class ExchangeRateService {
  // base currency = TND
  static const double timbreTnd = 1.0;
  static const double fodecRate = 1.000;
  static const Map<String, double> fodecRates = {
    'TND': fodecRate,
    'EUR': fodecRate,
    'USD': fodecRate,
  };

  static const Map<String, double> rates = {
    'TND': 1.0,
    'EUR': 0.30,
    'USD': 0.32,
  };

  static double convert(double amountTnd, String currency) {
    final rate = rates[currency] ?? 1.0;
    return amountTnd * rate;
  }

  static double convertToTnd(double amount, String currency) {
    final rate = rates[currency] ?? 1.0;
    if (rate == 0) return amount;
    return amount / rate;
  }

  static double fodecRateForCurrency(String currency) {
    return fodecRates[currency.toUpperCase()] ?? fodecRate;
  }

  static bool fodecEnabledFromMap(Map<String, dynamic> values) {
    for (final key in const ['fodec', 'is_fodec', 'fodec_enabled']) {
      if (!values.containsKey(key)) continue;

      final value = values[key];
      if (value is bool) return value;
      if (value is num) return value != 0;

      final normalized = value?.toString().trim().toLowerCase() ?? '';
      if (normalized.isEmpty) continue;
      if (normalized == '1' ||
          normalized == 'true' ||
          normalized == 'yes' ||
          normalized == 'oui') {
        return true;
      }
      if (normalized == '0' ||
          normalized == 'false' ||
          normalized == 'no' ||
          normalized == 'non') {
        return false;
      }
    }

    final legacyRate = values['fodec_rate'];
    if (legacyRate is num) return legacyRate > 0;
    if (legacyRate != null) {
      final parsed = double.tryParse(
        legacyRate.toString().trim().replaceAll(',', '.'),
      );
      if (parsed != null) return parsed > 0;
    }

    return false;
  }
}
