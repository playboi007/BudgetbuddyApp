import 'validation.dart';

enum PaymentRoute { phoneNumber, till, paybill }

/// Canonical Kenyan number. Provider eligibility is checked by the adapter.
final class MpesaPhoneNumber {
  MpesaPhoneNumber(String value) : value = value.trim() {
    if (!RegExp(r'^254[17]\d{8}$').hasMatch(this.value)) {
      throw ArgumentError.value(
        value,
        'phoneNumber',
        'Use 2547… or 2541… format.',
      );
    }
  }

  final String value;
}

sealed class PaymentRecipient {
  const PaymentRecipient();
  PaymentRoute get route;
}

final class PhoneRecipient extends PaymentRecipient {
  const PhoneRecipient(this.phoneNumber);
  final MpesaPhoneNumber phoneNumber;

  @override
  PaymentRoute get route => PaymentRoute.phoneNumber;
}

final class TillRecipient extends PaymentRecipient {
  TillRecipient(String tillNumber)
    : tillNumber = _digits(tillNumber, 'tillNumber');
  final String tillNumber;

  @override
  PaymentRoute get route => PaymentRoute.till;
}

final class PaybillRecipient extends PaymentRecipient {
  PaybillRecipient({
    required String paybillNumber,
    required String accountReference,
  }) : paybillNumber = _digits(paybillNumber, 'paybillNumber'),
       accountReference = nonBlank(accountReference, 'accountReference');

  final String paybillNumber;
  final String accountReference;

  @override
  PaymentRoute get route => PaymentRoute.paybill;
}

String _digits(String value, String field) {
  final normalized = nonBlank(value, field);
  if (!RegExp(r'^\d+$').hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'Must contain digits only.');
  }
  // Preserve leading zeros. Route-specific length checks belong to the adapter.
  return normalized;
}
