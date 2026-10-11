import 'funding.dart';
import 'money.dart';
import 'quotes.dart';
import 'validation.dart';

enum TransactionStatus {
  created,
  submitting,
  pending,
  awaitingVerification,
  succeeded,
  failed,
  reconciliationRequired;

  bool canTransitionTo(TransactionStatus next) => switch (this) {
    created => {submitting, failed}.contains(next),
    submitting => {
      pending,
      awaitingVerification,
      succeeded,
      failed,
      reconciliationRequired,
    }.contains(next),
    pending => {
      awaitingVerification,
      succeeded,
      failed,
      reconciliationRequired,
    }.contains(next),
    awaitingVerification => {
      pending,
      succeeded,
      failed,
      reconciliationRequired,
    }.contains(next),
    succeeded || failed => next == reconciliationRequired,
    reconciliationRequired => {succeeded, failed}.contains(next),
  };
}

/// Provider transport identifiers are distinct from the app's idempotency key.
final class ProviderIdentifiers {
  const ProviderIdentifiers({
    this.merchantRequestId,
    this.checkoutRequestId,
    this.originatorConversationId,
    this.conversationId,
    this.transactionReceipt,
  });

  final String? merchantRequestId;
  final String? checkoutRequestId;
  final String? originatorConversationId;
  final String? conversationId;
  final String? transactionReceipt;
}

/// A provider acknowledgment is not a settlement. State changes replace this
/// record; its approved amount stays fixed.
sealed class TransactionRequest {
  TransactionRequest({
    required String id,
    required String idempotencyKey,
    required this.status,
    required this.providerIdentifiers,
    required DateTime createdAt,
    required this.resultDescription,
    required this.ledgerOperationId,
    DateTime? settledAt,
  }) : id = nonBlank(id, 'id'),
       idempotencyKey = nonBlank(idempotencyKey, 'idempotencyKey'),
       createdAt = createdAt.toUtc(),
       settledAt = settledAt?.toUtc() {
    final isSettled =
        status == TransactionStatus.succeeded ||
        status == TransactionStatus.failed;
    if (isSettled && this.settledAt == null) {
      throw ArgumentError('A settled request needs a settlement time.');
    }
    if (!isSettled &&
        status != TransactionStatus.reconciliationRequired &&
        this.settledAt != null) {
      throw ArgumentError(
        'An unresolved request cannot have a settlement time.',
      );
    }
    if (this.settledAt?.isBefore(this.createdAt) ?? false) {
      throw ArgumentError('Settlement must not precede request creation.');
    }
    if (status == TransactionStatus.succeeded) {
      nonBlank(ledgerOperationId ?? '', 'ledgerOperationId');
      nonBlank(
        providerIdentifiers.transactionReceipt ?? '',
        'transactionReceipt',
      );
    } else if (status != TransactionStatus.reconciliationRequired &&
        ledgerOperationId != null) {
      throw ArgumentError(
        'Only success can post a settlement ledger operation.',
      );
    }
  }

  final String id;
  final String idempotencyKey;
  final TransactionStatus status;
  final ProviderIdentifiers providerIdentifiers;
  final DateTime createdAt;
  final DateTime? settledAt;
  final String? resultDescription;
  final String? ledgerOperationId;

  TransactionQuote get quote;
  String get walletId => quote.walletId;
  String get environment => 'sandbox';
}

final class DepositRequest extends TransactionRequest {
  DepositRequest({
    required super.id,
    required super.idempotencyKey,
    required this.quote,
    required super.status,
    required super.providerIdentifiers,
    required super.createdAt,
    required super.resultDescription,
    required super.ledgerOperationId,
    super.settledAt,
  }) {
    if (!quote.isValidAt(createdAt)) {
      throw ArgumentError(
        'Request must be created within the approved quote window.',
      );
    }
  }

  @override
  final DepositQuote quote;
}

final class OutgoingPaymentRequest extends TransactionRequest {
  OutgoingPaymentRequest({
    required super.id,
    required super.idempotencyKey,
    required this.funding,
    required String reservationId,
    required super.status,
    required super.providerIdentifiers,
    required super.createdAt,
    required super.resultDescription,
    required super.ledgerOperationId,
    super.settledAt,
  }) : reservationId = nonBlank(reservationId, 'reservationId') {
    if (!quote.isValidAt(createdAt)) {
      throw ArgumentError(
        'Request must be created within the approved quote window.',
      );
    }
    if (funding.approval?.approvedAt.isAfter(this.createdAt) ?? false) {
      throw ArgumentError(
        'Global funding must be approved before request creation.',
      );
    }
  }

  final PaymentFundingPlan funding;
  final String reservationId;

  @override
  PaymentQuote get quote => funding.quote;
}

enum ReservationStatus { active, consumed, released }

final class PaymentReservation {
  PaymentReservation({
    required String id,
    required String requestId,
    required this.funding,
    required this.status,
    required DateTime createdAt,
    DateTime? resolvedAt,
  }) : id = nonBlank(id, 'id'),
       requestId = nonBlank(requestId, 'requestId'),
       createdAt = createdAt.toUtc(),
       resolvedAt = resolvedAt?.toUtc() {
    if ((status == ReservationStatus.active) != (this.resolvedAt == null)) {
      throw ArgumentError('Only an active reservation has no resolution time.');
    }
    if (!funding.quote.isValidAt(this.createdAt)) {
      throw ArgumentError('Reserve against a current quote.');
    }
    if (funding.approval?.approvedAt.isAfter(this.createdAt) ?? false) {
      throw ArgumentError(
        'Global funding approval must precede its reservation.',
      );
    }
    if (this.resolvedAt?.isBefore(this.createdAt) ?? false) {
      throw ArgumentError('Resolution must not precede reservation.');
    }
  }

  final String id;
  final String requestId;
  final PaymentFundingPlan funding;
  final ReservationStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  String get walletId => funding.quote.walletId;
  String get categoryId => funding.quote.categoryId;
  Money get total => funding.totalReserved;
}
