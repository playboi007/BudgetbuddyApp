import 'money.dart';
import 'recipient.dart';
import 'validation.dart';

/// Immutable transaction amount accepted by the user. A changed amount needs
/// renewed confirmation before submission.
sealed class TransactionQuote {
  TransactionQuote({
    required String id,
    required String walletId,
    required Money amount,
    required DateTime createdAt,
    required DateTime expiresAt,
  }) : id = nonBlank(id, 'id'),
       walletId = nonBlank(walletId, 'walletId'),
       amount = positive(amount, 'amount'),
       createdAt = createdAt.toUtc(),
       expiresAt = expiresAt.toUtc() {
    if (!this.expiresAt.isAfter(this.createdAt)) {
      throw ArgumentError('Quote expiry must be after creation.');
    }
  }

  final String id;
  final String walletId;
  final Money amount;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool isValidAt(DateTime time) =>
      !time.isBefore(createdAt) && time.isBefore(expiresAt);
}

/// The amount is the complete spend debited from the wallet.
final class PaymentQuote extends TransactionQuote {
  PaymentQuote({
    required super.id,
    required super.walletId,
    required String categoryId,
    required this.recipient,
    required super.amount,
    required super.createdAt,
    required super.expiresAt,
  }) : categoryId = nonBlank(categoryId, 'categoryId');

  final String categoryId;
  final PaymentRecipient recipient;
}

/// The amount is the confirmed credit received by the wallet.
final class DepositQuote extends TransactionQuote {
  DepositQuote({
    required super.id,
    required super.walletId,
    required this.payer,
    required super.amount,
    required super.createdAt,
    required super.expiresAt,
  });

  final MpesaPhoneNumber payer;
}
