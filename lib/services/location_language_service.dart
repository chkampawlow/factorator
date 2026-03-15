import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationLanguageService {
  Future<bool> _handlePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied.');
    }

    return true;
  }

  Future<String> detectLanguageCodeFromLocation() async {
    await _handlePermission();

    final position = await Geolocator.getCurrentPosition();
    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (placemarks.isEmpty) return 'en';

    final countryCode = (placemarks.first.isoCountryCode ?? '').toUpperCase();

    if (countryCode == 'TN') return 'fr';

    const arabicCountries = {
      'DZ', 'MA', 'LY', 'EG', 'SA', 'AE', 'QA', 'KW', 'BH', 'OM',
      'JO', 'LB', 'IQ', 'SY', 'YE', 'SD', 'PS', 'MR'
    };

    if (arabicCountries.contains(countryCode)) return 'ar';

    return 'en';
  }
}