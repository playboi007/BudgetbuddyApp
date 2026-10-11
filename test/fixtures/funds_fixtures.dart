import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:budgetbuddy_app/budgetbuddy_flows.dart';
import 'package:budgetbuddy_app/budgetbuddy_models.dart';
import 'package:budgetbuddy_app/budgetbuddy_state.dart';

/// Reads shared scenario inputs from the checked-in JSON fixture.
abstract final class FlowFixture {
  static final Map<String, Object?> _input = _readInputs();

  static Map<String, Object?> _readInputs() {
    final file = File('test/fixtures/funds_inputs.json');
    if (!file.existsSync()) {
      throw StateError(
        'Run flow fixtures from the repository root; '
        'test/fixtures/funds_inputs.json was not found.',
      );
    }
    final decoded = jsonDecode(file.readAsStringSync());
    final input = Map<String, Object?>.from(decoded as Map);
    if (input['schemaVersion'] != 1) {
      throw StateError('Unsupported funds fixture schema version.');
    }
    return input;
  }

  static Map<String, Object?> _map(Object? value) =>
      Map<String, Object?>.from(value! as Map);

  static Map<String, Object?> get actor => _map(_input['actor']);
  static Map<String, Object?> get clock => _map(_input['clock']);
  static Map<String, Object?> get amounts => _map(_input['amountsKes']);
  static Map<String, Object?> get categories => _map(_input['categories']);
  static Map<String, Object?> get categoryEdits =>
      _map(_input['categoryEdits']);
  static Map<String, Object?> get commands => _map(_input['commands']);
  static Map<String, Object?> get events => _map(_input['events']);
  static Map<String, Object?> get quotes => _map(_input['quotes']);
  static Map<String, Object?> get providerResult =>
      _map(_input['providerResult']);
  static Map<String, Object?> get gatewayProfiles =>
      _map(_input['gatewayProfiles']);
  static Map<String, Object?> get recipient => _map(_input['recipient']);

  static String get ownerId => actor['ownerId']! as String;
  static String get walletId => actor['walletId']! as String;
  static String get payerPhone => _input['payerPhone']! as String;
  static DateTime get now => DateTime.parse(clock['nowUtc']! as String).toUtc();
  static DateTime quoteExpiry(String quoteName) =>
      now.add(Duration(seconds: quoteTtlSeconds(quoteName)));

  static int amountKes(String key) => amounts[key]! as int;
  static String commandId(String key) => commands[key]! as String;
  static String eventId(String key) => events[key]! as String;
  static int quoteTtlSeconds(String quoteName) {
    final ttl = quoteSpec(quoteName)['ttl']! as String;
    return ttl == 'expired'
        ? clock['expiredQuoteTtlSeconds']! as int
        : clock['defaultQuoteTtlSeconds']! as int;
  }

  static int approvalAmountKes(String quoteName) =>
      quoteSpec(quoteName)['approvedGlobalKes']! as int;

  static Map<String, Object?> seedSpec(String name) =>
      _map(_map(_input['seeds'])[name]);
  static Map<String, Object?> categorySpec(String name) =>
      _map(categories[name]);
  static Map<String, Object?> quoteSpec(String name) => _map(quotes[name]);
  static Map<String, Object?> gatewayProfile(String name) =>
      _map(gatewayProfiles[name]);

  static String get couchId => categorySpec('couch')['id']! as String;
  static String get rentId => categorySpec('rent')['id']! as String;
  static String get createdCategoryId =>
      categorySpec('emergency')['id']! as String;
  static String get emptyCategoryId =>
      categorySpec('emptyPayment')['id']! as String;

  static String get emptyRevision =>
      _map(_input['walletRevisions'])['empty']! as String;
  static String get fundedRevision =>
      _map(_input['walletRevisions'])['funded']! as String;

  static String get createCategoryCommandId => commandId('categoryCreate');
  static String get editCategoryCommandId => commandId('categoryEdit');
  static String get archiveCategoryCommandId => commandId('categoryArchive');
  static String get allocateCommandId => commandId('allocateCouch');
  static String get allocateRentCommandId =>
      commandId('allocateRentForStaleApproval');
  static String get releaseCommandId => commandId('releaseCouch');
  static String get depositCommandId => commandId('depositSuccess');
  static String get spend18kCommandId => commandId('couch18');
  static String get spend20kCommandId => commandId('couch20');
  static String get spend23kCommandId => commandId('couch23');
  static String get spend36kCommandId => commandId('couch36');
  static String get createEmptyCategoryCommandId =>
      commandId('emptyCategoryCreate');
  static String get spendEmptyCategoryCommandId =>
      commandId('emptyCategorySpend');
  static String get archiveEmptyCategoryCommandId =>
      commandId('emptyCategoryArchive');
  static String get archiveAfterHoldCommandId =>
      commandId('emptyCategoryArchiveAfterHold');
  static String get gatewayRejectedCommandId => commandId('gatewayRejected');
  static String get gatewayUnknownCommandId => commandId('gatewayUnknown');
}

