import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'flow_scenarios.dart';

FlowCheckpoint _at(List<FlowCheckpoint> checkpoints, String id) =>
    checkpoints.singleWhere((item) => item.id == id);

Map<String, Object?> _map(Object? value) => value! as Map<String, Object?>;

Map<String, Object?> _section(FlowCheckpoint checkpoint, String key) =>
    _map(checkpoint.state[key]);

String _money(Map<String, Object?> values, String key) =>
    _map(values[key])['kes']! as String;

String _wallet(FlowCheckpoint checkpoint, String key) =>
    _money(_section(checkpoint, 'wallet'), key);

Map<String, Object?> _category(FlowCheckpoint checkpoint, String id) =>
    (_mapList(checkpoint.state['categories']))
        .singleWhere((item) => item['id'] == id);

String _categoryMoney(FlowCheckpoint checkpoint, String id, String field) =>
    _money(_category(checkpoint, id), field);

List<Map<String, Object?>> _mapList(Object? value) =>
    (value! as List<Object?>).map(_map).toList(growable: false);

List<Map<String, Object?>> _requests(FlowCheckpoint checkpoint) =>
    _mapList(_section(checkpoint, 'transactions')['requests']);

List<Map<String, Object?>> _reservations(FlowCheckpoint checkpoint) =>
    _mapList(_section(checkpoint, 'transactions')['reservations']);

int _ledgerKind(FlowCheckpoint checkpoint, String kind) =>
    _map(_section(checkpoint, 'transactions')['ledgerCountsByKind'])[kind]!
        as int;

Map<String, Object?> _approval(FlowCheckpoint checkpoint) =>
    _map(_section(checkpoint, 'ui')['approvalRequirement']);

Map<String, Object?> _diagnostic(FlowCheckpoint checkpoint) =>
    _map(_section(checkpoint, 'ui')['fundingDiagnostic']);

