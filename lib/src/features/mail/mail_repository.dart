import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_response_parser.dart';
import '../../core/providers.dart';
import '../../core/storage/app_storage.dart';

class MailRepository {
  MailRepository(this._dio, this._parser, this._storage);
  final Dio _dio;
  final ApiResponseParser _parser;
  final AppStorage _storage;

  Future<List<Map<String, dynamic>>> fetchList({required int accountId, required int type, int emailId = 0, int size = 20}) async {
    try {
      final response = await _dio.get('/email/list', queryParameters: {
        'accountId': accountId,
        'type': type,
        'emailId': emailId,
        'size': size,
      });
      final data = _parser.parse<Map<String, dynamic>>(response.data as Map<String, dynamic>, (d) => d as Map<String, dynamic>);
      final list = ((data['list'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await _storage.writeMailCache(type == 0, list);
      return list;
    } catch (_) {
      return _storage.readMailCache(type == 0);
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllMailList({int emailId = 0, int size = 20}) async {
    final response = await _dio.get('/allEmail/list', queryParameters: {
      'emailId': emailId,
      'size': size,
    });
    final data = _parser.parse<Map<String, dynamic>>(response.data as Map<String, dynamic>, (d) => d as Map<String, dynamic>);
    return ((data['list'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> latest({required int accountId, required int emailId}) async {
    final response = await _dio.get('/email/latest', queryParameters: {'accountId': accountId, 'emailId': emailId});
    return _parser.parse<List<Map<String, dynamic>>>(response.data as Map<String, dynamic>, (d) {
      return ((d as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    });
  }

  Future<void> deleteEmails(List<int> ids) async {
    await _dio.delete('/email/delete', queryParameters: {'emailIds': ids.join(',')});
  }

  Future<void> star(int emailId, bool active) async {
    if (active) {
      await _dio.post('/star/add', data: {'emailId': emailId});
    } else {
      await _dio.delete('/star/cancel', queryParameters: {'emailId': emailId});
    }
  }

  Future<List<Map<String, dynamic>>> stars({int emailId = 0, int size = 20}) async {
    final response = await _dio.get('/star/list', queryParameters: {'emailId': emailId, 'size': size});
    final data = _parser.parse<Map<String, dynamic>>(response.data as Map<String, dynamic>, (d) => d as Map<String, dynamic>);
    return ((data['list'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>?> fetchDetail({
    required int accountId,
    required int type,
    required int emailId,
  }) async {
    final firstTry = await fetchList(accountId: accountId, type: type, emailId: emailId, size: 30);
    for (final item in firstTry) {
      if ((item['emailId'] as int?) == emailId) return item;
    }
    final secondTry = await fetchList(accountId: accountId, type: type, emailId: 0, size: 30);
    for (final item in secondTry) {
      if ((item['emailId'] as int?) == emailId) return item;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> send({
    required int accountId,
    required List<String> receiveEmail,
    required String subject,
    required String content,
    String manyType = 'merge',
    String? sendType,
    int? emailId,
    List<MultipartFile> attachments = const [],
    void Function(int sent, int total)? onSendProgress,
  }) async {
    late final Response<dynamic> response;
    if (attachments.isEmpty) {
      // 无附件优先走 JSON，避免后端对 multipart 字段 JSON.parse 出错。
      final payload = <String, dynamic>{
        'accountId': accountId,
        'receiveEmail': receiveEmail,
        'manyType': manyType,
        'name': '',
        'subject': subject,
        'text': '',
        'content': content,
        'attachments': const <dynamic>[],
      };
      if (sendType != null) payload['sendType'] = sendType;
      if (emailId != null) payload['emailId'] = emailId;
      response = await _dio.post(
        '/email/send',
        data: payload,
      );
    } else {
      final payload = <String, dynamic>{
        'accountId': accountId.toString(),
        'receiveEmail': jsonEncode(receiveEmail),
        'manyType': manyType,
        'name': '',
        'subject': subject,
        'text': '',
        'content': content,
        'attachments': attachments,
      };
      if (sendType != null) payload['sendType'] = sendType;
      if (emailId != null) payload['emailId'] = emailId.toString();
      final formData = FormData.fromMap(payload);
      response = await _dio.post('/email/send', data: formData, onSendProgress: onSendProgress);
    }
    return _parser.parse<List<Map<String, dynamic>>>(response.data as Map<String, dynamic>, (d) {
      if (d is List) {
        return d.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return const <Map<String, dynamic>>[];
    });
  }
}

final mailRepositoryProvider = Provider<MailRepository>((ref) {
  return MailRepository(ref.watch(dioProvider), ref.watch(parserProvider), ref.watch(storageReadyProvider));
});
