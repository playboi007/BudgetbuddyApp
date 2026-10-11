import 'package:budgetbuddy_app/application/contracts.dart';
import 'package:budgetbuddy_app/budgetbuddy_flows.dart';
import 'package:budgetbuddy_app/budgetbuddy_models.dart';

import '../fixtures/funds_fixtures.dart';

final class FlowCheckpoint {
  const FlowCheckpoint({
    required this.id,
    required this.scenario,
    required this.action,
    required this.state,
  });

  final String id;
  final String scenario;
  final String action;
  final Map<String, Object?> state;

  Map<String, Object?> toJson() => {
    'id': id,
    'scenario': scenario,
    'action': action,
    ...state,
  };
}

List<FlowCheckpoint> _capture(
  FundsFlowHarness harness, {
  required String id,
  required String scenario,
  required String action,
}) {
  final controller = harness.controller;
  final data = harness.snapshot;
  final command = controller.commandState.value;
  final resultRequirement = command.result?.fundingRequirement;
  final approvalRequirement = command.approvalRequirement;
  final resultDisposition = command.result?.disposition;
  final actionStatus = command.isBusy
      ? 'loading'
      : command.error != null
      ? 'error'
      : resultDisposition?.name ?? 'idle';

  return [
    FlowCheckpoint(
      id: id,
      scenario: scenario,
      action: action,
      state: {
        'ui': {
          'loadStatus': controller.loadStatus.value.name,
          'loadError': controller.loadError.value?.message,
          'watchError': controller.watchError.value?.message,
          'actionableApproval': approvalRequirement != null,
          'actionStatus': actionStatus,
          'actionIsLoading': command.isBusy,
          'commandId': command.commandId,
          'commandError': command.failure?.message ?? command.error?.message,
          'commandErrorCode': command.failure?.code.name,
          'needsApproval': approvalRequirement != null,
          'approvalRequirement': approvalRequirement == null
              ? null
              : {
                  'categoryContribution': _money(
                    approvalRequirement.categoryContribution,
                  ),
                  'globalShortfall': _money(
                    approvalRequirement.globalShortfall,
                  ),
                  'unfunded': _money(approvalRequirement.unfunded),
                  'globalAvailable': _money(
                    approvalRequirement.globalAvailable,
                  ),
                  'isFullyFundable': approvalRequirement.isFullyFundable,
                },
          'fundingDiagnostic': resultRequirement == null
              ? null
              : {
                  'advisory': true,
                  'mayBeStale': true,
                  'categoryContribution': _money(
                    resultRequirement.categoryContribution,
                  ),
                  'globalShortfall': _money(resultRequirement.globalShortfall),
                  'unfunded': _money(resultRequirement.unfunded),
                  'globalAvailable': _money(resultRequirement.globalAvailable),
                  'isFullyFundable': resultRequirement.isFullyFundable,
                },
        },
        'wallet': {
          'revision': data.wallet.revision,
          'asOf': data.wallet.asOf.toIso8601String(),
          'total': _money(controller.total.value),
          'allocated': _money(controller.allocated.value),
          'unallocated': _money(data.wallet.unallocated),
          'globalAvailable': _money(controller.globalAvailable.value),
          'reserved': _money(controller.reserved.value),
          'availableTotal': _money(controller.availableTotal.value),
        },
        'categories': controller.categories.value
            .map(
              (balance) => {
                'id': balance.category.id,
                'name': balance.category.name,
                'kind': balance.category.kind.name,
                'archived': balance.category.isArchived,
                'target': _money(balance.category.target),
                'balance': _money(balance.balance),
                'available': _money(balance.available),
                'reserved': _money(balance.reserved),
              },
            )
            .toList(growable: false),
        'transactions': {
          'requests': controller.requests.value
              .map(
                (request) => {
                  'id': request.id,
                  'kind': request is DepositRequest ? 'deposit' : 'payment',
                  'status': request.status.name,
                  'amount': _money(request.quote.amount),
                  'ledgerOperationId': request.ledgerOperationId,
                },
              )
              .toList(growable: false),
          'reservations': controller.reservations.value
              .map(
                (reservation) => {
                  'id': reservation.id,
                  'requestId': reservation.requestId,
                  'categoryId': reservation.categoryId,
                  'status': reservation.status.name,
                  'total': _money(reservation.total),
                  'categoryContribution': _money(
                    reservation.funding.categoryContribution,
                  ),
                  'globalContribution': _money(
                    reservation.funding.globalContribution,
                  ),
                },
              )
              .toList(growable: false),
          'ledgerCount': controller.ledger.value.length,
          'ledgerCountsByKind': {
            for (final kind in LedgerOperationKind.values)
              kind.name: controller.ledger.value
                  .where((operation) => operation.kind == kind)
                  .length,
          },
          'providerEventCount': controller.providerEvents.value.length,
          'referenceProviderSubmissionCount':
              harness.gateway.submittedRequests.length,
        },
      },
    ),
  ];
}

