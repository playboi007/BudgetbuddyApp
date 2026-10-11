/// Nonnegative KES, stored as integer minor units (100 minor units = KES 1).
final class Money implements Comparable<Money> {
  factory Money.fromMinorUnits(int minorUnits) {
    if (minorUnits < 0 || minorUnits > maxMinorUnits) {
      throw RangeError.range(minorUnits, 0, maxMinorUnits, 'minorUnits');
    }
    return Money._(minorUnits);
  }

  factory Money.fromKes(int wholeKes) {
    if (wholeKes < 0 || wholeKes > maxMinorUnits ~/ 100) {
      throw RangeError.range(wholeKes, 0, maxMinorUnits ~/ 100, 'wholeKes');
    }
    return Money.fromMinorUnits(wholeKes * 100);
  }

  const Money._(this.minorUnits);

  // Keep arithmetic exact on the Flutter web JavaScript target as well as native.
  static const int maxMinorUnits = 9007199254740991;
  static const String currency = 'KES';
  static const Money zero = Money._(0);

  final int minorUnits;

  Money operator +(Money other) {
    if (minorUnits > maxMinorUnits - other.minorUnits) {
      throw RangeError('Money addition exceeds the exact integer range.');
    }
    return Money.fromMinorUnits(minorUnits + other.minorUnits);
  }

  Money operator -(Money other) =>
      Money.fromMinorUnits(minorUnits - other.minorUnits);

  bool operator <(Money other) => minorUnits < other.minorUnits;
  bool operator <=(Money other) => minorUnits <= other.minorUnits;
  bool operator >(Money other) => minorUnits > other.minorUnits;
  bool operator >=(Money other) => minorUnits >= other.minorUnits;

  @override
  int compareTo(Money other) => minorUnits.compareTo(other.minorUnits);

  @override
  bool operator ==(Object other) =>
      other is Money && minorUnits == other.minorUnits;

  @override
  int get hashCode => minorUnits.hashCode;

  @override
  String toString() =>
      'KES ${minorUnits ~/ 100}.${(minorUnits % 100).toString().padLeft(2, '0')}';
}
