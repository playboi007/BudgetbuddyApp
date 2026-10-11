import '../budgetbuddy_models.dart';

typedef FundsClock = DateTime Function();

/// Bind this to the authenticated backend identity in a hosted implementation.
final class ActorContext {
  const ActorContext({required this.ownerId, required this.walletId});
  final String ownerId;
  final String walletId;
}

final class FundsData {
  FundsData({
    required this.wallet,
    Iterable<TransactionRequest> requests = const [],
    Iterable<PaymentReservation> reservations = const [],
    Iterable<LedgerOperation> ledger = const [],
    Iterable<ProviderEvent> providerEvents = const [],
  }) : requests = List.unmodifiable(requests),
       reservations = List.unmodifiable(reservations),
       ledger = List.unmodifiable(ledger),
       providerEvents = List.unmodifiable(providerEvents);

  final WalletSnapshot wallet;
  final List<TransactionRequest> requests;
  final List<PaymentReservation> reservations;
  final List<LedgerOperation> ledger;
  final List<ProviderEvent> providerEvents;
}

sealed class FundsCommand {
  const FundsCommand({required this.commandId});
  final String commandId;
}

final class CreateCategoryCommand extends FundsCommand {
  const CreateCategoryCommand({
    required super.commandId,
    required this.category,
  });
  final FundCategory category;
}

final class EditCategoryCommand extends FundsCommand {
  const EditCategoryCommand({
    required super.commandId,
    required this.categoryId,
    required this.name,
    required this.target,
  });
  final String categoryId;
  final String name;
  final Money target;
}

final class ArchiveCategoryCommand extends FundsCommand {
  const ArchiveCategoryCommand({
    required super.commandId,
    required this.categoryId,
  });
  final String categoryId;
}

final class AllocateCommand extends FundsCommand {
  const AllocateCommand({
    required super.commandId,
    required this.categoryId,
    required this.amount,
  });
  final String categoryId;
  final Money amount;
}

final class ReleaseCommand extends FundsCommand {
  const ReleaseCommand({
    required super.commandId,
    required this.categoryId,
    required this.amount,
  });
  final String categoryId;
  final Money amount;
}

final class DepositCommand extends FundsCommand {
  const DepositCommand({required super.commandId, required this.quote});
  final DepositQuote quote;
}

final class SpendCommand extends FundsCommand {
  const SpendCommand({
    required super.commandId,
    required this.quote,
    this.approval,
  });
  final PaymentQuote quote;
  final GlobalFundingApproval? approval;
}

enum FundsFailureCode {
  invalidCommand,
  unauthorized,
  notFound,
  archivedCategory,
  insufficientFunds,
  invalidApproval,
  expiredQuote,
  idempotencyConflict,
  busy,
  unavailable,
}

final class FundsFailure {
  const FundsFailure(this.code, this.message);
  final FundsFailureCode code;
  final String message;
}

final class FundsException implements Exception {
  const FundsException(this.failure);
  final FundsFailure failure;
  @override
  String toString() => failure.message;
}

enum CommandDisposition { applied, submitted, requiresGlobalApproval, rejected }

final class CommandResult {
  const CommandResult({
    required this.disposition,
    required this.data,
    this.requestId,
    this.fundingRequirement,
    this.failure,
  });
  final CommandDisposition disposition;
  final FundsData data;
  final String? requestId;
  final FundingRequirement? fundingRequirement;
  final FundsFailure? failure;
}

/// The screen-facing interface omits provider-result mutation.
abstract interface class FundsApplication {
  Future<FundsData> load();

  /// Emits commits in order; each opaque revision identifies an immutable snapshot.
  Stream<FundsData> watch();
  Future<CommandResult> execute(FundsCommand command);
}

enum GatewayAcknowledgmentStatus { accepted, rejected, unknown }

final class GatewayAcknowledgment {
  const GatewayAcknowledgment({
    required this.status,
    required this.identifiers,
    required this.description,
  });
  final GatewayAcknowledgmentStatus status;
  final ProviderIdentifiers identifiers;
  final String description;
}

abstract interface class PaymentGateway {
  Future<GatewayAcknowledgment> submit(TransactionRequest request);
}

enum ProviderResolutionOutcome { succeeded, failed, unknown }

/// Normalized adapter result; raw callback authentication is outside this type.
final class ProviderResolution {
  const ProviderResolution({
    required this.eventId,
    required this.requestId,
    required this.outcome,
    required this.identifiers,
    required this.description,
    this.reportedAmount,
  });
  final String eventId;
  final String requestId;
  final ProviderResolutionOutcome outcome;
  final ProviderIdentifiers identifiers;
  final String description;
  final Money? reportedAmount;
}
