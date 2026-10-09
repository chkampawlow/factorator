import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/delivery_maps.dart';

void main() {
  test('uses the delivery destination even without a client address', () {
    expect(deliveryAddress({'delivery_address': '  Warehouse, Tunis  '}),
        'Warehouse, Tunis');
    expect(
        deliveryAddress({
          'delivery_address': 'Delivery site',
          'client_address': 'Billing address',
        }),
        'Delivery site');
  });
  test('blank delivery destination falls back to customer address', () {
    expect(
        deliveryAddress({
          'delivery_address': '   ',
          'client_address': '  Sousse  ',
        }),
        'Sousse');
    expect(deliveryAddress({'client_address': 'Sfax'}), 'Sfax');
    expect(deliveryAddress({}), isEmpty);
  });
  test('single destination uses current location and encodes address', () {
    final uri = deliveryRouteUri(['Rue de la République, Tunis']);
    expect(uri.queryParameters['destination'], 'Rue de la République, Tunis');
    expect(uri.queryParameters.containsKey('origin'), isFalse);
    expect(uri.queryParameters.containsKey('waypoints'), isFalse);
  });
  test('multiple destinations preserve selected order and Arabic text', () {
    final uri = deliveryRouteUri(['تونس', 'Sousse', 'Sfax', 'Gabès']);
    expect(uri.queryParameters['waypoints'], 'تونس|Sousse|Sfax');
    expect(uri.queryParameters['destination'], 'Gabès');
  });
  test('invalid routes never silently discard destinations', () {
    expect(() => deliveryRouteUri([]), throwsArgumentError);
    expect(() => deliveryRouteUri([' ']), throwsArgumentError);
    expect(
        () => deliveryRouteUri(List.filled(5, 'Tunis')), throwsArgumentError);
    expect(() => deliveryRouteUri(['a' * 2100]), throwsArgumentError);
  });
}
