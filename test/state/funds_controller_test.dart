import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:budgetbuddy_app/application/contracts.dart';
import 'package:budgetbuddy_app/budgetbuddy_models.dart';
import 'package:budgetbuddy_app/state/funds_controller.dart';
import 'package:flutter_test/flutter_test.dart';

late ControllerTestInputs testInputs;

DateTime get now => testInputs.now;

Money kes(int amount) => Money.fromKes(amount);

PaymentQuote payment({int? amount, String? id}) => PaymentQuote(
  id: id ?? testInputs.paymentQuoteId,
  walletId: testInputs.walletId,
  categoryId: testInputs.paymentCategoryId,
  recipient: TillRecipient(testInputs.tillNumber),
  amount: kes(amount ?? testInputs.paymentAmountKes),
  createdAt: now,
  expiresAt: now.add(testInputs.quoteLifetime),
);

FundsData snapshot({
  String? revision,
  int? global,
  int? globalReserved,
  int? category,
  int? categoryReserved,
  Iterable<TransactionRequest>? requests,
  Iterable<PaymentReservation>? reservations,
  Iterable<LedgerOperation>? ledger,
  Iterable<ProviderEvent>? providerEvents,
}) {
  final categoryKind = switch (testInputs.categoryKind) {
    'spending' => CategoryKind.spending,
    'savingsGoal' => CategoryKind.savingsGoal,
    _ => throw StateError('Unknown fixture category kind.'),
  };
  return FundsData(
    wallet: WalletSnapshot(
      wallet: Wallet(
        id: testInputs.walletId,
        ownerId: testInputs.ownerId,
        createdAt: now,
      ),
      revision: revision ?? testInputs.walletRevision,
      unallocated: kes(global ?? testInputs.walletGlobalKes),
      globalReserved: kes(globalReserved ?? testInputs.walletGlobalReservedKes),
      categories: [
        CategoryBalance(
          category: FundCategory(
            id: testInputs.categoryId,
            walletId: testInputs.walletId,
            name: testInputs.categoryName,
            kind: categoryKind,
            target: kes(testInputs.categoryTargetKes),
            createdAt: now,
          ),
          balance: kes(category ?? testInputs.walletCategoryBalanceKes),
          reserved: kes(
            categoryReserved ?? testInputs.walletCategoryReservedKes,
          ),
        ),
      ],
      asOf: now,
    ),
    requests: requests ?? const [],
    reservations: reservations ?? const [],
    ledger: ledger ?? const [],
    providerEvents: providerEvents ?? const [],
  );
}

final class ControllerTestInputs {
  ControllerTestInputs._({
    required this.time,
    required this.identity,
    required this.wallet,
    required this.category,
    required this.payment,
    required this.deposit,
    required this.provider,
    required this.references,
  });

  factory ControllerTestInputs.decode(String json) {
    final root = _readObject(jsonDecode(json));
    return ControllerTestInputs._(
      time: _readObject(root['time']),
      identity: _readObject(root['identity']),
      wallet: _readObject(root['wallet']),
      category: _readObject(root['category']),
      payment: _readObject(root['payment']),
      deposit: _readObject(root['deposit']),
      provider: _readObject(root['provider']),
      references: _readObject(root['references']),
    );
  }

  final Map<String, Object?> time;
  final Map<String, Object?> identity;
  final Map<String, Object?> wallet;
  final Map<String, Object?> category;
  final Map<String, Object?> payment;
  final Map<String, Object?> deposit;
  final Map<String, Object?> provider;
  final Map<String, Object?> references;

