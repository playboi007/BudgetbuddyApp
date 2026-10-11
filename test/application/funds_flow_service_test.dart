import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:budgetbuddy_app/application/contracts.dart';
import 'package:budgetbuddy_app/application/funds_flow_service.dart';
import 'package:budgetbuddy_app/application/funds_repository.dart';
import 'package:budgetbuddy_app/budgetbuddy_models.dart';
import 'package:budgetbuddy_app/infrastructure/in_memory_funds_repository.dart';
import 'package:flutter_test/flutter_test.dart';

late Map<String, dynamic> testInputs;
late DateTime testNow;
Money kes(int amount) => Money.fromKes(amount);

FundCategory testCategory({String? id, int? target}) {
  final category = testInputs['category'] as Map<String, dynamic>;
  return FundCategory(
    id: id ?? category['id'] as String,
    walletId: (testInputs['wallet'] as Map<String, dynamic>)['id'] as String,
    name: id == null || id == category['id'] ? category['name'] as String : id,
    kind: CategoryKind.values.byName(category['kind'] as String),
    target: kes(target ?? category['targetKes'] as int),
    createdAt: DateTime.parse(category['createdAt'] as String),
  );
}

FundsData seed({int? global, int? category}) => FundsData(
  wallet: WalletSnapshot(
    wallet: Wallet(
      id: (testInputs['wallet'] as Map<String, dynamic>)['id'] as String,
      ownerId:
          (testInputs['wallet'] as Map<String, dynamic>)['ownerId'] as String,
      createdAt: DateTime.parse(
        (testInputs['wallet'] as Map<String, dynamic>)['createdAt'] as String,
      ),
    ),
    revision:
        (testInputs['wallet'] as Map<String, dynamic>)['revision'] as String,
    unallocated: kes(global ?? testInputs['globalAvailableKes'] as int),
    globalReserved: Money.zero,
    categories: [
      CategoryBalance(
        category: testCategory(),
        balance: kes(
          category ??
              (testInputs['category'] as Map<String, dynamic>)['balanceKes']
                  as int,
        ),
        reserved: Money.zero,
      ),
    ],
    asOf: testNow,
  ),
);

PaymentQuote paymentQuote({
  required int amount,
  String id = 'quote-1',
  String categoryId = 'food',
}) {
  final recipient = testInputs['paymentRecipient'] as Map<String, dynamic>;
  final time = testInputs['time'] as Map<String, dynamic>;
  final createdOffset = time['quoteCreatedOffsetMinutes'] as int;
  final expiryOffset = time['quoteExpiryOffsetMinutes'] as int;
  return PaymentQuote(
    id: id,
    walletId: (testInputs['wallet'] as Map<String, dynamic>)['id'] as String,
    categoryId: categoryId,
    recipient: switch (recipient['type'] as String) {
      'till' => TillRecipient(recipient['tillNumber'] as String),
      _ => throw StateError('Unsupported fixture recipient type.'),
    },
    amount: kes(amount),
    createdAt: testNow.add(Duration(minutes: createdOffset)),
    expiresAt: testNow.add(Duration(minutes: expiryOffset)),
  );
}

DepositQuote depositQuote({int amount = 5000, String id = 'deposit-quote'}) =>
    DepositQuote(
      id: id,
      walletId: (testInputs['wallet'] as Map<String, dynamic>)['id'] as String,
      payer: MpesaPhoneNumber(testInputs['depositPayer'] as String),
      amount: kes(amount),
      createdAt: testNow.add(
        Duration(
          minutes:
              (testInputs['time']
                      as Map<String, dynamic>)['quoteCreatedOffsetMinutes']
                  as int,
        ),
      ),
      expiresAt: testNow.add(
        Duration(
          minutes:
              (testInputs['time']
                      as Map<String, dynamic>)['quoteExpiryOffsetMinutes']
                  as int,
        ),
      ),
    );

final class _FakeGateway implements PaymentGateway {
  _FakeGateway({GatewayAcknowledgment? response, this.pending})
    : response = response ?? _defaultAcknowledgment();

