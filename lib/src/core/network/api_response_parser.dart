class ApiResponseParser {
  const ApiResponseParser();

  T parse<T>(Map<String, dynamic> json, T Function(dynamic data) mapper) {
    final code = json['code'] as int? ?? -1;
    final message = json['message']?.toString() ?? 'unknown error';
    if (code != 200) {
      throw ApiException(code, message);
    }
    return mapper(json['data']);
  }
}

class ApiException implements Exception {
  ApiException(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => 'ApiException(code=$code, message=$message)';
}
