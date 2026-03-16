class ExchangeRateService {
  // base currency = TND
  static const Map<String, double> rates = {
    'TND': 1.0,
    'EUR': 0.30,
    'USD': 0.32,
  };

  static double convert(double amountTnd, String currency) {
    final rate = rates[currency] ?? 1.0;
    return amountTnd * rate;
  }
}