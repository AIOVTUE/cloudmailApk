import 'package:cloudmail/src/core/network/api_response_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = ApiResponseParser();

  test('parse returns data when code is 200', () {
    final result = parser.parse<Map<String, dynamic>>(
      {'code': 200, 'message': 'success', 'data': {'token': 'abc'}},
      (data) => Map<String, dynamic>.from(data as Map),
    );
    expect(result['token'], 'abc');
  });

  test('parse throws ApiException when code is not 200', () {
    expect(
      () => parser.parse({'code': 403, 'message': 'forbidden'}, (data) => data),
      throwsA(isA<ApiException>()),
    );
  });
}
