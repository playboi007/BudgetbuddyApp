import 'contracts.dart';
import '../budgetbuddy_models.dart';

/// Synchronous callbacks let implementations hold one lock across balance and
/// ledger changes.
abstract interface class FundsRepository {
  Future<FundsData> load(ActorContext actor);

  Stream<FundsData> watch(ActorContext actor);

  Future<T> transact<T>(
    ActorContext actor,
    T Function(FundsRepositoryTransaction transaction) action,
  );
}

/// Commit changes together; discard the local view if [transact] throws.
abstract interface class FundsRepositoryTransaction {
  FundsData get data;

  Map<String, String> get commandFingerprints;

  Map<String, FundsCommandMemo> get commandMemos;

  Map<String, String> get providerEventFingerprints;

  void replaceData(FundsData data);

  String? commandFingerprint(String commandId);

  void bindCommand(String commandId, String fingerprint);

  FundsCommandMemo? commandMemo(String commandId);

  void completeCommand(String commandId, FundsCommandMemo memo);

  String? providerEventFingerprint(String eventId);

  void bindProviderEvent(String eventId, String fingerprint);
}

/// Stores an idempotent command's result beside its payload binding.
/// Replays return fresh data without repeating mutation or provider dispatch.
final class FundsCommandMemo {
  const FundsCommandMemo({
    required this.disposition,
    this.requestId,
    this.fundingRequirement,
    this.failure,
  });

  final CommandDisposition disposition;
  final String? requestId;
  final FundingRequirement? fundingRequirement;
  final FundsFailure? failure;
}