  final GatewayAcknowledgment response;
  final Completer<GatewayAcknowledgment>? pending;
  final Completer<void> called = Completer<void>();
  int calls = 0;
  TransactionRequest? lastRequest;

  @override
  Future<GatewayAcknowledgment> submit(TransactionRequest request) {
    calls++;
    lastRequest = request;
    if (!called.isCompleted) called.complete();
    final baseCheckoutId =
        (testInputs['gateway'] as Map<String, dynamic>)['checkoutRequestId']
            as String;
    final acknowledgment =
        calls == 1 || response.identifiers.checkoutRequestId != baseCheckoutId
        ? response
        : GatewayAcknowledgment(
            status: response.status,
            identifiers: ProviderIdentifiers(
              merchantRequestId: response.identifiers.merchantRequestId,
              checkoutRequestId: '$baseCheckoutId-$calls',
              originatorConversationId:
                  response.identifiers.originatorConversationId,
              conversationId: response.identifiers.conversationId,
              transactionReceipt: response.identifiers.transactionReceipt,
            ),
            description: response.description,
          );
    return pending?.future ?? Future.value(acknowledgment);
  }

  static GatewayAcknowledgment _defaultAcknowledgment() {
    final gateway = testInputs['gateway'] as Map<String, dynamic>;
    return GatewayAcknowledgment(
      status: GatewayAcknowledgmentStatus.values.byName(
        gateway['acknowledgment'] as String,
      ),
      identifiers: ProviderIdentifiers(
        checkoutRequestId: gateway['checkoutRequestId'] as String,
      ),
      description: gateway['description'] as String,
    );
  }
}

final class _ThrowingGateway implements PaymentGateway {
  int calls = 0;

  @override
  Future<GatewayAcknowledgment> submit(TransactionRequest request) async {
    calls++;
    throw StateError('connection timed out after dispatch');
  }
}

FundsFlowService service(
  FundsRepository repository,
  PaymentGateway gateway, {
  String? ownerId,
  String? walletId,
}) => FundsFlowService(
  actor: ActorContext(
    ownerId:
        ownerId ??
        (testInputs['actor'] as Map<String, dynamic>)['ownerId'] as String,
    walletId:
        walletId ??
        (testInputs['actor'] as Map<String, dynamic>)['walletId'] as String,
  ),
  repository: repository,
  gateway: gateway,
  clock: () => testNow,
);

ProviderResolution result({
  required String eventId,
  required String commandId,
  required ProviderResolutionOutcome outcome,
  required String receipt,
  required int amount,
  String? checkoutId,
}) => ProviderResolution(
  eventId: eventId,
  requestId: 'request:$commandId',
  outcome: outcome,
  identifiers: ProviderIdentifiers(
    checkoutRequestId:
        checkoutId ??
        (testInputs['gateway'] as Map<String, dynamic>)['checkoutRequestId']
            as String,
    transactionReceipt: receipt,
  ),
  description: outcome == ProviderResolutionOutcome.succeeded
      ? 'Completed'
      : 'Declined',
  reportedAmount: kes(amount),
);