Map<String, Object?>? _money(Money? amount) => amount == null
    ? null
    : {'minorUnits': amount.minorUnits, 'kes': _kesLabel(amount)};

String _kesLabel(Money amount) {
  final whole = amount.minorUnits ~/ 100;
  final digits = whole.toString();
  final chunks = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    final start = end - 3 < 0 ? 0 : end - 3;
    chunks.add(digits.substring(start, end));
  }
  final groupedWhole = chunks.reversed.join(',');
  final cents = (amount.minorUnits % 100).toString().padLeft(2, '0');
  return 'KES $groupedWhole.$cents';
}

FundCategory _newCategory({
  required String fixtureName,
  String? name,
  int? targetKes,
}) {
  final spec = FlowFixture.categorySpec(fixtureName);
  return FundCategory(
    id: spec['id']! as String,
    walletId: FlowFixture.walletId,
    name: name ?? spec['name']! as String,
    kind: CategoryKind.values.byName(spec['kind']! as String),
    target: kes(targetKes ?? spec['targetKes']! as int),
    createdAt: FlowFixture.now,
  );
}

GlobalFundingApproval _approval({
  required PaymentQuote quote,
  required String quoteFixtureName,
}) => GlobalFundingApproval(
  quoteId: quote.id,
  ownerId: FlowFixture.ownerId,
  amount: kes(FlowFixture.approvalAmountKes(quoteFixtureName)),
  approvedAt: FlowFixture.now,
);

Future<List<FlowCheckpoint>> runCategoryManagementScenario() async {
  final harness = await FundsFlowHarness.start();
  try {
    final checkpoints = <FlowCheckpoint>[];
    checkpoints.addAll(
      _capture(
        harness,
        id: 'category.loaded',
        scenario: 'category-management',
        action: 'Load the funded wallet before category changes.',
      ),
    );

    await harness.execute(
      CreateCategoryCommand(
        commandId: FlowFixture.createCategoryCommandId,
        category: _newCategory(fixtureName: 'emergency'),
      ),
    );
    checkpoints.addAll(
      _capture(
        harness,
        id: 'category.created',
        scenario: 'category-management',
        action: 'Create an empty savings category.',
      ),
    );

    await harness.execute(
      EditCategoryCommand(
        commandId: FlowFixture.editCategoryCommandId,
        categoryId: FlowFixture.createdCategoryId,
        name: FlowFixture.categoryEdits['emergencyName']! as String,
        target: kes(FlowFixture.amountKes('emergencyEditedTarget')),
      ),
    );
    checkpoints.addAll(
      _capture(
        harness,
        id: 'category.edited',
        scenario: 'category-management',
        action: 'Rename the category and change its target.',
      ),
    );

    await harness.execute(
      ArchiveCategoryCommand(
        commandId: FlowFixture.archiveCategoryCommandId,
        categoryId: FlowFixture.createdCategoryId,
      ),
    );
    checkpoints.addAll(
      _capture(
        harness,
        id: 'category.archived',
        scenario: 'category-management',
        action: 'Archive the empty category while preserving its history.',
      ),
    );
    return checkpoints;
  } finally {
    await harness.dispose();
  }
}

