import 'package:intl/intl.dart';

class CurrencyFormat {
  CurrencyFormat._();
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: 'Ksh ',
    decimalDigits: 2,
    locale: 'en_KE',
  );

  static String format(double amount) {
    return _currencyFormat.format(amount);
  }
}
/*  
} _currencyFormat = NumberFormat.currency(
  symbol: 'Ksh ',
  decimalDigits: 2,
  locale: 'en_KE',
);*/