void main() {
  group('reference flows through FundsFlowService and Signals', () {
    test('creates, edits, and archives an empty category', () async {
      final checkpoints = await runCategoryManagementScenario();
      final created = _at(checkpoints, 'category.created');
      final edited = _at(checkpoints, 'category.edited');
      final archived = _at(checkpoints, 'category.archived');

      expect(_categoryMoney(created, 'emergency', 'balance'), 'KES 0.00');
      expect(_category(edited, 'emergency')['name'], 'Emergency fund');
      expect(_categoryMoney(edited, 'emergency', 'target'), 'KES 12,000.00');
      expect(_category(archived, 'emergency')['archived'], isTrue);
      expect(_wallet(archived, 'total'), 'KES 50,000.00');
      expect(_section(archived, 'ui')['actionStatus'], 'applied');
    });

    test('allocation and release preserve total wallet funds', () async {
      final checkpoints = await runAllocationReleaseScenario();
      final allocated = _at(checkpoints, 'funds.allocated');
      final released = _at(checkpoints, 'funds.released');

      expect(_wallet(allocated, 'total'), 'KES 50,000.00');
      expect(_wallet(allocated, 'globalAvailable'), 'KES 10,000.00');
      expect(_categoryMoney(allocated, 'couch', 'balance'), 'KES 25,000.00');
      expect(_wallet(released, 'total'), 'KES 50,000.00');
      expect(_wallet(released, 'globalAvailable'), 'KES 13,000.00');
      expect(_categoryMoney(released, 'couch', 'balance'), 'KES 22,000.00');
      expect(_ledgerKind(released, 'allocation'), 1);
      expect(_ledgerKind(released, 'release'), 1);
    });

    test(
      'deposit stays pending until confirmed success credits it once',
      () async {
        final checkpoints = await runDepositSuccessScenario();
        final loading = _at(checkpoints, 'deposit.loading');
        final pending = _at(checkpoints, 'deposit.pending');
        final succeeded = _at(checkpoints, 'deposit.succeeded');

        expect(_section(loading, 'ui')['loadStatus'], 'ready');
        expect(_section(loading, 'ui')['actionIsLoading'], isTrue);
        expect(_section(loading, 'ui')['actionStatus'], 'loading');
        expect(_wallet(loading, 'total'), 'KES 0.00');
        expect(_requests(pending).single['status'], 'pending');
        expect(_wallet(pending, 'total'), 'KES 0.00');
        expect(_wallet(succeeded, 'total'), 'KES 50,000.00');
        expect(_ledgerKind(succeeded, 'deposit'), 1);
        expect(_section(succeeded, 'ui')['actionStatus'], 'submitted');
        expect(_requests(succeeded).single['status'], 'succeeded');
      },
    );

    test('confirmed deposit failure leaves the wallet uncredited', () async {
      final checkpoints = await runDepositFailureScenario();
      final pending = _at(checkpoints, 'deposit-failure.pending');
      final failed = _at(checkpoints, 'deposit-failure.failed');

      expect(_requests(pending).single['status'], 'pending');
      expect(_wallet(failed, 'total'), 'KES 0.00');
      expect(_requests(failed).single['status'], 'failed');
      expect(_section(failed, 'transactions')['ledgerCount'], 0);
    });

    test('KES 18,000 Couch spend holds funds and settles once', () async {
      final checkpoints = await runCouch18kScenario();
      final loading = _at(checkpoints, 'spend18.loading');
      final pending = _at(checkpoints, 'spend18.pending');
      final succeeded = _at(checkpoints, 'spend18.succeeded');

      expect(_section(loading, 'ui')['actionIsLoading'], isTrue);
      expect(_wallet(loading, 'total'), 'KES 50,000.00');
      expect(_wallet(loading, 'reserved'), 'KES 18,000.00');
      expect(_categoryMoney(loading, 'couch', 'available'), 'KES 2,000.00');
      expect(_requests(pending).single['status'], 'pending');
      expect(_wallet(pending, 'total'), 'KES 50,000.00');
      expect(_wallet(succeeded, 'total'), 'KES 32,000.00');
      expect(_categoryMoney(succeeded, 'couch', 'balance'), 'KES 2,000.00');
      expect(_categoryMoney(succeeded, 'rent', 'balance'), 'KES 15,000.00');
      expect(_wallet(succeeded, 'globalAvailable'), 'KES 15,000.00');
      expect(_ledgerKind(succeeded, 'payment'), 1);
      expect(_section(succeeded, 'ui')['actionStatus'], 'submitted');
      expect(_requests(succeeded).single['status'], 'succeeded');
    });

    test(
      'KES 23,000 requires exact approval and settles the approved split',
      () async {
        final checkpoints = await runCouch23kApprovalScenario();
        final needsApproval = _at(checkpoints, 'spend23.approval-required');
        final pending = _at(checkpoints, 'spend23.pending');
        final succeeded = _at(checkpoints, 'spend23.succeeded');

        expect(_section(needsApproval, 'ui')['needsApproval'], isTrue);
        expect(
          _money(_approval(needsApproval), 'globalShortfall'),
          'KES 3,000.00',
        );
        expect(_wallet(needsApproval, 'total'), 'KES 50,000.00');
        expect(_requests(needsApproval), isEmpty);
        expect(_reservations(needsApproval), isEmpty);
        expect(_wallet(pending, 'total'), 'KES 50,000.00');
        expect(_wallet(pending, 'reserved'), 'KES 23,000.00');
        expect(_wallet(pending, 'globalAvailable'), 'KES 12,000.00');
        expect(_categoryMoney(pending, 'couch', 'available'), 'KES 0.00');
        expect(
          _money(_reservations(pending).single, 'globalContribution'),
          'KES 3,000.00',
        );
        expect(_wallet(succeeded, 'total'), 'KES 27,000.00');
        expect(_categoryMoney(succeeded, 'couch', 'balance'), 'KES 0.00');
        expect(_categoryMoney(succeeded, 'rent', 'balance'), 'KES 15,000.00');
        expect(_wallet(succeeded, 'globalAvailable'), 'KES 12,000.00');
      },
    );

    test('confirmed spend failure releases holds to seed balances', () async {
      final checkpoints = await runSpendFailureScenario();
      final pending = _at(checkpoints, 'spend-failure.pending');
      final failed = _at(checkpoints, 'spend-failure.failed');

      expect(_wallet(pending, 'reserved'), 'KES 23,000.00');
      expect(_requests(failed).single['status'], 'failed');
      expect(_reservations(failed).single['status'], 'released');
      expect(_wallet(failed, 'total'), 'KES 50,000.00');
      expect(_wallet(failed, 'reserved'), 'KES 0.00');
      expect(_categoryMoney(failed, 'couch', 'available'), 'KES 20,000.00');
      expect(_wallet(failed, 'globalAvailable'), 'KES 15,000.00');
      expect(_section(failed, 'transactions')['ledgerCount'], 0);
    });

    test('unknown provider result keeps the spend reserved', () async {
      final checkpoints = await runSpendUnknownScenario();
      final unknown = _at(checkpoints, 'spend-unknown.awaiting-verification');

      expect(_requests(unknown).single['status'], 'awaitingVerification');
      expect(_reservations(unknown).single['status'], 'active');
      expect(_wallet(unknown, 'reserved'), 'KES 23,000.00');
      expect(_ledgerKind(unknown, 'payment'), 0);
    });

    test('provider rejection releases holds while unknown acknowledgment keeps them', () async {
      final checkpoints = await runGatewayAcknowledgmentScenario();
      final rejected = _at(checkpoints, 'gateway.rejected');
      final unknown = _at(checkpoints, 'gateway.unknown');

      expect(_requests(rejected).single['status'], 'failed');
      expect(_reservations(rejected).single['status'], 'released');
      expect(_wallet(rejected, 'reserved'), 'KES 0.00');
      expect(_requests(unknown).single['status'], 'awaitingVerification');
      expect(_reservations(unknown).single['status'], 'active');
      expect(_wallet(unknown, 'reserved'), 'KES 18,000.00');
    });

    test(
      'KES 36,000 is blocked with KES 1,000 unfunded and Rent protected',
      () async {
        final checkpoints = await runSpend36kScenario();
        final rejected = _at(checkpoints, 'spend36.rejected');
        final ui = _section(rejected, 'ui');

        expect(ui['actionStatus'], 'rejected');
        expect(ui['commandErrorCode'], 'insufficientFunds');
        expect(ui['needsApproval'], isFalse);
        expect(_money(_diagnostic(rejected), 'unfunded'), 'KES 1,000.00');
        expect(_requests(rejected), isEmpty);
        expect(
          _section(
            rejected,
            'transactions',
          )['referenceProviderSubmissionCount'],
          0,
        );
        expect(_wallet(rejected, 'total'), 'KES 50,000.00');
        expect(_categoryMoney(rejected, 'rent', 'balance'), 'KES 15,000.00');
      },
    );

    test(
      'KES 20,000 exact category coverage needs no global approval',
      () async {
        final checkpoints = await runCouch20kExactScenario();
        final pending = _at(checkpoints, 'spend20.pending');
        final succeeded = _at(checkpoints, 'spend20.succeeded');

        expect(_section(pending, 'ui')['needsApproval'], isFalse);
        expect(_wallet(pending, 'reserved'), 'KES 20,000.00');
        expect(_wallet(pending, 'globalAvailable'), 'KES 15,000.00');
        expect(
          _money(_reservations(pending).single, 'globalContribution'),
          'KES 0.00',
        );
        expect(_wallet(succeeded, 'total'), 'KES 30,000.00');
        expect(_categoryMoney(succeeded, 'couch', 'balance'), 'KES 0.00');
        expect(_wallet(succeeded, 'globalAvailable'), 'KES 15,000.00');
      },
    );

    test(
      'duplicate command and callback do not repeat provider or ledger work',
      () async {
        final checkpoints = await runDuplicateCommandCallbackScenario();
        final first = _at(checkpoints, 'duplicate.first-command');
        final replayed = _at(checkpoints, 'duplicate.replayed-command');
        final success = _at(checkpoints, 'duplicate.first-callback');
        final duplicateCallback = _at(
          checkpoints,
          'duplicate.replayed-callback',
        );

        expect(_requests(first), hasLength(1));
        expect(_requests(replayed), hasLength(1));
        expect(
          _section(
            replayed,
            'transactions',
          )['referenceProviderSubmissionCount'],
          1,
        );
        expect(_wallet(success, 'total'), 'KES 32,000.00');
        expect(_section(success, 'transactions')['ledgerCount'], 1);
        expect(_section(duplicateCallback, 'transactions')['ledgerCount'], 1);
        expect(
          _section(duplicateCallback, 'transactions')['providerEventCount'],
          1,
        );
        expect(_wallet(duplicateCallback, 'total'), 'KES 32,000.00');
      },
    );

    test(
      'stale approval is checked against the latest serialized balance',
      () async {
        final checkpoints = await runStaleApprovalScenario();
        final changed = _at(checkpoints, 'stale-approval.funds-changed');
        final rejected = _at(checkpoints, 'stale-approval.rejected');
        final ui = _section(rejected, 'ui');

        expect(_wallet(changed, 'globalAvailable'), 'KES 2,000.00');
        expect(_categoryMoney(changed, 'rent', 'balance'), 'KES 28,000.00');
        expect(ui['actionStatus'], 'rejected');
        expect(ui['commandErrorCode'], 'insufficientFunds');
        expect(ui['needsApproval'], isFalse);
        expect(
          _money(_diagnostic(rejected), 'globalShortfall'),
          'KES 3,000.00',
        );
        expect(_money(_diagnostic(rejected), 'unfunded'), 'KES 1,000.00');
        expect(_requests(rejected), isEmpty);
        expect(
          _section(
            rejected,
            'transactions',
          )['referenceProviderSubmissionCount'],
          0,
        );
      },
    );

    test(
      'global-only pending payment blocks archive until it resolves',
      () async {
        final checkpoints = await runGlobalOnlyHoldArchiveScenario();
        final pending = _at(checkpoints, 'global-only.pending');
        final blocked = _at(checkpoints, 'global-only.archive-blocked');
        final released = _at(checkpoints, 'global-only.hold-released');
        final archived = _at(checkpoints, 'global-only.archive-allowed');

        expect(
          _money(_reservations(pending).single, 'categoryContribution'),
          'KES 0.00',
        );
        expect(
          _money(_reservations(pending).single, 'globalContribution'),
          'KES 10,000.00',
        );
        expect(_wallet(pending, 'globalAvailable'), 'KES 5,000.00');
        expect(_section(blocked, 'ui')['actionStatus'], 'rejected');
        expect(_category(blocked, 'empty-category')['archived'], isFalse);
        expect(_wallet(released, 'globalAvailable'), 'KES 15,000.00');
        expect(_category(archived, 'empty-category')['archived'], isTrue);
      },
    );

    test(
      'expired quote is rejected before reservation or provider submission',
      () async {
        final checkpoints = await runExpiredQuoteScenario();
        final expired = _at(checkpoints, 'quote.expired');
        final ui = _section(expired, 'ui');

        expect(ui['actionStatus'], 'rejected');
        expect(ui['commandErrorCode'], 'expiredQuote');
        expect(_requests(expired), isEmpty);
        expect(_reservations(expired), isEmpty);
        expect(
          _section(expired, 'transactions')['referenceProviderSubmissionCount'],
          0,
        );
        expect(_wallet(expired, 'total'), 'KES 50,000.00');
      },
    );

    test(
      'checked-in JSON matches live controller and application scenarios',
      () async {
        final file = File('test/fixtures/flow_states.json');
        final expected = Map<String, Object?>.from(
          jsonDecode(file.readAsStringSync()) as Map,
        );
        final actual = buildReferenceFlowEvidence(
          await runAllReferenceScenarios(),
        );

        expect(actual, equals(expected));
      },
    );
  });
}
