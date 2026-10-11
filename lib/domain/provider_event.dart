import 'money.dart';
import 'transactions.dart';
import 'validation.dart';

enum ProviderEventDisposition { received, applied, duplicate, quarantined }

/// Backend evidence record, not client authority to settle a transaction.
/// Sensitive raw callback content belongs behind payloadReference, not in UI.
final class ProviderEvent {
  ProviderEvent({
    required String id,
    required this.requestId,
    required this.identifiers,
    required this.resultCode,
    required this.resultDescription,
    required this.reportedAmount,
    required DateTime receivedAt,
    required String payloadReference,
    required this.disposition,
    required this.quarantineReason,
  }) : id = nonBlank(id, 'id'),
       payloadReference = nonBlank(payloadReference, 'payloadReference'),
       receivedAt = receivedAt.toUtc() {
    if (disposition == ProviderEventDisposition.quarantined) {
      nonBlank(quarantineReason ?? '', 'quarantineReason');
    } else if (quarantineReason != null) {
      throw ArgumentError('Only quarantined events have a quarantine reason.');
    }
    if (disposition == ProviderEventDisposition.applied ||
        disposition == ProviderEventDisposition.duplicate) {
      nonBlank(requestId ?? '', 'requestId');
    }
  }

  final String id;
  final String? requestId;
  final ProviderIdentifiers identifiers;
  final String? resultCode;
  final String? resultDescription;
  final Money? reportedAmount;
  final DateTime receivedAt;
  final String payloadReference;
  final ProviderEventDisposition disposition;
  final String? quarantineReason;
}
