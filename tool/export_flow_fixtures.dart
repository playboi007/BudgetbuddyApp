import 'dart:convert';
import 'dart:io';

import '../test/scenarios/flow_scenarios.dart';

Future<void> main(List<String> arguments) async {
  final checkOnly = arguments.length == 1 && arguments.single == '--check';
  if (arguments.isNotEmpty && !checkOnly) {
    stderr.writeln('Usage: dart run tool/export_flow_fixtures.dart [--check]');
    exitCode = 64;
    return;
  }

  final checkpoints = await runAllReferenceScenarios();
  final contents =
      '${const JsonEncoder.withIndent('  ').convert(buildReferenceFlowEvidence(checkpoints))}\n';
  final output = File('test/fixtures/flow_states.json');

  if (checkOnly) {
    if (!output.existsSync() || output.readAsStringSync() != contents) {
      stderr.writeln(
        'test/fixtures/flow_states.json differs from live reference scenarios. '
        'Run `dart run tool/export_flow_fixtures.dart` to regenerate it.',
      );
      exitCode = 1;
      return;
    }
    stdout.writeln(
      'Verified ${checkpoints.length} reference flow checkpoints against '
      'test/fixtures/flow_states.json.',
    );
    return;
  }

  output.writeAsStringSync(contents);
  stdout.writeln(
    'Exported ${checkpoints.length} reference flow checkpoints to '
    'test/fixtures/flow_states.json.',
  );
}
