import 'package:cloudmail/src/core/network/api_response_parser.dart';
import 'package:cloudmail/src/features/auth/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late AuthRepository repository;

  setUp(() {
    dio = _MockDio();
    repository = AuthRepository(dio, const ApiResponseParser());
  });

  test('login returns token', () async {
    when(
      () => dio.post(
        any(),
        data: any(named: 'data'),
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
        onSendProgress: any(named: 'onSendProgress'),
        onReceiveProgress: any(named: 'onReceiveProgress'),
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/login'),
        data: {'code': 200, 'message': 'success', 'data': {'token': 'token-1'}},
      ),
    );

    final token = await repository.login(baseUrl: 'https://example.com/api', email: 'a@b.com', password: '123456');
    expect(token, 'token-1');
  });
}
