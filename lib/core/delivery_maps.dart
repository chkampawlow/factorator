String deliveryAddress(Map<String, dynamic> delivery) {
  final destination = (delivery['delivery_address'] ?? '').toString().trim();
  if (destination.isNotEmpty) return destination;
  return (delivery['client_address'] ?? '').toString().trim();
}

/// Four stops fit the mobile browser limit of three intermediate waypoints.
/// Omitting origin lets Google Maps use the driver's current location.
Uri deliveryRouteUri(List<String> addresses) {
  if (addresses.isEmpty ||
      addresses.length > 4 ||
      addresses.any((address) => address.trim().isEmpty)) {
    throw ArgumentError('A route requires 1–4 non-empty addresses.');
  }
  final stops = addresses.map((address) => address.trim()).toList();
  final uri = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'travelmode': 'driving',
    'destination': stops.last,
    if (stops.length > 1) 'waypoints': stops.take(stops.length - 1).join('|'),
  });
  if (uri.toString().length > 2048) {
    throw ArgumentError('Route link exceeds the Google Maps URL limit.');
  }
  return uri;
}
