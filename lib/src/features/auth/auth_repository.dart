import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_response_parser.dart';
import '../../core/providers.dart';

class AuthRepository {
  AuthRepository(this._dio, this._parser);
  final Dio _dio;
  final ApiResponseParser _parser;

  Future<String> login({
    required String baseUrl,
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      '$baseUrl/login',
      data: {'email': email, 'password': password},
    );
    return _parser.parse<String>(response.data as Map<String, dynamic>, (data) {
      final map = data as Map<String, dynamic>;
      return map['token']?.toString() ?? '';
    });
  }

  Future<Map<String, dynamic>> loginUserInfo() async {
    final response = await _dio.get('/my/loginUserInfo');
    return _parser.parse<Map<String, dynamic>>(response.data as Map<String, dynamic>, (data) => data as Map<String, dynamic>);
  }

  Future<void> logout() async {
    await _dio.delete('/logout');
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioProvider), ref.watch(parserProvider));
});