Money kes(int amount) => Money.fromKes(amount);

/// Mutable UTC clock for crossing quote-expiry and settlement boundaries.
final class FixedFundsClock {
  FixedFundsClock([DateTime? initial])
    : _now = (initial ?? FlowFixture.now).toUtc();

  DateTime _now;

  DateTime call() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }

  void set(DateTime value) {
    _now = value.toUtc();
  }
}

WalletSnapshot _walletSeed(String name) {
  final seed = FlowFixture.seedSpec(name);
  final revision = name == 'empty'
      ? FlowFixture.emptyRevision
      : FlowFixture.fundedRevision;
  final categories = (seed['categories']! as List<Object?>).map((entry) {
    final row = Map<String, Object?>.from(entry! as Map);
    final spec = FlowFixture.categorySpec(row['category']! as String);
    final category = FundCategory(
      id: spec['id']! as String,
      walletId: FlowFixture.walletId,
      name: spec['name']! as String,
      kind: CategoryKind.values.byName(spec['kind']! as String),
      target: kes(spec['targetKes']! as int),
      createdAt: FlowFixture.now,
    );
    return CategoryBalance(
      category: category,
      balance: kes(row['balanceKes']! as int),
      reserved: kes(row['reservedKes']! as int),
    );
  });
  return WalletSnapshot(
    wallet: Wallet(
      id: FlowFixture.walletId,
      ownerId: FlowFixture.ownerId,
      createdAt: FlowFixture.now,
    ),
    revision: revision,
    unallocated: kes(seed['unallocatedKes']! as int),
    globalReserved: kes(seed['globalReservedKes']! as int),
    categories: categories,
    asOf: FlowFixture.now,
  );
}

WalletSnapshot emptyWalletSeed() => _walletSeed('empty');

WalletSnapshot fundedWalletSeed() => _walletSeed('funded');

FundsData emptyFundsSeed() => FundsData(wallet: emptyWalletSeed());

FundsData fundedFundsSeed() => FundsData(wallet: fundedWalletSeed());

PaymentRecipient _recipientFromFixture() {
  final recipient = FlowFixture.recipient;
  return switch (recipient['kind']! as String) {
    'till' => TillRecipient(recipient['tillNumber']! as String),
    _ => throw StateError('Unsupported reference recipient fixture.'),
  };
}

PaymentQuote paymentQuote(
  String fixtureName, {
  DateTime? createdAt,
  DateTime? expiresAt,
}) {
  final spec = FlowFixture.quoteSpec(fixtureName);
  final categoryName = spec['category']! as String;
  final amountName = spec['amount']! as String;
  return PaymentQuote(
    id: spec['id']! as String,
    walletId: FlowFixture.walletId,
    categoryId: FlowFixture.categorySpec(categoryName)['id']! as String,
    recipient: _recipientFromFixture(),
    amount: kes(FlowFixture.amountKes(amountName)),
    createdAt: createdAt ?? FlowFixture.now,
    expiresAt: expiresAt ?? FlowFixture.quoteExpiry(fixtureName),
  );
}

DepositQuote depositQuote(
  String fixtureName, {
  DateTime? createdAt,
  DateTime? expiresAt,
}) {
  final spec = FlowFixture.quoteSpec(fixtureName);
  final amountName = spec['amount']! as String;
  return DepositQuote(
    id: spec['id']! as String,
    walletId: FlowFixture.walletId,
    payer: MpesaPhoneNumber(FlowFixture.payerPhone),
    amount: kes(FlowFixture.amountKes(amountName)),
    createdAt: createdAt ?? FlowFixture.now,
    expiresAt: expiresAt ?? FlowFixture.quoteExpiry(fixtureName),
  );
}

ProviderResolution providerResolution({
  required String eventId,
  required String requestId,
  required ProviderResolutionOutcome outcome,
  int? reportedAmount,
}) {
  final profile = FlowFixture.providerResult;
  final succeeded = outcome == ProviderResolutionOutcome.succeeded;
  final identifiers = ProviderIdentifiers(
    merchantRequestId: '${profile['merchantRequestIdPrefix']}$requestId',
    checkoutRequestId: '${profile['checkoutRequestIdPrefix']}$requestId',
    conversationId: '${profile['conversationIdPrefix']}$requestId',
    transactionReceipt: succeeded
        ? '${profile['receiptPrefix']}$requestId'
        : null,
  );
  final description = switch (outcome) {
    ProviderResolutionOutcome.succeeded =>
      profile['successDescription']! as String,
    ProviderResolutionOutcome.failed =>
      profile['failureDescription']! as String,
    ProviderResolutionOutcome.unknown =>
      profile['unknownDescription']! as String,
  };
  return ProviderResolution(
    eventId: eventId,
    requestId: requestId,
    outcome: outcome,
    identifiers: identifiers,
    description: description,
    reportedAmount: reportedAmount == null ? null : kes(reportedAmount),
  );
}

