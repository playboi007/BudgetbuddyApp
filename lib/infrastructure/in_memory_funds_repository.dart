import 'dart:async';

import '../budgetbuddy_models.dart';
import '../application/contracts.dart';
import '../application/funds_repository.dart';

/// Serialized, process-local reference repository; state is not durable.
final class InMemoryFundsRepository implements FundsRepository {
  InMemoryFundsRepository({required FundsData seed}) : _data = seed {
    _revisionBase = seed.wallet.revision;
    _validateReservations(seed);
  }

  late final String _revisionBase;
  FundsData _data;
  int _revisionSequence = 0;
  Future<void> _tail = Future<void>.value();
  final StreamController<FundsData> _updates =
      StreamController<FundsData>.broadcast(sync: true);
  final Map<String, String> _commandFingerprints = {};
  final Map<String, FundsCommandMemo> _commandMemos = {};
  final Map<String, String> _providerEventFingerprints = {};

  @override
  Future<FundsData> load(ActorContext actor) async {
    _checkActor(actor);
    return _data;
  }

  @override
  Stream<FundsData> watch(ActorContext actor) {
    _checkActor(actor);
    return Stream<FundsData>.multi((controller) {
      final subscription = _updates.stream.listen(controller.add);
      controller.add(_data);
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<T> transact<T>(
    ActorContext actor,
    T Function(FundsRepositoryTransaction transaction) action,
  ) async {
    final previous = _tail;
    final release = Completer<void>();
    _tail = release.future;
    await previous;
    try {
      _checkActor(actor);
      final transaction = _MemoryTransaction(
        data: _data,
        commandFingerprints: _commandFingerprints,
        commandMemos: _commandMemos,
        providerEventFingerprints: _providerEventFingerprints,
      );
      final result = action(transaction);

      if (transaction.dataChanged) {
        if (transaction.data.wallet.wallet.id != _data.wallet.wallet.id ||
            transaction.data.wallet.wallet.ownerId !=
                _data.wallet.wallet.ownerId) {
          throw ArgumentError(
            'A repository transaction cannot replace wallet ownership.',
          );
        }
        _validateReservations(transaction.data);
        _revisionSequence++;
        _data = _withRevision(
          transaction.data,
          '$_revisionBase:$_revisionSequence',
        );
        _updates.add(_data);
      }
      _commandFingerprints
        ..clear()
        ..addAll(transaction.commandFingerprints);
      _commandMemos
        ..clear()
        ..addAll(transaction.commandMemos);
      _providerEventFingerprints
        ..clear()
        ..addAll(transaction.providerEventFingerprints);
      return result;
    } finally {
      release.complete();
    }
  }

  void _checkActor(ActorContext actor) {
    if (actor.ownerId != _data.wallet.wallet.ownerId ||
        actor.walletId != _data.wallet.wallet.id) {
      throw const FundsException(
        FundsFailure(
          FundsFailureCode.unauthorized,
          'This wallet is not available to the current actor.',
        ),
      );
    }
  }

  static FundsData _withRevision(FundsData data, String revision) => FundsData(
    wallet: WalletSnapshot(
      wallet: data.wallet.wallet,
      revision: revision,
      unallocated: data.wallet.unallocated,
      globalReserved: data.wallet.globalReserved,
      categories: data.wallet.categories,
      asOf: data.wallet.asOf,
    ),
    requests: data.requests,
    reservations: data.reservations,
    ledger: data.ledger,
    providerEvents: data.providerEvents,
  );

  static void _validateReservations(FundsData data) {
    final requestsById = {
      for (final request in data.requests) request.id: request,
    };
    if (requestsById.length != data.requests.length) {
      throw ArgumentError('Request IDs must be unique in the repository seed.');
    }
    final idempotencyKeys = {
      for (final request in data.requests) request.idempotencyKey,
    };
    if (idempotencyKeys.length != data.requests.length) {
      throw ArgumentError(
        'Request idempotency keys must be unique in the repository seed.',
      );
    }
    final reservationsById = {
      for (final reservation in data.reservations) reservation.id: reservation,
    };
    if (reservationsById.length != data.reservations.length) {
      throw ArgumentError(
        'Reservation IDs must be unique in the repository seed.',
      );
    }

    final globalReserved = <int>[0];
    final categoryReserved = <String, int>{};
    for (final reservation in data.reservations) {
      final request = requestsById[reservation.requestId];
      if (request is! OutgoingPaymentRequest ||
          request.reservationId != reservation.id ||
          request.walletId != data.wallet.wallet.id ||
          !_sameFunding(request, reservation)) {
        throw ArgumentError('A payment reservation must match its request.');
      }
      if (reservation.status == ReservationStatus.active) {
        globalReserved[0] += reservation.funding.globalContribution.minorUnits;
        final categoryId = reservation.categoryId;
        categoryReserved[categoryId] =
            (categoryReserved[categoryId] ?? 0) +
            reservation.funding.categoryContribution.minorUnits;
      }
    }

    for (final request in data.requests) {
      if (request.walletId != data.wallet.wallet.id) {
        throw ArgumentError('Every request must belong to the seeded wallet.');
      }
      if (request is OutgoingPaymentRequest) {
        final reservation = reservationsById[request.reservationId];
        if (reservation == null || reservation.requestId != request.id) {
          throw ArgumentError(
            'Every outgoing request must retain its reservation record.',
          );
        }
        final expected = switch (request.status) {
          TransactionStatus.created ||
          TransactionStatus.submitting ||
          TransactionStatus.pending ||
          TransactionStatus.awaitingVerification => ReservationStatus.active,
          TransactionStatus.succeeded => ReservationStatus.consumed,
          TransactionStatus.failed => ReservationStatus.released,
          TransactionStatus.reconciliationRequired =>
            request.settledAt == null
                ? ReservationStatus.active
                : request.ledgerOperationId == null
                ? ReservationStatus.released
                : ReservationStatus.consumed,
        };
        if (reservation.status != expected) {
          throw ArgumentError('Request state and reservation state disagree.');
        }
      }
    }

    if (globalReserved[0] != data.wallet.globalReserved.minorUnits) {
      throw ArgumentError(
        'Global reservations must match the wallet projection.',
      );
    }
    for (final categoryBalance in data.wallet.categories) {
      final expected = categoryReserved[categoryBalance.category.id] ?? 0;
      if (expected != categoryBalance.reserved.minorUnits) {
        throw ArgumentError(
          'Category reservations must match the wallet projection.',
        );
      }
    }
    for (final categoryId in categoryReserved.keys) {
      if (!data.wallet.categories.any(
        (item) => item.category.id == categoryId,
      )) {
        throw ArgumentError('A reservation references a missing category.');
      }
    }
  }

  static bool _sameFunding(
    OutgoingPaymentRequest request,
    PaymentReservation reservation,
  ) {
    final expected = request.funding;
    final stored = reservation.funding;
    final expectedQuote = expected.quote;
    final storedQuote = stored.quote;
    return request.reservationId == reservation.id &&
        request.createdAt == reservation.createdAt &&
        storedQuote.walletId == request.walletId &&
        storedQuote.categoryId == request.quote.categoryId &&
        stored.totalReserved == request.quote.amount &&
        stored.categoryContribution == expected.categoryContribution &&
        stored.globalContribution == expected.globalContribution &&
        storedQuote.id == expectedQuote.id &&
        storedQuote.walletId == expectedQuote.walletId &&
        storedQuote.categoryId == expectedQuote.categoryId &&
        storedQuote.amount == expectedQuote.amount &&
        storedQuote.createdAt == expectedQuote.createdAt &&
        storedQuote.expiresAt == expectedQuote.expiresAt &&
        _sameRecipient(storedQuote.recipient, expectedQuote.recipient) &&
        _sameApproval(stored.approval, expected.approval);
  }

  static bool _sameApproval(
    GlobalFundingApproval? left,
    GlobalFundingApproval? right,
  ) => left == null
      ? right == null
      : right != null &&
            left.quoteId == right.quoteId &&
            left.ownerId == right.ownerId &&
            left.amount == right.amount &&
            left.approvedAt == right.approvedAt;

  static bool _sameRecipient(PaymentRecipient left, PaymentRecipient right) {
    if (left is PhoneRecipient && right is PhoneRecipient) {
      return left.phoneNumber.value == right.phoneNumber.value;
    }
    if (left is TillRecipient && right is TillRecipient) {
      return left.tillNumber == right.tillNumber;
    }
    if (left is PaybillRecipient && right is PaybillRecipient) {
      return left.paybillNumber == right.paybillNumber &&
          left.accountReference == right.accountReference;
    }
    return false;
  }
}

final class _MemoryTransaction implements FundsRepositoryTransaction {
  _MemoryTransaction({
    required FundsData data,
    required Map<String, String> commandFingerprints,
    required Map<String, FundsCommandMemo> commandMemos,
    required Map<String, String> providerEventFingerprints,
  }) : _data = data,
       commandFingerprints = Map.of(commandFingerprints),
       commandMemos = Map.of(commandMemos),
       providerEventFingerprints = Map.of(providerEventFingerprints);

  FundsData _data;
  bool dataChanged = false;
  @override
  final Map<String, String> commandFingerprints;
  @override
  final Map<String, FundsCommandMemo> commandMemos;
  @override
  final Map<String, String> providerEventFingerprints;

  @override
  FundsData get data => _data;

  @override
  void replaceData(FundsData data) {
    _data = data;
    dataChanged = true;
  }

  @override
  String? commandFingerprint(String commandId) =>
      commandFingerprints[commandId];

  @override
  void bindCommand(String commandId, String fingerprint) {
    commandFingerprints[commandId] = fingerprint;
  }

  @override
  FundsCommandMemo? commandMemo(String commandId) => commandMemos[commandId];

  @override
  void completeCommand(String commandId, FundsCommandMemo memo) {
    commandMemos[commandId] = memo;
  }

  @override
  String? providerEventFingerprint(String eventId) =>
      providerEventFingerprints[eventId];

  @override
  void bindProviderEvent(String eventId, String fingerprint) {
    providerEventFingerprints[eventId] = fingerprint;
  }
}