  DateTime get now => DateTime.parse(_string(time, 'nowUtc')).toUtc();
  Duration get quoteLifetime =>
      Duration(seconds: _integer(time, 'quoteLifetimeSeconds'));
  Duration get settlementDelay =>
      Duration(seconds: _integer(time, 'settlementDelaySeconds'));
  String get walletId => _string(identity, 'walletId');
  String get ownerId => _string(identity, 'ownerId');
  String get walletRevision => _string(wallet, 'revision');
  int get walletGlobalKes => _integer(wallet, 'globalKes');
  int get walletGlobalReservedKes => _integer(wallet, 'globalReservedKes');
  int get walletCategoryBalanceKes => _integer(wallet, 'categoryBalanceKes');
  int get walletCategoryReservedKes => _integer(wallet, 'categoryReservedKes');
  String get categoryId => _string(category, 'id');
  String get categoryName => _string(category, 'name');
  String get categoryKind => _string(category, 'kind');
  int get categoryTargetKes => _integer(category, 'targetKes');
  String get paymentQuoteId => _string(payment, 'quoteId');
  String get paymentCategoryId => _string(payment, 'categoryId');
  int get paymentAmountKes => _integer(payment, 'amountKes');
  String get tillNumber => _string(payment, 'tillNumber');
  int get paymentCategoryContributionKes =>
      _integer(payment, 'categoryContributionKes');
  int get paymentGlobalContributionKes =>
      _integer(payment, 'globalContributionKes');
  String get depositQuoteId => _string(deposit, 'quoteId');
  String get depositRequestId => _string(deposit, 'requestId');
  String get depositIdempotencyKey => _string(deposit, 'idempotencyKey');
  int get depositAmountKes => _integer(deposit, 'amountKes');
  String get depositPayerPhone => _string(deposit, 'payerPhone');
  String get depositPendingDescription =>
      _string(deposit, 'pendingDescription');
  String get depositSuccessDescription =>
      _string(deposit, 'successDescription');
  String get providerMerchantRequestId =>
      _string(provider, 'merchantRequestId');
  String get providerTransactionReceipt =>
      _string(provider, 'transactionReceipt');
  String get providerSettledLedgerId => _string(provider, 'settledLedgerId');
  String get providerSettledLedgerDescription =>
      _string(provider, 'settledLedgerDescription');
  String get reservationId => _string(references, 'reservationId');
  String get paymentRequestId => _string(references, 'paymentRequestId');
  String get createCommandId => _string(references, 'createCommandId');
  String get spendCommandId => _string(references, 'spendCommandId');
  String get nextCreateCommandId => _string(references, 'nextCreateCommandId');
}

Map<String, Object?> _readObject(Object? value) =>
    value! as Map<String, Object?>;

String _string(Map<String, Object?> object, String key) =>
    object[key]! as String;

int _integer(Map<String, Object?> object, String key) => object[key]! as int;

class FakeFundsApplication implements FundsApplication {
  FakeFundsApplication(this.currentData);

  FundsData currentData;
  Future<FundsData> Function()? loadHandler;
  Future<CommandResult> Function(FundsCommand command)? executeHandler;
  final StreamController<FundsData> updates =
      StreamController<FundsData>.broadcast(sync: true);
  int loadCount = 0;
  int executeCount = 0;

  @override
  Future<FundsData> load() {
    loadCount++;
    return loadHandler?.call() ?? Future.value(currentData);
  }

  @override
  Stream<FundsData> watch() => updates.stream;

  @override
  Future<CommandResult> execute(FundsCommand command) {
    executeCount++;
    return executeHandler?.call(command) ??
        Future.value(
          CommandResult(
            disposition: CommandDisposition.applied,
            data: currentData,
          ),
        );
  }

  Future<void> close() => updates.close();
}

