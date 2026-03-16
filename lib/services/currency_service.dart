import 'package:intl/intl.dart';
import 'exchange_rate_service.dart';

class CurrencyService {
  static String symbol(String currency) {
    switch (currency) {
      case 'EUR':
        return 'euro';
      case 'USD':
        return r'USD';
      case 'TND':
      default:
        return 'TND';
    }
  }

  static int decimals(String currency) {
    if (currency == 'TND') return 3;
    return 2;
  }

  static String format(double amountTnd, String currency) {
    final converted = ExchangeRateService.convert(amountTnd, currency);

    final formatted = NumberFormat.currency(
      locale: 'en_US',
      symbol: '',
      decimalDigits: decimals(currency),
    ).format(converted);

    return '$formatted ${symbol(currency)}';
  }
}