Future<List<FlowCheckpoint>> runAllocationReleaseScenario() async {
  final harness = await FundsFlowHarness.start();
  try {
    final checkpoints = <FlowCheckpoint>[];
    await harness.execute(
      AllocateCommand(
        commandId: FlowFixture.allocateCommandId,
        categoryId: FlowFixture.couchId,
        amount: kes(FlowFixture.amountKes('couchAllocation')),
      ),
    );
    checkpoints.addAll(
      _capture(
        harness,
        id: 'funds.allocated',
        scenario: 'allocate-release',
        action: 'Move KES 5,000 from global funds into Couch.',
      ),
    );

    await harness.execute(
      ReleaseCommand(
        commandId: FlowFixture.releaseCommandId,
        categoryId: FlowFixture.couchId,
        amount: kes(FlowFixture.amountKes('couchRelease')),
      ),
    );
    checkpoints.addAll(
      _capture(
        harness,
        id: 'funds.released',
        scenario: 'allocate-release',
        action: 'Return KES 3,000 from Couch to global funds.',
      ),
    );
    return checkpoints;
  } finally {
    await harness.dispose();
  }
}

Future<List<FlowCheckpoint>> runDepositSuccessScenario() async {
  final gateway = ControlledPaymentGateway.accepted(gated: true);
  final harness = await FundsFlowHarness.start(
    seedName: 'empty',
    gateway: gateway,
  );
  try {
    final command = DepositCommand(
      commandId: FlowFixture.depositCommandId,
      quote: depositQuote('depositSuccess'),
    );
    final execution = harness.execute(command);
    await gateway.firstSubmission;
    final checkpoints = <FlowCheckpoint>[];
    checkpoints.addAll(
      _capture(
        harness,
        id: 'deposit.loading',
        scenario: 'deposit-success',
        action: 'Show the deposit as loading while provider acknowledgment is gated.',
      ),
    );
    gateway.releaseAcknowledgment();
    await execution;
    checkpoints.addAll(
      _capture(
        harness,
        id: 'deposit.pending',
        scenario: 'deposit-success',
        action:
            'Keep the wallet at zero after an accepted pending acknowledgment.',
      ),
    );

    final requestId = harness.snapshot.requests.single.id;
    final quote = depositQuote('depositSuccess');
    await harness.resolve(
      requestId: requestId,
      eventId: FlowFixture.eventId('depositSuccess'),
      outcome: ProviderResolutionOutcome.succeeded,
      reportedAmount: quote.amount.minorUnits ~/ 100,
    );
    await harness.refresh();
    checkpoints.addAll(
      _capture(
        harness,
        id: 'deposit.succeeded',
        scenario: 'deposit-success',
        action: 'Credit KES 50,000 after the trusted success result.',
      ),
    );
    return checkpoints;
  } finally {
    await harness.dispose();
  }
}

Future<List<FlowCheckpoint>> runDepositFailureScenario() async {
  final harness = await FundsFlowHarness.start(seedName: 'empty');
  try {
    await harness.execute(
      DepositCommand(
        commandId: FlowFixture.commandId('depositFailure'),
        quote: depositQuote('depositFailure'),
      ),
    );
    final checkpoints = <FlowCheckpoint>[];
    checkpoints.addAll(
      _capture(
        harness,
        id: 'deposit-failure.pending',
        scenario: 'deposit-failure',
        action: 'Show the deposit as pending before its provider result.',
      ),
    );
    await harness.resolve(
      requestId: harness.snapshot.requests.single.id,
      eventId: FlowFixture.eventId('depositFailure'),
      outcome: ProviderResolutionOutcome.failed,
    );
    await harness.refresh();
    checkpoints.addAll(
      _capture(
        harness,
        id: 'deposit-failure.failed',
        scenario: 'deposit-failure',
        action: 'Keep the wallet uncredited after confirmed failure.',
      ),
    );
    return checkpoints;
  } finally {
    await harness.dispose();
  }
}

