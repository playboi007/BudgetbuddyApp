import 'package:budgetbuddy_app/budgetbuddy_flows.dart';
import 'package:budgetbuddy_app/budgetbuddy_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/funds_fixtures.dart';

void main() {
  test(
    'recovered requests reject changed payloads without a second dispatch',
    () async {
      final harness = await FundsFlowHarness.start();
      try {
        final quote = paymentQuote('couch20');
        const commandId = 'review-recovered-command';
        final initial = await harness.execute(
          SpendCommand(commandId: commandId, quote: quote),
        );
        final recoveredGateway = ControlledPaymentGateway.accepted();
        final recovered = FundsFlowService(
          actor: ActorContext(
            ownerId: FlowFixture.ownerId,
            walletId: FlowFixture.walletId,
          ),
          repository: InMemoryFundsRepository(seed: initial!.data),
          gateway: recoveredGateway,
          clock: harness.clock.call,
        );
        final changed = await recovered.execute(
          SpendCommand(
            commandId: commandId,
            quote: PaymentQuote(
              id: quote.id,
              walletId: quote.walletId,
              categoryId: quote.categoryId,
              recipient: quote.recipient,
              amount: quote.amount - kes(1),
              createdAt: quote.createdAt,
              expiresAt: quote.expiresAt,
            ),
          ),
        );
        expect(changed.failure?.code, FundsFailureCode.idempotencyConflict);
        final replayed = await recovered.execute(
          SpendCommand(commandId: commandId, quote: quote),
        );
        expect(replayed.requestId, initial.requestId);
        expect(replayed.data.requests, hasLength(1));
        expect(replayed.data.wallet.reserved, initial.data.wallet.reserved);
        expect(recoveredGateway.submittedRequests, isEmpty);
      } finally {
        await harness.dispose();
      }
    },
  );

  test(
    'trusted settlement can arrive before acknowledgment without rewinding',
    () async {
      final gateway = ControlledPaymentGateway.accepted(gated: true);
      final harness = await FundsFlowHarness.start(gateway: gateway);
      try {
        final execution = harness.execute(
          DepositCommand(
            commandId: FlowFixture.depositCommandId,
            quote: depositQuote('depositSuccess'),
          ),
        );
        final submitted = await gateway.firstSubmission;
        await harness.resolve(
          requestId: submitted.id,
          eventId: 'review-early-success',
          outcome: ProviderResolutionOutcome.succeeded,
          reportedAmount: submitted.quote.amount.minorUnits ~/ 100,
        );
        gateway.releaseAcknowledgment();
        await execution;
        await harness.refresh();

        expect(
          harness.snapshot.requests.single.status,
          TransactionStatus.succeeded,
        );
        expect(harness.snapshot.ledger, hasLength(1));
        expect(
          harness.snapshot.wallet.total,
          fundedWalletSeed().total + submitted.quote.amount,
        );
        expect(gateway.submittedRequests, hasLength(1));
      } finally {
        gateway.releaseAcknowledgment();
        await harness.dispose();
      }
    },
  );

  test(
    'an aborted repository draft changes neither funds nor replay metadata',
    () async {
      final seed = fundedFundsSeed();
      final repository = InMemoryFundsRepository(seed: seed);
      final actor = ActorContext(
        ownerId: seed.wallet.wallet.ownerId,
        walletId: seed.wallet.wallet.id,
      );
      await expectLater(
        repository.transact<void>(actor, (draft) {
          draft.bindCommand('review-aborted', 'discard-me');
          draft.replaceData(FundsData(wallet: emptyWalletSeed()));
          throw StateError('Abort the complete draft');
        }),
        throwsStateError,
      );
      final loaded = await repository.load(actor);
      expect(loaded.wallet.total, seed.wallet.total);
      expect(loaded.wallet.revision, seed.wallet.revision);
      final binding = await repository.transact<String?>(
        actor,
        (draft) => draft.commandFingerprint('review-aborted'),
      );
      expect(binding, isNull);
    },
  );

  test('repository validation cannot replace wallet ownership', () async {
    final seed = fundedFundsSeed();
    final repository = InMemoryFundsRepository(seed: seed);
    final actor = ActorContext(
      ownerId: seed.wallet.wallet.ownerId,
      walletId: seed.wallet.wallet.id,
    );
    final foreign = FundsData(
      wallet: WalletSnapshot(
        wallet: Wallet(
          id: 'foreign-wallet',
          ownerId: 'foreign-owner',
          createdAt: seed.wallet.asOf,
        ),
        revision: seed.wallet.revision,
        unallocated: seed.wallet.total,
        globalReserved: Money.zero,
        categories: const [],
        asOf: seed.wallet.asOf,
      ),
    );
    await expectLater(
      repository.transact<void>(actor, (draft) => draft.replaceData(foreign)),
      throwsArgumentError,
    );
    expect((await repository.load(actor)).wallet.wallet.ownerId, actor.ownerId);
    expect((await repository.load(actor)).wallet.total, seed.wallet.total);
  });
}
