import 'money.dart';

String nonBlank(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be blank.');
  }
  return normalized;
}

Money positive(Money value, String field) {
  if (value == Money.zero) {
    throw ArgumentError.value(value, field, 'Must be greater than zero.');
  }
  return value;
}