Future<List<FlowCheckpoint>> runCouch18kScenario() async {
  final gateway = ControlledPaymentGateway.accepted(gated: true);
  final harness = await FundsFlowHarness.start(gateway: gateway);
  try {
    final quote = paymentQuote('couch18');
    final execution = harness.execute(
      SpendCommand(commandId: FlowFixture.spend18kCommandId, quote: quote),
    );
    await gateway.firstSubmission;
    final checkpoints = <FlowCheckpoint>[];
    checkpoints.addAll(
      _capture(
        harness,
        id: 'spend18.loading',
        scenario: 'couch-18000',
        action: 'Hold KES 18,000 while waiting for provider acknowledgment.',
      ),
    );
    gateway.releaseAcknowledgment();
    await execution;
    checkpoints.addAll(
      _capture(
        harness,
        id: 'spend18.pending',
        scenario: 'couch-18000',
        action: 'Keep Couch KES 2,000 available while the accepted payment is pending.',
      ),
    );
    await harness.resolve(
      requestId: harness.snapshot.requests.single.id,
      eventId: FlowFixture.eventId('couch18Success'),
      outcome: ProviderResolutionOutcome.succeeded,
      reportedAmount: quote.amount.minorUnits ~/ 100,
    );
    await harness.refresh();
    checkpoints.addAll(
      _capture(
        harness,
        id: 'spend18.succeeded',
        scenario: 'couch-18000',
        action: 'Settle the complete KES 18,000 spend.',
      ),
    );
    return checkpoints;
  } finally {
    await harness.dispose();
  }
}

Future<List<FlowCheckpoint>> runCouch23kApprovalScenario() async {
  final harness = await FundsFlowHarness.start();
  try {
    final quote = paymentQuote('couch23');
    final commandId = FlowFixture.spend23kCommandId;
    await harness.execute(SpendCommand(commandId: commandId, quote: quote));
    final checkpoints = <FlowCheckpoint>[];
    checkpoints.addAll(
      _capture(
        harness,
        id: 'spend23.approval-required',
        scenario: 'couch-23000-approved',
        action:
            'Ask explicit approval for the exact KES 3,000 global shortfall.',
      ),
    );

    final approval = _approval(quote: quote, quoteFixtureName: 'couch23');
    await harness.execute(
      SpendCommand(commandId: commandId, quote: quote, approval: approval),
    );
    checkpoints.addAll(
      _capture(
        harness,
        id: 'spend23.pending',
        scenario: 'couch-23000-approved',
        action: 'Reserve KES 20,000 from Couch and KES 3,000 globally.',
      ),
    );
    await harness.resolve(
      requestId: harness.snapshot.requests.single.id,
      eventId: FlowFixture.eventId('couch23Success'),
      outcome: ProviderResolutionOutcome.succeeded,
      reportedAmount: quote.amount.minorUnits ~/ 100,
    );
    await harness.refresh();
    checkpoints.addAll(
      _capture(
        harness,
        id: 'spend23.succeeded',
        scenario: 'couch-23000-approved',
        action: 'Settle the complete KES 23,000 spend once.',
      ),
    );
    return checkpoints;
  } finally {
    await harness.dispose();
  }
}

Future<List<FlowCheckpoint>> runSpendFailureScenario() async {
  final harness = await FundsFlowHarness.start();
  try {
    final quote = paymentQuote('couchFailure23');
    final approval = _approval(
      quote: quote,
      quoteFixtureName: 'couchFailure23',
    );
    await harness.execute(
      SpendCommand(
        commandId: FlowFixture.commandId('couchFailure'),
        quote: quote,
        approval: approval,
      ),
    );
    final checkpoints = <FlowCheckpoint>[];
    checkpoints.addAll(
      _capture(
        harness,
        id: 'spend-failure.pending',
        scenario: 'spend-confirmed-failure',
        action:
            'Show the full payment hold while awaiting the provider result.',
      ),
    );
    await harness.resolve(
      requestId: harness.snapshot.requests.single.id,
      eventId: FlowFixture.eventId('couchFailure'),
      outcome: ProviderResolutionOutcome.failed,
    );
    await harness.refresh();
    checkpoints.addAll(
      _capture(
        harness,
        id: 'spend-failure.failed',
        scenario: 'spend-confirmed-failure',
        action: 'Release the reservation and restore the seed balances.',
      ),
    );
    return checkpoints;
  } finally {
    await harness.dispose();
  }
}

