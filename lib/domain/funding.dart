import 'money.dart';
import 'quotes.dart';
import 'validation.dart';

/// A calculation for display/validation, not authorization to debit money.
final class FundingRequirement {
  FundingRequirement({
    required this.quote,
    required Money categoryAvailable,
    required this.globalAvailable,
  }) : categoryContribution = categoryAvailable < quote.amount
           ? categoryAvailable
           : quote.amount;

  final PaymentQuote quote;
  final Money categoryContribution;
  final Money globalAvailable;

  Money get globalShortfall => quote.amount - categoryContribution;
  bool get needsGlobalApproval => globalShortfall != Money.zero;
  bool get isFullyFundable => globalAvailable >= globalShortfall;
  Money get unfunded =>
      isFullyFundable ? Money.zero : globalShortfall - globalAvailable;
}

final class GlobalFundingApproval {
  GlobalFundingApproval({
    required String quoteId,
    required String ownerId,
    required Money amount,
    required DateTime approvedAt,
  }) : quoteId = nonBlank(quoteId, 'quoteId'),
       ownerId = nonBlank(ownerId, 'ownerId'),
       amount = positive(amount, 'amount'),
       approvedAt = approvedAt.toUtc();

  final String quoteId;
  final String ownerId;
  final Money amount;
  final DateTime approvedAt;
}

/// The backend must authenticate the owner, check quote freshness, and reserve
/// funds atomically.
final class PaymentFundingPlan {
  PaymentFundingPlan({
    required this.quote,
    required this.categoryContribution,
    required this.globalContribution,
    required this.approval,
  }) {
    if (categoryContribution + globalContribution != quote.amount) {
      throw ArgumentError('Funding must cover the complete spend amount.');
    }
    if (globalContribution == Money.zero) {
      if (approval != null) {
        throw ArgumentError('No global contribution needs no global approval.');
      }
    } else {
      if (approval == null ||
          approval!.quoteId != quote.id ||
          approval!.amount != globalContribution ||
          !quote.isValidAt(approval!.approvedAt)) {
        throw ArgumentError(
          'Global funding needs approval for this quote and amount.',
        );
      }
    }
  }

  final PaymentQuote quote;
  final Money categoryContribution;
  final Money globalContribution;
  final GlobalFundingApproval? approval;

  Money get totalReserved => categoryContribution + globalContribution;
}