DepositRequest depositRequest({
  required TransactionStatus status,
  DateTime? settledAt,
}) => DepositRequest(
  id: testInputs.depositRequestId,
  idempotencyKey: testInputs.depositIdempotencyKey,
  quote: DepositQuote(
    id: testInputs.depositQuoteId,
    walletId: testInputs.walletId,
    payer: MpesaPhoneNumber(testInputs.depositPayerPhone),
    amount: kes(testInputs.depositAmountKes),
    createdAt: now,
    expiresAt: now.add(testInputs.quoteLifetime),
  ),
  status: status,
  providerIdentifiers: ProviderIdentifiers(
    merchantRequestId: testInputs.providerMerchantRequestId,
    transactionReceipt: status == TransactionStatus.succeeded
        ? testInputs.providerTransactionReceipt
        : null,
  ),
  createdAt: now,
  resultDescription: status == TransactionStatus.succeeded
      ? testInputs.depositSuccessDescription
      : testInputs.depositPendingDescription,
  ledgerOperationId: status == TransactionStatus.succeeded
      ? testInputs.providerSettledLedgerId
      : null,
  settledAt: settledAt,
);

LedgerOperation settledDeposit(DateTime settledAt) => LedgerOperation(
  id: testInputs.providerSettledLedgerId,
  walletId: testInputs.walletId,
  kind: LedgerOperationKind.deposit,
  transfers: [
    LedgerTransfer(
      source: LedgerBucket.external(testInputs.depositPayerPhone),
      destination: const LedgerBucket.global(),
      amount: kes(testInputs.depositAmountKes),
    ),
  ],
  postedAt: settledAt,
  requestId: testInputs.depositRequestId,
  description: testInputs.providerSettledLedgerDescription,
);

PaymentReservation activePaymentReservation() {
  final quote = payment();
  return PaymentReservation(
    id: testInputs.reservationId,
    requestId: testInputs.paymentRequestId,
    funding: PaymentFundingPlan(
      quote: quote,
      categoryContribution: kes(testInputs.paymentCategoryContributionKes),
      globalContribution: kes(testInputs.paymentGlobalContributionKes),
      approval: GlobalFundingApproval(
        quoteId: quote.id,
        ownerId: testInputs.ownerId,
        amount: kes(testInputs.paymentGlobalContributionKes),
        approvedAt: now,
      ),
    ),
    status: ReservationStatus.active,
    createdAt: now,
  );
}