Future<List<FlowCheckpoint>> runSpendUnknownScenario() async {
  final harness = await FundsFlowHarness.start();
  try {
    final quote = paymentQuote('couchUnknown23');
    await harness.execute(
      SpendCommand(
        commandId: FlowFixture.commandId('couchUnknown'),
        quote: quote,
        approval: _approval(quote: quote, quoteFixtureName: 'couchUnknown23'),
      ),
    );
    final checkpoints = <FlowCheckpoint>[];
    checkpoints.addAll(
      _capture(
        harness,
        id: 'spend-unknown.pending',
        scenario: 'spend-unknown',
        action: 'Show the approved payment hold while pending.',
      ),
    );
    await harness.resolve(
      requestId: harness.snapshot.requests.single.id,
      eventId: FlowFixture.eventId('couchUnknown'),
      outcome: ProviderResolutionOutcome.unknown,
    );
    await harness.refresh();
    checkpoints.addAll(
      _capture(
        harness,
        id: 'spend-unknown.awaiting-verification',
        scenario: 'spend-unknown',
        action: 'Keep the reservation held until a verified result arrives.',
      ),
    );
    return checkpoints;
  } finally {
    await harness.dispose();
  }
}

Future<List<FlowCheckpoint>> runGatewayAcknowledgmentScenario() async {
  final checkpoints = <FlowCheckpoint>[];

  final rejectedGateway = ControlledPaymentGateway.rejected();
  final rejectedHarness = await FundsFlowHarness.start(
    gateway: rejectedGateway,
  );
  try {
    await rejectedHarness.execute(
      SpendCommand(
        commandId: FlowFixture.gatewayRejectedCommandId,
        quote: paymentQuote('gatewayRejected18'),
      ),
    );
    checkpoints.addAll(
      _capture(
        rejectedHarness,
        id: 'gateway.rejected',
        scenario: 'gateway-acknowledgments',
        action:
            'Release the payment hold after an immediate provider rejection.',
      ),
    );
  } finally {
    await rejectedHarness.dispose();
  }

  final unknownGateway = ControlledPaymentGateway.unknown();
  final unknownHarness = await FundsFlowHarness.start(gateway: unknownGateway);
  try {
    await unknownHarness.execute(
      SpendCommand(
        commandId: FlowFixture.gatewayUnknownCommandId,
        quote: paymentQuote('gatewayUnknown18'),
      ),
    );
    checkpoints.addAll(
      _capture(
        unknownHarness,
        id: 'gateway.unknown',
        scenario: 'gateway-acknowledgments',
        action:
            'Keep the payment hold when provider acknowledgment is unknown.',
      ),
    );
  } finally {
    await unknownHarness.dispose();
  }

  return checkpoints;
}

Future<List<FlowCheckpoint>> runSpend36kScenario() async {
  final harness = await FundsFlowHarness.start();
  try {
    await harness.execute(
      SpendCommand(
        commandId: FlowFixture.spend36kCommandId,
        quote: paymentQuote('couch36'),
      ),
    );
    return _capture(
      harness,
      id: 'spend36.rejected',
      scenario: 'couch-36000-insufficient',
      action: 'Block a KES 36,000 spend because KES 1,000 remains unfunded.',
    );
  } finally {
    await harness.dispose();
  }
}

Future<List<FlowCheckpoint>> runCouch20kExactScenario() async {
  final harness = await FundsFlowHarness.start();
  try {
    final quote = paymentQuote('couch20');
    await harness.execute(
      SpendCommand(commandId: FlowFixture.spend20kCommandId, quote: quote),
    );
    final checkpoints = <FlowCheckpoint>[];
    checkpoints.addAll(
      _capture(
        harness,
        id: 'spend20.pending',
        scenario: 'couch-20000-exact',
        action: 'Reserve the exact Couch balance without global approval.',
      ),
    );
    await harness.resolve(
      requestId: harness.snapshot.requests.single.id,
      eventId: FlowFixture.eventId('couch20Success'),
      outcome: ProviderResolutionOutcome.succeeded,
      reportedAmount: quote.amount.minorUnits ~/ 100,
    );
    await harness.refresh();
    checkpoints.addAll(
      _capture(
        harness,
        id: 'spend20.succeeded',
        scenario: 'couch-20000-exact',
        action: 'Settle the exact KES 20,000 Couch spend.',
      ),
    );
    return checkpoints;
  } finally {
    await harness.dispose();
  }
}

