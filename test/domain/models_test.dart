import 'package:budgetbuddy_app/budgetbuddy_models.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime.utc(2026, 10, 4, 16);
Money kes(int value) => Money.fromKes(value);

PaymentQuote payment({int amount = 23000, String id = 'quote-1'}) =>
    PaymentQuote(
      id: id,
      walletId: 'wallet-1',
      categoryId: 'couch',
      recipient: TillRecipient('001234'),
      amount: kes(amount),
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 5)),
    );

FundCategory category(
  String id, {
  String walletId = 'wallet-1',
  bool archived = false,
}) => FundCategory(
  id: id,
  walletId: walletId,
  name: id,
  kind: CategoryKind.savingsGoal,
  target: kes(30000),
  createdAt: now,
  archivedAt: archived ? now : null,
);

PaymentFundingPlan plan({
  PaymentQuote? quote,
  GlobalFundingApproval? approval,
}) => PaymentFundingPlan(
  quote: quote ?? payment(),
  categoryContribution: kes(20000),
  globalContribution: kes(3000),
  approval:
      approval ??
      GlobalFundingApproval(
        quoteId: 'quote-1',
        ownerId: 'owner-1',
        amount: kes(3000),
        approvedAt: now,
      ),
);

void main() {
  group('Transaction amounts', () {
    test('minor-unit spend remains exact through allocation arithmetic', () {
      final amount = Money.fromMinorUnits(130);
      final categoryPart = Money.fromMinorUnits(100);
      final globalPart = amount - categoryPart;
      expect(categoryPart + globalPart, amount);
      expect(amount.toString(), 'KES 1.30');
    });

    test('negative balances and oversubtraction are rejected', () {
      expect(() => Money.fromMinorUnits(-1), throwsRangeError);
      expect(() => kes(10) - kes(11), throwsRangeError);
    });

    test('addition cannot exceed exact Flutter web integer range', () {
      final maximum = Money.fromMinorUnits(Money.maxMinorUnits);
      expect(() => maximum + Money.fromMinorUnits(1), throwsRangeError);
      expect(() => Money.fromKes(Money.maxMinorUnits), throwsRangeError);
    });

    test('deposit records the amount credited to the wallet', () {
      final quote = DepositQuote(
        id: 'deposit-quote',
        walletId: 'wallet-1',
        payer: MpesaPhoneNumber('254712345678'),
        amount: kes(50000),
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 5)),
      );
      expect(quote.amount, kes(50000));
    });

    test('zero-value deposits and spends are rejected', () {
      expect(() => payment(amount: 0), throwsArgumentError);
      expect(
        () => DepositQuote(
          id: 'deposit-quote',
          walletId: 'wallet-1',
          payer: MpesaPhoneNumber('254712345678'),
          amount: Money.zero,
          createdAt: now,
          expiresAt: now.add(const Duration(minutes: 5)),
        ),
        throwsArgumentError,
      );
    });
  });

  group('Spend funding and approval', () {
    for (final example in [
      (amount: 18000, shortfall: 0, unfunded: 0),
      (amount: 20000, shortfall: 0, unfunded: 0),
      (amount: 23000, shortfall: 3000, unfunded: 0),
      (amount: 36000, shortfall: 16000, unfunded: 1000),
    ]) {
      test('KES ${example.amount} spend uses its single amount in funding', () {
        final requirement = FundingRequirement(
          quote: payment(amount: example.amount),
          categoryAvailable: kes(20000),
          globalAvailable: kes(15000),
        );
        expect(requirement.globalShortfall, kes(example.shortfall));
        expect(requirement.unfunded, kes(example.unfunded));
        expect(requirement.isFullyFundable, example.unfunded == 0);
        expect(requirement.needsGlobalApproval, example.shortfall > 0);
      });
    }

    test('partial funding cannot authorize the full spend', () {
      expect(
        () => PaymentFundingPlan(
          quote: payment(amount: 20001),
          categoryContribution: kes(20000),
          globalContribution: Money.zero,
          approval: null,
        ),
        throwsArgumentError,
      );
    });

    test('global funds require explicit approval', () {
      expect(
        () => PaymentFundingPlan(
          quote: payment(),
          categoryContribution: kes(20000),
          globalContribution: kes(3000),
          approval: null,
        ),
        throwsArgumentError,
      );
    });

    test('funding and reservation include the whole debit', () {
      final funding = plan();
      expect(funding.totalReserved, kes(23000));
      final reservation = PaymentReservation(
        id: 'hold-1',
        requestId: 'request-1',
        funding: funding,
        status: ReservationStatus.active,
        createdAt: now,
      );
      expect(reservation.total, kes(23000));
    });

    test('a refreshed quote cannot reuse the previous global approval', () {
      expect(
        () => plan(quote: payment(id: 'refreshed-quote')),
        throwsArgumentError,
      );
    });

    test('approval must cover the exact global amount', () {
      expect(
        () => plan(
          approval: GlobalFundingApproval(
            quoteId: 'quote-1',
            ownerId: 'owner-1',
            amount: kes(2999),
            approvedAt: now,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('quote expiry invalidates new approval at the expiry boundary', () {
      final quote = payment();
      expect(quote.isValidAt(quote.expiresAt), isFalse);
      expect(
        () => plan(
          approval: GlobalFundingApproval(
            quoteId: quote.id,
            ownerId: 'owner-1',
            amount: kes(3000),
            approvedAt: quote.expiresAt,
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('Protected wallet funds', () {
    WalletSnapshot snapshot(
      Iterable<CategoryBalance> categories, {
      int globalReserved = 3000,
    }) => WalletSnapshot(
      wallet: Wallet(id: 'wallet-1', ownerId: 'owner-1', createdAt: now),
      revision: 'revision-1',
      unallocated: kes(15000),
      globalReserved: kes(globalReserved),
      categories: categories,
      asOf: now,
    );

    test('pending couch payment protects Rent and reduces available funds', () {
      final state = snapshot([
        CategoryBalance(
          category: category('couch'),
          balance: kes(20000),
          reserved: kes(20000),
        ),
        CategoryBalance(
          category: category('rent'),
          balance: kes(15000),
          reserved: Money.zero,
        ),
      ]);
      expect(state.total, kes(50000));
      expect(state.allocated, kes(35000));
      expect(state.availableGlobal, kes(12000));
      expect(state.reserved, kes(23000));
      expect(state.categories.first.available, Money.zero);
      expect(state.categories.last.available, kes(15000));
      final next = FundingRequirement(
        quote: payment(amount: 12001),
        categoryAvailable: state.categories.first.available,
        globalAvailable: state.availableGlobal,
      );
      expect(next.isFullyFundable, isFalse);
      expect(next.unfunded, kes(1));
    });

    test('foreign and duplicate categories cannot inflate wallet totals', () {
      final couch = CategoryBalance(
        category: category('couch'),
        balance: kes(20000),
        reserved: Money.zero,
      );
      expect(() => snapshot([couch, couch]), throwsArgumentError);
      expect(
        () => snapshot([
          CategoryBalance(
            category: category('foreign', walletId: 'other-wallet'),
            balance: kes(1),
            reserved: Money.zero,
          ),
        ]),
        throwsArgumentError,
      );
    });

    test('global and category reservations cannot exceed settled balances', () {
      expect(() => snapshot([], globalReserved: 15001), throwsArgumentError);
      expect(
        () => CategoryBalance(
          category: category('couch'),
          balance: kes(1),
          reserved: kes(2),
        ),
        throwsArgumentError,
      );
    });

    test('archiving cannot hide allocated money', () {
      expect(
        () => CategoryBalance(
          category: category('couch', archived: true),
          balance: kes(1),
          reserved: Money.zero,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Request and ledger evidence', () {
    test('conflicting evidence quarantines every dispatched state', () {
      for (final status in [
        TransactionStatus.submitting,
        TransactionStatus.pending,
        TransactionStatus.awaitingVerification,
      ]) {
        expect(
          status.canTransitionTo(TransactionStatus.reconciliationRequired),
          isTrue,
          reason: '$status must retain its hold for reconciliation',
        );
      }
    });

    test(
      'ambiguous requests can settle later without rewriting terminal results',
      () {
        expect(
          TransactionStatus.pending.canTransitionTo(
            TransactionStatus.awaitingVerification,
          ),
          isTrue,
        );
        expect(
          TransactionStatus.awaitingVerification.canTransitionTo(
            TransactionStatus.succeeded,
          ),
          isTrue,
        );
        expect(
          TransactionStatus.succeeded.canTransitionTo(TransactionStatus.failed),
          isFalse,
        );
        expect(
          TransactionStatus.failed.canTransitionTo(TransactionStatus.succeeded),
          isFalse,
        );
        expect(
          TransactionStatus.failed.canTransitionTo(
            TransactionStatus.reconciliationRequired,
          ),
          isTrue,
        );
      },
    );

    test('success needs provider receipt and ledger evidence', () {
      expect(
        () => OutgoingPaymentRequest(
          id: 'request-1',
          idempotencyKey: 'idem-1',
          funding: plan(),
          reservationId: 'hold-1',
          status: TransactionStatus.succeeded,
          providerIdentifiers: const ProviderIdentifiers(),
          createdAt: now,
          settledAt: now.add(const Duration(seconds: 10)),
          resultDescription: 'Success',
          ledgerOperationId: 'operation-1',
        ),
        throwsArgumentError,
      );
    });

    test('unknown outcome has an active hold and no settlement entry', () {
      final request = OutgoingPaymentRequest(
        id: 'request-1',
        idempotencyKey: 'idem-1',
        funding: plan(),
        reservationId: 'hold-1',
        status: TransactionStatus.awaitingVerification,
        providerIdentifiers: const ProviderIdentifiers(
          conversationId: 'provider-1',
        ),
        createdAt: now,
        resultDescription: 'Checking result',
        ledgerOperationId: null,
      );
      expect(request.settledAt, isNull);
      expect(request.funding.totalReserved, kes(23000));
      expect(request.environment, 'sandbox');
    });

    test('release is evidence-backed, not an automatically expiring hold', () {
      expect(
        () => PaymentReservation(
          id: 'hold-1',
          requestId: 'request-1',
          funding: plan(),
          status: ReservationStatus.released,
          createdAt: now,
        ),
        throwsArgumentError,
      );
      final active = PaymentReservation(
        id: 'hold-1',
        requestId: 'request-1',
        funding: plan(),
        status: ReservationStatus.active,
        createdAt: now,
      );
      expect(active.status, ReservationStatus.active);
      expect(active.resolvedAt, isNull);
    });

    test(
      'payment ledger records the complete spend with its approved supplement',
      () {
        final couch = LedgerBucket.category('couch');
        final operation = LedgerOperation(
          id: 'operation-1',
          walletId: 'wallet-1',
          kind: LedgerOperationKind.payment,
          postedAt: now,
          requestId: 'request-1',
          description: 'Couch purchase',
          transfers: [
            LedgerTransfer(
              source: const LedgerBucket.global(),
              destination: couch,
              amount: kes(3000),
            ),
            LedgerTransfer(
              source: couch,
              destination: LedgerBucket.external('merchant'),
              amount: kes(23000),
            ),
          ],
        );
        final outgoing = operation.transfers
            .where((t) => t.destination.kind == LedgerBucketKind.external)
            .fold(Money.zero, (sum, t) => sum + t.amount);
        expect(outgoing, kes(23000));
        expect(
          kes(20000) + operation.transfers.first.amount - outgoing,
          Money.zero,
        );
      },
    );

    test('one payment cannot debit unrelated categories', () {
      expect(
        () => LedgerOperation(
          id: 'bad',
          walletId: 'wallet-1',
          kind: LedgerOperationKind.payment,
          postedAt: now,
          requestId: 'request-1',
          description: 'Wrong categories',
          transfers: [
            LedgerTransfer(
              source: LedgerBucket.category('couch'),
              destination: LedgerBucket.external('merchant'),
              amount: kes(23000),
            ),
            LedgerTransfer(
              source: LedgerBucket.category('rent'),
              destination: LedgerBucket.external('merchant'),
              amount: kes(100),
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('internal allocation cannot be mislabeled as external spending', () {
      expect(
        () => LedgerOperation(
          id: 'bad',
          walletId: 'wallet-1',
          kind: LedgerOperationKind.allocation,
          postedAt: now,
          requestId: null,
          description: 'Wrong route',
          transfers: [
            LedgerTransfer(
              source: const LedgerBucket.global(),
              destination: LedgerBucket.external('merchant'),
              amount: kes(100),
            ),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  test(
    'recipient variants preserve leading zeros and require Paybill reference',
    () {
      expect(TillRecipient('001234').tillNumber, '001234');
      expect(
        () => PaybillRecipient(paybillNumber: '001234', accountReference: ' '),
        throwsArgumentError,
      );
      expect(MpesaPhoneNumber('254112345678').value, '254112345678');
    },
  );
}