void main() {
  setUpAll(() async {
    testInputs = jsonDecode(
      await File('test/application/funds_test_inputs.json').readAsString(),
    ) as Map<String, dynamic>;
  });
  setUp(() {
    final time = testInputs['time'] as Map<String, dynamic>;
    testNow = DateTime.parse(time['now'] as String);
  });

  test(
    'same-key retry while dispatch is pending reserves and dispatches once',
    () async {
      final repository = InMemoryFundsRepository(seed: seed());
      final pending = Completer<GatewayAcknowledgment>();
      final gateway = _FakeGateway(pending: pending);
      final app = service(repository, gateway);
      final command = SpendCommand(
        commandId: 'pay-once',
        quote: paymentQuote(amount: 15000),
      );

      final firstCall = app.execute(command);
      await gateway.called.future;
      final repeated = await app.execute(command);

      expect(gateway.calls, 1);
      expect(repeated.disposition, CommandDisposition.submitted);
      expect(repeated.requestId, 'request:pay-once');
      expect(repeated.data.wallet.categories.single.reserved, kes(15000));
      expect(repeated.data.wallet.categories.single.available, kes(5000));
      expect(repeated.data.requests, hasLength(1));

      final conflict = await app.execute(
        SpendCommand(commandId: 'pay-once', quote: paymentQuote(amount: 16000)),
      );
      expect(conflict.failure?.code, FundsFailureCode.idempotencyConflict);
      expect(gateway.calls, 1);

      pending.complete(
        const GatewayAcknowledgment(
          status: GatewayAcknowledgmentStatus.accepted,
          identifiers: ProviderIdentifiers(checkoutRequestId: 'checkout-1'),
          description: 'Accepted',
        ),
      );
      await firstCall;
    },
  );

  test(
    'shared repository serializes competing spends across service instances',
    () async {
      final repository = InMemoryFundsRepository(seed: seed());
      final gateway = _FakeGateway();
      final first = service(repository, gateway);
      final second = service(repository, gateway);

      final results = await Future.wait([
        first.execute(
          SpendCommand(
            commandId: 'race-a',
            quote: paymentQuote(amount: 15000, id: 'quote-a'),
          ),
        ),
        second.execute(
          SpendCommand(
            commandId: 'race-b',
            quote: paymentQuote(amount: 15000, id: 'quote-b'),
          ),
        ),
      ]);

      expect(
        results.where(
          (item) => item.disposition == CommandDisposition.submitted,
        ),
        hasLength(1),
      );
      expect(
        results.where(
          (item) => item.failure?.code == FundsFailureCode.insufficientFunds,
        ),
        hasLength(1),
      );
      expect(gateway.calls, 1);
      final data = await first.load();
      expect(data.wallet.categories.single.reserved, kes(15000));
      expect(data.wallet.categories.single.available, kes(5000));
      expect(data.wallet.total, kes(20000));
    },
  );

  test('foreign actors cannot load or mutate another wallet', () async {
    final repository = InMemoryFundsRepository(seed: seed());
    final foreign = service(repository, _FakeGateway(), ownerId: 'owner-2');

    await expectLater(foreign.load(), throwsA(isA<FundsException>()));
    await expectLater(
      foreign.execute(
        AllocateCommand(
          commandId: 'foreign-allocation',
          categoryId: 'food',
          amount: kes(1),
        ),
      ),
      throwsA(isA<FundsException>()),
    );
  });

  test(
    'approval retry keeps quote key and checks the latest shortfall',
    () async {
      final repository = InMemoryFundsRepository(seed: seed(global: 10000));
      final gateway = _FakeGateway();
      final app = service(repository, gateway);
      final quote = paymentQuote(amount: 23000);

      final waiting = await app.execute(
        SpendCommand(commandId: 'approved-pay', quote: quote),
      );
      expect(waiting.disposition, CommandDisposition.requiresGlobalApproval);
      expect(waiting.fundingRequirement?.globalShortfall, kes(3000));
      expect(waiting.data.requests, isEmpty);
      expect(gateway.calls, 0);

      await app.execute(
        AllocateCommand(
          commandId: 'increase-category',
          categoryId: 'food',
          amount: kes(2000),
        ),
      );
      final staleApproval = GlobalFundingApproval(
        quoteId: quote.id,
        ownerId: 'owner-1',
        amount: kes(3000),
        approvedAt: testNow,
      );
      final stale = await app.execute(
        SpendCommand(
          commandId: 'approved-pay',
          quote: quote,
          approval: staleApproval,
        ),
      );
      expect(stale.failure?.code, FundsFailureCode.invalidApproval);
      expect(stale.data.requests, isEmpty);
      expect(gateway.calls, 0);

      final fresh = await app.execute(
        SpendCommand(
          commandId: 'approved-pay',
          quote: quote,
          approval: GlobalFundingApproval(
            quoteId: quote.id,
            ownerId: 'owner-1',
            amount: kes(1000),
            approvedAt: testNow,
          ),
        ),
      );
      expect(fresh.disposition, CommandDisposition.submitted);
      expect(gateway.calls, 1);
      final outgoing = fresh.data.requests.single as OutgoingPaymentRequest;
      expect(outgoing.funding.categoryContribution, kes(22000));
      expect(outgoing.funding.globalContribution, kes(1000));
    },
  );

  test(
    'provider failure releases holds while dispatch ambiguity keeps them',
    () async {
      final rejectedGateway = _FakeGateway(
        response: const GatewayAcknowledgment(
          status: GatewayAcknowledgmentStatus.rejected,
          identifiers: ProviderIdentifiers(checkoutRequestId: 'checkout-1'),
          description: 'Rejected by provider',
        ),
      );
      final rejectedApp = service(
        InMemoryFundsRepository(seed: seed()),
        rejectedGateway,
      );
      final rejected = await rejectedApp.execute(
        SpendCommand(
          commandId: 'rejected-pay',
          quote: paymentQuote(amount: 10000),
        ),
      );
      expect(rejected.data.wallet.categories.single.reserved, Money.zero);
      expect(rejected.data.wallet.categories.single.balance, kes(20000));
      expect(rejected.data.requests.single.status, TransactionStatus.failed);
      expect(rejected.data.ledger, isEmpty);

      final unknownApp = service(
        InMemoryFundsRepository(seed: seed()),
        _ThrowingGateway(),
      );
      final unknown = await unknownApp.execute(
        SpendCommand(
          commandId: 'unknown-pay',
          quote: paymentQuote(amount: 10000),
        ),
      );
      expect(
        unknown.data.requests.single.status,
        TransactionStatus.awaitingVerification,
      );
      expect(unknown.data.wallet.categories.single.reserved, kes(10000));
      expect(unknown.data.wallet.categories.single.balance, kes(20000));
      expect(unknown.data.ledger, isEmpty);
    },
  );

  test('success posts once, repeated result is harmless, and late conflict reconciles', () async {
    final repository = InMemoryFundsRepository(seed: seed());
    final app = service(repository, _FakeGateway());
    await app.execute(
      SpendCommand(commandId: 'settled-pay', quote: paymentQuote(amount: 6000)),
    );

    final success = result(
      eventId: 'event-success',
      commandId: 'settled-pay',
      outcome: ProviderResolutionOutcome.succeeded,
      receipt: 'R-100',
      amount: 6000,
    );
    final applied = await app.recordProviderResult(success);
    final duplicate = await app.recordProviderResult(success);
    final duplicateReceipt = await app.recordProviderResult(
      result(
        eventId: 'event-success-replay',
        commandId: 'settled-pay',
        outcome: ProviderResolutionOutcome.succeeded,
        receipt: 'R-100',
        amount: 6000,
      ),
    );
    expect(applied.data.wallet.categories.single.balance, kes(14000));
    expect(duplicate.data.ledger, hasLength(1));
    expect(duplicateReceipt.data.ledger, hasLength(1));
    expect(
      duplicateReceipt.data.reservations.single.status,
      ReservationStatus.consumed,
    );
    expect(duplicateReceipt.data.providerEvents, hasLength(2));

    final lateFailure = await app.recordProviderResult(
      result(
        eventId: 'event-late-failure',
        commandId: 'settled-pay',
        outcome: ProviderResolutionOutcome.failed,
        receipt: 'R-100',
        amount: 6000,
      ),
    );
    expect(
      lateFailure.data.requests.single.status,
      TransactionStatus.reconciliationRequired,
    );
    expect(lateFailure.data.wallet.categories.single.balance, kes(14000));
    expect(lateFailure.data.ledger, hasLength(1));
    expect(
      lateFailure.data.reservations.single.status,
      ReservationStatus.consumed,
    );
  });

  test(
    'mismatched result stays quarantined and cannot later settle the hold',
    () async {
      final app = service(
        InMemoryFundsRepository(seed: seed()),
        _FakeGateway(),
      );
      await app.execute(
        SpendCommand(
          commandId: 'mismatch-pay',
          quote: paymentQuote(amount: 6000),
        ),
      );

      final mismatch = await app.recordProviderResult(
        result(
          eventId: 'event-bad-amount',
          commandId: 'mismatch-pay',
          outcome: ProviderResolutionOutcome.succeeded,
          receipt: 'R-200',
          amount: 5999,
        ),
      );
      final later = await app.recordProviderResult(
        result(
          eventId: 'event-corrected',
          commandId: 'mismatch-pay',
          outcome: ProviderResolutionOutcome.succeeded,
          receipt: 'R-200',
          amount: 6000,
        ),
      );

      expect(
        mismatch.data.requests.single.status,
        TransactionStatus.reconciliationRequired,
      );
      expect(
        mismatch.data.providerEvents.last.disposition,
        ProviderEventDisposition.quarantined,
      );
      expect(
        later.data.requests.single.status,
        TransactionStatus.reconciliationRequired,
      );
      expect(
        later.data.providerEvents.last.disposition,
        ProviderEventDisposition.quarantined,
      );
      expect(later.data.wallet.categories.single.balance, kes(20000));
      expect(later.data.wallet.categories.single.reserved, kes(6000));
      expect(later.data.ledger, isEmpty);
      expect(later.data.reservations.single.status, ReservationStatus.active);
    },
  );

  test('a provider receipt cannot settle two different requests', () async {
    final app = service(
      InMemoryFundsRepository(seed: seed(category: 20000)),
      _FakeGateway(),
    );
    await app.execute(
      SpendCommand(
        commandId: 'receipt-a',
        quote: paymentQuote(amount: 5000, id: 'receipt-quote-a'),
      ),
    );
    await app.execute(
      SpendCommand(
        commandId: 'receipt-b',
        quote: paymentQuote(amount: 5000, id: 'receipt-quote-b'),
      ),
    );
    await app.recordProviderResult(
      result(
        eventId: 'receipt-event-a',
        commandId: 'receipt-a',
        outcome: ProviderResolutionOutcome.succeeded,
        receipt: 'R-SHARED',
        amount: 5000,
      ),
    );
    final collision = await app.recordProviderResult(
      result(
        eventId: 'receipt-event-b',
        commandId: 'receipt-b',
        outcome: ProviderResolutionOutcome.succeeded,
        receipt: 'R-SHARED',
        amount: 5000,
        checkoutId: 'checkout-1-2',
      ),
    );

    expect(collision.data.ledger, hasLength(1));
    expect(collision.data.wallet.categories.single.balance, kes(15000));
    expect(
      collision.data.requests.map((item) => item.status),
      contains(TransactionStatus.reconciliationRequired),
    );
    expect(collision.data.reservations.last.status, ReservationStatus.active);
  });

  test(
    'deposit credits global funds only after verified success, once',
    () async {
      final app = service(
        InMemoryFundsRepository(seed: seed(category: 0)),
        _FakeGateway(),
      );
      await app.execute(
        DepositCommand(commandId: 'deposit-once', quote: depositQuote()),
      );
      final resolution = ProviderResolution(
        eventId: 'deposit-result',
        requestId: 'request:deposit-once',
        outcome: ProviderResolutionOutcome.succeeded,
        identifiers: const ProviderIdentifiers(transactionReceipt: 'D-100'),
        description: 'Deposit complete',
        reportedAmount: kes(5000),
      );
      final applied = await app.recordProviderResult(resolution);
      final repeated = await app.recordProviderResult(resolution);

      expect(applied.data.wallet.unallocated, kes(5000));
      expect(repeated.data.wallet.unallocated, kes(5000));
      expect(repeated.data.wallet.total, kes(5000));
      expect(repeated.data.ledger, hasLength(1));
    },
  );
}
