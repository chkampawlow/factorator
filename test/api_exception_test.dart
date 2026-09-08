import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/api_exception.dart';

void main() {
  test('formats status, code, and request id without losing the message', () {
    const exception = ApiException(
      message: 'Access denied',
      statusCode: 403,
      code: 'FORBIDDEN',
      requestId: 'request-123',
    );

    expect(exception.toString(), contains('Access denied'));
    expect(exception.toString(), contains('HTTP 403'));
    expect(exception.toString(), contains('FORBIDDEN'));
    expect(exception.toString(), contains('request request-123'));
  });

  test('does not present transport failures as an HTTP response', () {
    const exception = ApiException(
      message: 'Unable to reach the server.',
      statusCode: 0,
      code: 'NETWORK_UNAVAILABLE',
    );

    expect(exception.toString(), 'Unable to reach the server.');
    expect(exception.toString(), isNot(contains('HTTP 0')));
  });

  test('identifies a missing deployed endpoint without exposing HTML', () {
    const exception = ApiException(
      message: 'This mobile API endpoint is not installed on the server.',
      statusCode: 404,
      code: 'ENDPOINT_NOT_FOUND',
    );

    expect(exception.toString(), contains('HTTP 404'));
    expect(exception.toString(), contains('ENDPOINT_NOT_FOUND'));
    expect(exception.toString(), isNot(contains('<html')));
  });
}
