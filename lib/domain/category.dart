import 'money.dart';
import 'validation.dart';

enum CategoryKind { spending, savingsGoal }

/// A target is informational; it does not add funds or impose a spending lock.
final class FundCategory {
  FundCategory({
    required String id,
    required String walletId,
    required String name,
    required this.kind,
    required Money target,
    required DateTime createdAt,
    DateTime? archivedAt,
  }) : id = nonBlank(id, 'id'),
       walletId = nonBlank(walletId, 'walletId'),
       name = nonBlank(name, 'name'),
       target = positive(target, 'target'),
       createdAt = createdAt.toUtc(),
       archivedAt = archivedAt?.toUtc() {
    if (this.archivedAt?.isBefore(this.createdAt) ?? false) {
      throw ArgumentError('Archive time must not precede creation.');
    }
  }

  final String id;
  final String walletId;
  final String name;
  final CategoryKind kind;
  final Money target;
  final DateTime createdAt;
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;
}

/// A backend balance projection, including funds held by pending requests.
final class CategoryBalance {
  CategoryBalance({
    required this.category,
    required this.balance,
    required this.reserved,
  }) {
    if (reserved > balance) {
      throw ArgumentError('Reserved category funds exceed its balance.');
    }
    if (category.isArchived && balance != Money.zero) {
      throw ArgumentError('An archived category must have zero balance.');
    }
  }

  final FundCategory category;
  final Money balance;
  final Money reserved;

  Money get available => balance - reserved;
  bool get canArchive => !category.isArchived && balance == Money.zero;
}