void main() {
  setUpAll(() async {
    final json = await File('test/state/controller_test_inputs.json')
        .readAsString();
    testInputs = ControllerTestInputs.decode(json);
  });

  group('FundsController snapshots', () {
    test(
      'watch data wins when it arrives while the initial load is pending',
      () async {
        final older = snapshot(revision: 'opaque-old', global: 10000);
        final newer = snapshot(revision: 'opaque-new', global: 18000);
        final load = Completer<FundsData>();
        final app = FakeFundsApplication(older)
          ..loadHandler = () => load.future;
        final controller = FundsController(app, clock: () => now);

        final initialized = controller.initialize();
        expect(controller.loadStatus.value, FundsControllerStatus.loading);
        expect(controller.data.value, isNull);

        app.updates.add(newer);
        expect(controller.data.value, same(newer));
        expect(controller.total.value, kes(38000));

        load.complete(older);
        await initialized;

        expect(controller.data.value, same(newer));
        expect(controller.globalAvailable.value, kes(18000));
        expect(controller.loadStatus.value, FundsControllerStatus.ready);

        await controller.dispose();
        await app.close();
      },
    );

    test(
      'read-only computed projections derive reserved and available totals',
      () async {
        final current = snapshot(
          global: 10000,
          globalReserved: 5000,
          category: 20000,
          categoryReserved: 10000,
          reservations: [activePaymentReservation()],
        );
        final app = FakeFundsApplication(current);
        final controller = FundsController(app, clock: () => now);
        await controller.initialize();

        expect(controller.wallet.value?.wallet.id, 'wallet-1');
        expect(controller.categories.value.single.category.name, 'Couch');
        expect(controller.globalAvailable.value, kes(5000));
        expect(controller.total.value, kes(30000));
        expect(controller.allocated.value, kes(20000));
        expect(controller.reserved.value, kes(15000));
        expect(controller.availableTotal.value, kes(15000));
        expect(controller.reservations.value.single.id, 'reservation-1');
        expect(controller.requests.value, isEmpty);
        expect(controller.ledger.value, isEmpty);
        expect(controller.providerEvents.value, isEmpty);

        await controller.dispose();
        await app.close();
      },
    );

    test('refresh failure keeps the last good snapshot and normalizes FundsException', () async {
      final initial = snapshot(global: 12000);
      final app = FakeFundsApplication(initial)
        ..loadHandler = () => Future.error(
          const FundsException(
            FundsFailure(FundsFailureCode.unavailable, 'Network unavailable'),
          ),
        );
      final controller = FundsController(app, clock: () => now);
      await controller.initialize();
      expect(controller.loadStatus.value, FundsControllerStatus.failed);
      expect(controller.data.value, isNull);
      expect(
        controller.loadError.value?.failure?.code,
        FundsFailureCode.unavailable,
      );

      app.loadHandler = () => Future.value(initial);
      await controller.refresh();
      expect(controller.loadStatus.value, FundsControllerStatus.ready);
      expect(controller.data.value, same(initial));
      expect(controller.loadError.value, isNull);

      app.loadHandler = () => Future.error(
        const FundsException(
          FundsFailure(FundsFailureCode.unavailable, 'Network unavailable'),
        ),
      );
      await controller.refresh();

      expect(controller.data.value, same(initial));
      expect(controller.loadStatus.value, FundsControllerStatus.failed);
      expect(
        controller.loadError.value?.failure?.code,
        FundsFailureCode.unavailable,
      );
      expect(controller.loadError.value?.message, 'Network unavailable');

      await controller.dispose();
      await app.close();
    });

    test(
      'provider watch updates pending deposit to settled request and ledger',
      () async {
        final app = FakeFundsApplication(snapshot(global: 10000));
        final controller = FundsController(app, clock: () => now);
        await controller.initialize();

        final pending = snapshot(
          revision: 'pending',
          global: 10000,
          requests: [depositRequest(status: TransactionStatus.pending)],
        );
        final settledAt = now.add(testInputs.settlementDelay);
        final complete = snapshot(
          revision: 'settled',
          global: 15000,
          requests: [
            depositRequest(
              status: TransactionStatus.succeeded,
              settledAt: settledAt,
            ),
          ],
          ledger: [settledDeposit(settledAt)],
        );

        app.updates
          ..add(pending)
          ..add(complete);

        expect(
          controller.requests.value.single.status,
          TransactionStatus.succeeded,
        );
        expect(controller.total.value, kes(35000));
        expect(controller.ledger.value.single.id, 'ledger-1');
        expect(controller.loadStatus.value, FundsControllerStatus.ready);

        await controller.dispose();
        await app.close();
      },
    );

    test(
      'stream errors are captured without dropping the last good view',
      () async {
        final initial = snapshot();
        final app = FakeFundsApplication(initial);
        final controller = FundsController(app, clock: () => now);
        await controller.initialize();

        app.updates.addError(
          const FundsException(
            FundsFailure(FundsFailureCode.unavailable, 'Watch interrupted'),
          ),
        );

        expect(controller.data.value, same(initial));
        expect(
          controller.watchError.value?.failure?.code,
          FundsFailureCode.unavailable,
        );
        expect(controller.loadStatus.value, FundsControllerStatus.ready);

        await controller.dispose();
        await app.close();
      },
    );

    test(
      'dispose prevents a pending load from updating controller state',
      () async {
        final load = Completer<FundsData>();
        final app = FakeFundsApplication(snapshot())
          ..loadHandler = () => load.future;
        final controller = FundsController(app, clock: () => now);
        final initialized = controller.initialize();

        await controller.dispose();
        load.complete(snapshot(global: 50000));
        await initialized;
        app.updates.add(snapshot(global: 60000));

        expect(controller.data.value, isNull);
        expect(controller.loadStatus.value, FundsControllerStatus.disposed);
        await app.close();
      },
    );
  });

  group('FundsController commands', () {
    test('approval requirement keeps exact quote and clears after a newer snapshot', () async {
      final initial = snapshot(global: 10000, category: 10000);
      final app = FakeFundsApplication(initial);
      final controller = FundsController(app, clock: () => now);
      await controller.initialize();
      final quote = payment();
      final requirement = FundingRequirement(
        quote: quote,
        categoryAvailable: kes(10000),
        globalAvailable: kes(10000),
      );
      app.executeHandler = (command) async {
        expect(command, isA<SpendCommand>());
        expect((command as SpendCommand).quote, same(quote));
        return CommandResult(
          disposition: CommandDisposition.requiresGlobalApproval,
          data: initial,
          fundingRequirement: requirement,
        );
      };

      final result = await controller.execute(
        SpendCommand(commandId: testInputs.spendCommandId, quote: quote),
      );

      expect(result?.fundingRequirement, same(requirement));
      expect(controller.commandState.value.isBusy, isFalse);
      expect(
        controller.commandState.value.approvalRequirement,
        same(requirement),
      );
      expect(controller.previewFunding(quote)?.quote, same(quote));

      final newer = snapshot(revision: 'changed', global: 8000, category: 8000);
      app.updates.add(newer);

      expect(controller.data.value, same(newer));
      expect(controller.commandState.value.approvalRequirement, isNull);
      expect(controller.previewFunding(quote)?.globalShortfall, kes(7000));

      await controller.dispose();
      await app.close();
    });

    test(
      'a command result cannot replace a watch snapshot emitted in flight',
      () async {
        final initial = snapshot(global: 10000);
        final oldCommandData = snapshot(revision: 'command-old', global: 9000);
        final latestWatchData = snapshot(
          revision: 'watch-latest',
          global: 14000,
        );
        final response = Completer<CommandResult>();
        final app = FakeFundsApplication(initial)
          ..executeHandler = (_) => response.future;
        final controller = FundsController(app, clock: () => now);
        await controller.initialize();

        final running = controller.execute(
          CreateCategoryCommand(
            commandId: testInputs.createCommandId,
            category: FundCategory(
              id: 'rent',
              walletId: testInputs.walletId,
              name: 'Rent',
              kind: CategoryKind.spending,
              target: kes(20000),
              createdAt: now,
            ),
          ),
        );
        expect(controller.commandState.value.isBusy, isTrue);

        app.updates.add(latestWatchData);
        response.complete(
          CommandResult(
            disposition: CommandDisposition.applied,
            data: oldCommandData,
          ),
        );
        await running;

        expect(app.executeCount, 1);
        expect(controller.data.value, same(latestWatchData));
        expect(controller.globalAvailable.value, kes(14000));
        expect(
          controller.commandState.value.result?.disposition,
          CommandDisposition.applied,
        );
        expect(controller.commandState.value.isBusy, isFalse);

        await controller.dispose();
        await app.close();
      },
    );

    test('approval remains available when in-flight result matches watched revision', () async {
      final initial = snapshot(global: 10000, category: 10000);
      final latest = snapshot(revision: 'r2', global: 12000, category: 9000);
      final response = Completer<CommandResult>();
      final app = FakeFundsApplication(initial)
        ..executeHandler = (_) => response.future;
      final controller = FundsController(app, clock: () => now);
      await controller.initialize();
      final quote = payment();
      final requirement = FundingRequirement(
        quote: quote,
        categoryAvailable: kes(9000),
        globalAvailable: kes(12000),
      );

      final running = controller.execute(
        SpendCommand(commandId: testInputs.spendCommandId, quote: quote),
      );
      app.updates.add(latest);
      response.complete(
        CommandResult(
          disposition: CommandDisposition.requiresGlobalApproval,
          data: snapshot(revision: 'r2', global: 12000, category: 9000),
          fundingRequirement: requirement,
        ),
      );
      await running;

      expect(controller.data.value, same(latest));
      expect(
        controller.commandState.value.approvalRequirement,
        same(requirement),
      );

      await controller.dispose();
      await app.close();
    });

    test(
      'duplicate submission while busy does not send a second command',
      () async {
        final initial = snapshot();
        final response = Completer<CommandResult>();
        final app = FakeFundsApplication(initial)
          ..executeHandler = (_) => response.future;
        final controller = FundsController(app, clock: () => now);
        await controller.initialize();
        final command = CreateCategoryCommand(
          commandId: testInputs.createCommandId,
          category: FundCategory(
            id: 'rent',
            walletId: testInputs.walletId,
            name: 'Rent',
            kind: CategoryKind.spending,
            target: kes(20000),
            createdAt: now,
          ),
        );

        final first = controller.execute(command);
        expect(controller.commandState.value.isBusy, isTrue);
        expect(await controller.execute(command), isNull);
        expect(app.executeCount, 1);

        response.complete(
          CommandResult(disposition: CommandDisposition.applied, data: initial),
        );
        expect(await first, isNotNull);
        expect(controller.commandState.value.isBusy, isFalse);
        expect(controller.commandState.value.commandId, 'create-1');

        await controller.dispose();
        await app.close();
      },
    );

    test('unknown command errors remain visible and do not look like funds failures', () async {
      final app = FakeFundsApplication(snapshot())
        ..executeHandler = (_) =>
            Future.error(StateError('Unexpected failure'));
      final controller = FundsController(app, clock: () => now);
      await controller.initialize();

      expect(
        await controller.execute(
          CreateCategoryCommand(
            commandId: testInputs.createCommandId,
            category: FundCategory(
              id: 'rent',
              walletId: testInputs.walletId,
              name: 'Rent',
              kind: CategoryKind.spending,
              target: kes(20000),
              createdAt: now,
            ),
          ),
        ),
        isNull,
      );
      expect(controller.commandState.value.error?.failure, isNull);
      expect(
        controller.commandState.value.error?.message,
        contains('Unexpected failure'),
      );
      expect(controller.commandState.value.isBusy, isFalse);

      await controller.dispose();
      await app.close();
    });

    test(
      'dispose clears busy state and ignores a late command result',
      () async {
        final initial = snapshot();
        final response = Completer<CommandResult>();
        final app = FakeFundsApplication(initial)
          ..executeHandler = (_) => response.future;
        final controller = FundsController(app, clock: () => now);
        await controller.initialize();

        final commandFuture = controller.execute(
          CreateCategoryCommand(
            commandId: testInputs.createCommandId,
            category: FundCategory(
              id: 'rent',
              walletId: testInputs.walletId,
              name: 'Rent',
              kind: CategoryKind.spending,
              target: kes(20000),
              createdAt: now,
            ),
          ),
        );
        expect(controller.commandState.value.isBusy, isTrue);

        await controller.dispose();
        expect(controller.loadStatus.value, FundsControllerStatus.disposed);
        expect(controller.commandState.value.isBusy, isFalse);
        expect(
          controller.execute(
            CreateCategoryCommand(
              commandId: testInputs.nextCreateCommandId,
              category: FundCategory(
                id: 'food',
                walletId: testInputs.walletId,
                name: 'Food',
                kind: CategoryKind.spending,
                target: kes(20000),
                createdAt: now,
              ),
            ),
          ),
          throwsStateError,
        );

        response.complete(
          CommandResult(
            disposition: CommandDisposition.applied,
            data: snapshot(global: 25000),
          ),
        );
        expect(await commandFuture, isNull);
        expect(controller.data.value, same(initial));
        expect(controller.commandState.value.result, isNull);
        await app.close();
      },
    );
  });
}