/// Deterministic provider fixture with request-derived identifiers for later
/// acknowledgment tracing and resolution.
final class ControlledPaymentGateway implements PaymentGateway {
  ControlledPaymentGateway({required this.profileName, this.gated = false});

  factory ControlledPaymentGateway.accepted({bool gated = false}) =>
      ControlledPaymentGateway(profileName: 'accepted', gated: gated);

  factory ControlledPaymentGateway.rejected({bool gated = false}) =>
      ControlledPaymentGateway(profileName: 'rejected', gated: gated);

  factory ControlledPaymentGateway.unknown({bool gated = false}) =>
      ControlledPaymentGateway(profileName: 'unknown', gated: gated);

  final String profileName;
  final bool gated;
  final List<TransactionRequest> submittedRequests = [];
  final Completer<TransactionRequest> _firstSubmission = Completer();
  final Completer<void> _acknowledgmentGate = Completer();

  Future<TransactionRequest> get firstSubmission => _firstSubmission.future;

  void releaseAcknowledgment() {
    if (!_acknowledgmentGate.isCompleted) _acknowledgmentGate.complete();
  }

  GatewayAcknowledgment _acknowledgmentFor(TransactionRequest request) {
    final profile = FlowFixture.gatewayProfile(profileName);
    final identifiers = Map<String, Object?>.from(
      profile['identifiers']! as Map,
    );
    String? prefixedId(String key) {
      final prefix = identifiers['${key}Prefix'];
      return prefix == null ? null : '$prefix${request.id}';
    }

    return GatewayAcknowledgment(
      status: GatewayAcknowledgmentStatus.values.byName(
        profile['status']! as String,
      ),
      identifiers: ProviderIdentifiers(
        merchantRequestId: prefixedId('merchantRequestId'),
        checkoutRequestId: prefixedId('checkoutRequestId'),
        originatorConversationId: prefixedId('originatorConversationId'),
        conversationId: prefixedId('conversationId'),
      ),
      description: profile['description']! as String,
    );
  }

  @override
  Future<GatewayAcknowledgment> submit(TransactionRequest request) async {
    submittedRequests.add(request);
    if (!_firstSubmission.isCompleted) _firstSubmission.complete(request);
    if (gated) await _acknowledgmentGate.future;
    return _acknowledgmentFor(request);
  }
}

final class FundsFlowHarness {
  FundsFlowHarness._({
    required this.clock,
    required this.gateway,
    required this.repository,
    required this.application,
    required this.controller,
  });

  static Future<FundsFlowHarness> start({
    String seedName = 'funded',
    FixedFundsClock? clock,
    ControlledPaymentGateway? gateway,
  }) async {
    final actualClock = clock ?? FixedFundsClock();
    final actualGateway = gateway ?? ControlledPaymentGateway.accepted();
    final repository = InMemoryFundsRepository(
      seed: seedName == 'empty' ? emptyFundsSeed() : fundedFundsSeed(),
    );
    final application = FundsFlowService(
      actor: ActorContext(
        ownerId: FlowFixture.ownerId,
        walletId: FlowFixture.walletId,
      ),
      repository: repository,
      gateway: actualGateway,
      clock: actualClock.call,
    );
    final controller = FundsController(application, clock: actualClock.call);
    await controller.initialize();
    return FundsFlowHarness._(
      clock: actualClock,
      gateway: actualGateway,
      repository: repository,
      application: application,
      controller: controller,
    );
  }

  final FixedFundsClock clock;
  final ControlledPaymentGateway gateway;
  final InMemoryFundsRepository repository;
  final FundsFlowService application;
  final FundsController controller;

  FundsData get snapshot => controller.data.value!;

  Future<CommandResult?> execute(FundsCommand command) =>
      controller.execute(command);

  Future<CommandResult> resolve({
    required String requestId,
    required String eventId,
    required ProviderResolutionOutcome outcome,
    int? reportedAmount,
  }) => application.recordProviderResult(
    providerResolution(
      eventId: eventId,
      requestId: requestId,
      outcome: outcome,
      reportedAmount: reportedAmount,
    ),
  );

  Future<void> refresh() => controller.refresh();

  Future<void> dispose() => controller.dispose();
}
