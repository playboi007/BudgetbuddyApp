import 'category.dart';
import 'money.dart';
import 'validation.dart';

final class Wallet {
  Wallet({
    required String id,
    required String ownerId,
    required DateTime createdAt,
  }) : id = nonBlank(id, 'id'),
       ownerId = nonBlank(ownerId, 'ownerId'),
       createdAt = createdAt.toUtc();

  final String id;
  final String ownerId;
  final DateTime createdAt;
  String get currency => Money.currency;
}

/// Totals come from one coherent snapshot, not separately edited values.
/// The backend must recheck its revision before reserving funds.
final class WalletSnapshot {
  WalletSnapshot({
    required this.wallet,
    required String revision,
    required this.unallocated,
    required this.globalReserved,
    required Iterable<CategoryBalance> categories,
    required DateTime asOf,
  }) : revision = nonBlank(revision, 'revision'),
       categories = List.unmodifiable(categories),
       asOf = asOf.toUtc() {
    if (globalReserved > unallocated) {
      throw ArgumentError('Global reservations exceed unallocated funds.');
    }
    final ids = <String>{};
    for (final item in this.categories) {
      if (item.category.walletId != wallet.id) {
        throw ArgumentError('Category belongs to a different wallet.');
      }
      if (!ids.add(item.category.id)) {
        throw ArgumentError('Duplicate category in wallet projection.');
      }
    }
    // Validate aggregate exactness on construction, including the web target.
    total;
  }

  final Wallet wallet;
  final String revision;
  final Money unallocated;
  final Money globalReserved;
  final List<CategoryBalance> categories;
  final DateTime asOf;

  Money get allocated =>
      categories.fold(Money.zero, (sum, c) => sum + c.balance);
  Money get total => unallocated + allocated;
  Money get availableGlobal => unallocated - globalReserved;
  Money get reserved =>
      categories.fold(globalReserved, (sum, c) => sum + c.reserved);
  Money get availableTotal => total - reserved;
}