Future<List<FlowCheckpoint>> runDuplicateCommandCallbackScenario() async {
  final harness = await FundsFlowHarness.start();
  try {
    final quote = paymentQuote('couchDuplicate18');
    final command = SpendCommand(
      commandId: FlowFixture.commandId('couchDuplicate'),
      quote: quote,
    );
    await harness.execute(command);
    final checkpoints = <FlowCheckpoint>[];
    checkpoints.addAll(
      _capture(
        harness,
        id: 'duplicate.first-command',
        scenario: 'duplicate-command-callback',
        action: 'Record the first payment request and reservation.',
      ),
    );

    await harness.execute(command);
    checkpoints.addAll(
      _capture(
        harness,
        id: 'duplicate.replayed-command',
        scenario: 'duplicate-command-callback',
        action: 'Replay the same command without another provider submission.',
      ),
    );

    final requestId = harness.snapshot.requests.single.id;
    await harness.resolve(
      requestId: requestId,
      eventId: FlowFixture.eventId('couchDuplicateSuccess'),
      outcome: ProviderResolutionOutcome.succeeded,
      reportedAmount: quote.amount.minorUnits ~/ 100,
    );
    await harness.refresh();
    checkpoints.addAll(
      _capture(
        harness,
        id: 'duplicate.first-callback',
        scenario: 'duplicate-command-callback',
        action: 'Apply the first trusted success result.',
      ),
    );

    await harness.resolve(
      requestId: requestId,
      eventId: FlowFixture.eventId('couchDuplicateSuccess'),
      outcome: ProviderResolutionOutcome.succeeded,
      reportedAmount: quote.amount.minorUnits ~/ 100,
    );
    await harness.refresh();
    checkpoints.addAll(
      _capture(
        harness,
        id: 'duplicate.replayed-callback',
        scenario: 'duplicate-command-callback',
        action: 'Ignore the duplicate callback without adding another debit.',
      ),
    );
    return checkpoints;
  } finally {
    await harness.dispose();
  }
}

Future<List<FlowCheckpoint>> runStaleApprovalScenario() async {
  final harness = await FundsFlowHarness.start();
  try {
    final quote = paymentQuote('couchStale23');
    final commandId = FlowFixture.commandId('couchStale');
    await harness.execute(SpendCommand(commandId: commandId, quote: quote));
    final previewRequirement =
        harness.controller.commandState.value.approvalRequirement!;
    final approval = GlobalFundingApproval(
      quoteId: quote.id,
      ownerId: FlowFixture.ownerId,
      amount: previewRequirement.globalShortfall,
      approvedAt: FlowFixture.now,
    );
    final checkpoints = <FlowCheckpoint>[];
    checkpoints.addAll(
      _capture(
        harness,
        id: 'stale-approval.previewed',
        scenario: 'stale-approval',
        action: 'Preview KES 3,000 global approval against current funds.',
      ),
    );

    // Simulate another caller changing funds after preview through the shared repository.
    await harness.application.execute(
      AllocateCommand(
        commandId: FlowFixture.allocateRentCommandId,
        categoryId: FlowFixture.rentId,
        amount: kes(FlowFixture.amountKes('rentAllocationForStaleApproval')),
      ),
    );
    await harness.refresh();
    checkpoints.addAll(
      _capture(
        harness,
        id: 'stale-approval.funds-changed',
        scenario: 'stale-approval',
        action: 'Another operation allocates KES 13,000 after the KES 3,000 preview.',
      ),
    );

    await harness.execute(
      SpendCommand(commandId: commandId, quote: quote, approval: approval),
    );
    checkpoints.addAll(
      _capture(
        harness,
        id: 'stale-approval.rejected',
        scenario: 'stale-approval',
        action: 'Recompute current funding and block the now-unfunded payment.',
      ),
    );
    return checkpoints;
  } finally {
    await harness.dispose();
  }
}

