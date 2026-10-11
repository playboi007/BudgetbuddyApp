import 'money.dart';
import 'validation.dart';

enum LedgerBucketKind { global, category, external }

/// A bucket scoped by the owning ledger operation's walletId. External buckets
/// are outside the wallet; they are not included in wallet totals.
final class LedgerBucket {
  const LedgerBucket.global()
    : kind = LedgerBucketKind.global,
      reference = null;

  LedgerBucket.category(String categoryId)
    : kind = LedgerBucketKind.category,
      reference = nonBlank(categoryId, 'categoryId');

  LedgerBucket.external(String partyReference)
    : kind = LedgerBucketKind.external,
      reference = nonBlank(partyReference, 'partyReference');

  final LedgerBucketKind kind;
  final String? reference;

  @override
  bool operator ==(Object other) =>
      other is LedgerBucket &&
      kind == other.kind &&
      reference == other.reference;

  @override
  int get hashCode => Object.hash(kind, reference);
}

/// A payment records its complete spend in one external transfer.
final class LedgerTransfer {
  LedgerTransfer({
    required this.source,
    required this.destination,
    required Money amount,
  }) : amount = positive(amount, 'amount') {
    if (source == destination) {
      throw ArgumentError('A transfer must change buckets.');
    }
  }

  final LedgerBucket source;
  final LedgerBucket destination;
  final Money amount;
}

enum LedgerOperationKind { deposit, allocation, release, payment }

/// Append-only fact. Transfers settle atomically. The backend validates each
/// amount against the linked request's quote and funding plan.
final class LedgerOperation {
  LedgerOperation({
    required String id,
    required String walletId,
    required this.kind,
    required Iterable<LedgerTransfer> transfers,
    required DateTime postedAt,
    required this.requestId,
    required this.description,
  }) : id = nonBlank(id, 'id'),
       walletId = nonBlank(walletId, 'walletId'),
       transfers = List.unmodifiable(transfers),
       postedAt = postedAt.toUtc() {
    if (this.transfers.isEmpty) {
      throw ArgumentError('A ledger operation requires transfers.');
    }
    final isProviderSettlement =
        kind == LedgerOperationKind.deposit ||
        kind == LedgerOperationKind.payment;
    if (isProviderSettlement) {
      nonBlank(requestId ?? '', 'requestId');
    } else if (requestId != null) {
      throw ArgumentError(
        'Standalone allocation/release has no provider request.',
      );
    }
    if (!isProviderSettlement && this.transfers.length != 1) {
      throw ArgumentError('Standalone allocation/release moves one amount.');
    }
    for (final transfer in this.transfers) {
      final source = transfer.source.kind;
      final destination = transfer.destination.kind;
      final validRoute = switch (kind) {
        LedgerOperationKind.deposit =>
          source == LedgerBucketKind.external &&
              destination == LedgerBucketKind.global,
        LedgerOperationKind.allocation =>
          source == LedgerBucketKind.global &&
              destination == LedgerBucketKind.category,
        LedgerOperationKind.release =>
          source == LedgerBucketKind.category &&
              destination == LedgerBucketKind.global,
        LedgerOperationKind.payment =>
          (source == LedgerBucketKind.global &&
                  destination == LedgerBucketKind.category) ||
              (source == LedgerBucketKind.category &&
                  destination == LedgerBucketKind.external),
      };
      if (!validRoute) {
        throw ArgumentError(
          'Transfer route does not match the ledger operation.',
        );
      }
    }
    if (kind == LedgerOperationKind.deposit && this.transfers.length != 1) {
      throw ArgumentError('A deposit records one credited amount.');
    }
    if (kind == LedgerOperationKind.payment &&
        this.transfers
                .where((t) => t.destination.kind == LedgerBucketKind.external)
                .length !=
            1) {
      throw ArgumentError('A payment records one complete external spend.');
    }
    if (kind == LedgerOperationKind.payment &&
        this.transfers
                .where((t) => t.source.kind == LedgerBucketKind.global)
                .length >
            1) {
      throw ArgumentError('A payment has at most one global supplement.');
    }
    if (kind == LedgerOperationKind.payment) {
      final categories = <String>{};
      for (final transfer in this.transfers) {
        for (final bucket in [transfer.source, transfer.destination]) {
          if (bucket.kind == LedgerBucketKind.category) {
            categories.add(bucket.reference!);
          }
        }
      }
      if (categories.length != 1) {
        throw ArgumentError('A payment cannot draw from unrelated categories.');
      }
    }
  }

  final String id;
  final String walletId;
  final LedgerOperationKind kind;
  final List<LedgerTransfer> transfers;
  final DateTime postedAt;
  final String? requestId;
  final String description;
}
