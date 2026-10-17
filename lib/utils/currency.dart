import 'package:intl/intl.dart';

/// Mata uang yang didukung aplikasi.
class AppCurrency {
  final String code;
  final String symbol;
  final String locale;
  final int decimalDigits;
  final String nameId;
  final String nameEn;

  const AppCurrency({
    required this.code,
    required this.symbol,
    required this.locale,
    required this.decimalDigits,
    required this.nameId,
    required this.nameEn,
  });

  String format(num value) {
    final fmt = NumberFormat.currency(
      locale: locale,
      symbol: symbol,
      decimalDigits: decimalDigits,
    );
    return fmt.format(value);
  }
}

/// Daftar mata uang yang didukung. IDR selalu pertama (default).
const supportedCurrencies = <AppCurrency>[
  AppCurrency(code: 'IDR', symbol: 'Rp ', locale: 'id_ID', decimalDigits: 0, nameId: 'Rupiah Indonesia', nameEn: 'Indonesian Rupiah'),
  AppCurrency(code: 'USD', symbol: '\$', locale: 'en_US', decimalDigits: 2, nameId: 'Dolar AS', nameEn: 'US Dollar'),
  AppCurrency(code: 'EUR', symbol: 'EUR ', locale: 'de_DE', decimalDigits: 2, nameId: 'Euro', nameEn: 'Euro'),
  AppCurrency(code: 'SGD', symbol: 'S\$', locale: 'en_SG', decimalDigits: 2, nameId: 'Dolar Singapura', nameEn: 'Singapore Dollar'),
  AppCurrency(code: 'MYR', symbol: 'RM', locale: 'ms_MY', decimalDigits: 2, nameId: 'Ringgit Malaysia', nameEn: 'Malaysian Ringgit'),
  AppCurrency(code: 'JPY', symbol: 'JPY ', locale: 'ja_JP', decimalDigits: 0, nameId: 'Yen Jepang', nameEn: 'Japanese Yen'),
  AppCurrency(code: 'GBP', symbol: 'GBP ', locale: 'en_GB', decimalDigits: 2, nameId: 'Pound Sterling', nameEn: 'British Pound'),
  AppCurrency(code: 'AUD', symbol: 'A\$', locale: 'en_AU', decimalDigits: 2, nameId: 'Dolar Australia', nameEn: 'Australian Dollar'),
];

/// Cari mata uang berdasarkan kode; fallback ke IDR bila tidak dikenal.
AppCurrency currencyByCode(String code) {
  final upper = code.toUpperCase();
  for (final c in supportedCurrencies) {
    if (c.code == upper) return c;
  }
  return supportedCurrencies.first;
}

/// Format nominal dalam mata uang tertentu.
String formatMoney(num value, [String currencyCode = 'IDR']) =>
    currencyByCode(currencyCode).format(value);