Future<List<FlowCheckpoint>> runGlobalOnlyHoldArchiveScenario() async {
  final harness = await FundsFlowHarness.start();
  try {
    final categoryId = FlowFixture.emptyCategoryId;
    await harness.execute(
      CreateCategoryCommand(
        commandId: FlowFixture.createEmptyCategoryCommandId,
        category: _newCategory(fixtureName: 'emptyPayment'),
      ),
    );
    final quote = paymentQuote('emptyCategory10');
    await harness.execute(
      SpendCommand(
        commandId: FlowFixture.spendEmptyCategoryCommandId,
        quote: quote,
        approval: _approval(quote: quote, quoteFixtureName: 'emptyCategory10'),
      ),
    );
    final checkpoints = <FlowCheckpoint>[];
    checkpoints.addAll(
      _capture(
        harness,
        id: 'global-only.pending',
        scenario: 'global-only-hold-blocks-archive',
        action: 'Hold KES 10,000 globally for a zero-balance category payment.',
      ),
    );

    await harness.execute(
      ArchiveCategoryCommand(
        commandId: FlowFixture.archiveEmptyCategoryCommandId,
        categoryId: categoryId,
      ),
    );
    checkpoints.addAll(
      _capture(
        harness,
        id: 'global-only.archive-blocked',
        scenario: 'global-only-hold-blocks-archive',
        action:
            'Keep the zero-balance category active while its payment is held.',
      ),
    );

    await harness.resolve(
      requestId: harness.snapshot.requests.single.id,
      eventId: FlowFixture.eventId('emptyCategoryFailure'),
      outcome: ProviderResolutionOutcome.failed,
    );
    await harness.refresh();
    checkpoints.addAll(
      _capture(
        harness,
        id: 'global-only.hold-released',
        scenario: 'global-only-hold-blocks-archive',
        action: 'Release the global hold after confirmed provider failure.',
      ),
    );
    await harness.execute(
      ArchiveCategoryCommand(
        commandId: FlowFixture.archiveAfterHoldCommandId,
        categoryId: categoryId,
      ),
    );
    checkpoints.addAll(
      _capture(
        harness,
        id: 'global-only.archive-allowed',
        scenario: 'global-only-hold-blocks-archive',
        action: 'Archive the category after its pending payment has resolved.',
      ),
    );
    return checkpoints;
  } finally {
    await harness.dispose();
  }
}

Future<List<FlowCheckpoint>> runExpiredQuoteScenario() async {
  final clock = FixedFundsClock();
  final harness = await FundsFlowHarness.start(clock: clock);
  try {
    final quote = paymentQuote('couchExpired18');
    clock.advance(
      Duration(seconds: FlowFixture.quoteTtlSeconds('couchExpired18')),
    );
    await harness.execute(
      SpendCommand(
        commandId: FlowFixture.commandId('expiredSpend'),
        quote: quote,
      ),
    );
    return _capture(
      harness,
      id: 'quote.expired',
      scenario: 'expired-quote',
      action:
          'Reject the quote at its expiry boundary before provider submission.',
    );
  } finally {
    await harness.dispose();
  }
}

Future<List<FlowCheckpoint>> runAllReferenceScenarios() async {
  final checkpoints = <FlowCheckpoint>[];
  checkpoints.addAll(await runCategoryManagementScenario());
  checkpoints.addAll(await runAllocationReleaseScenario());
  checkpoints.addAll(await runDepositSuccessScenario());
  checkpoints.addAll(await runDepositFailureScenario());
  checkpoints.addAll(await runCouch18kScenario());
  checkpoints.addAll(await runCouch23kApprovalScenario());
  checkpoints.addAll(await runSpendFailureScenario());
  checkpoints.addAll(await runSpendUnknownScenario());
  checkpoints.addAll(await runGatewayAcknowledgmentScenario());
  checkpoints.addAll(await runSpend36kScenario());
  checkpoints.addAll(await runCouch20kExactScenario());
  checkpoints.addAll(await runDuplicateCommandCallbackScenario());
  checkpoints.addAll(await runStaleApprovalScenario());
  checkpoints.addAll(await runGlobalOnlyHoldArchiveScenario());
  checkpoints.addAll(await runExpiredQuoteScenario());
  return checkpoints;
}

Map<String, Object?> buildReferenceFlowEvidence(
  List<FlowCheckpoint> checkpoints,
) => {
  'schemaVersion': 1,
  'sourceInputs': 'test/fixtures/funds_inputs.json',
  'providerScope': 'reference provider fixture; no live provider or browser QA',
  'fixedClockUtc': FlowFixture.now.toIso8601String(),
  'money': {
    'currency': 'KES',
    'storedUnit': 'minor units',
    'minorUnitsPerKes': 100,
  },
  'checkpoints': checkpoints.map((checkpoint) => checkpoint.toJson()).toList(),
};
