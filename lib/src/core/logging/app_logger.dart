import 'package:flutter/foundation.dart';

abstract class AppLogger {
  void info(String message, {Map<String, Object?> extra = const {}});
  void error(String message, {Object? error, StackTrace? stackTrace, Map<String, Object?> extra = const {}});
}

class ConsoleLogger implements AppLogger {
  @override
  void info(String message, {Map<String, Object?> extra = const {}}) {
    if (kDebugMode) {
      debugPrint('[INFO] $message ${_safeMap(extra)}');
    }
  }

  @override
  void error(String message, {Object? error, StackTrace? stackTrace, Map<String, Object?> extra = const {}}) {
    debugPrint('[ERROR] $message err=$error extra=${_safeMap(extra)}');
    if (kDebugMode && stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }

  Map<String, Object?> _safeMap(Map<String, Object?> src) {
    final map = Map<String, Object?>.from(src);
    map.removeWhere((key, _) => key.toLowerCase().contains('token') || key.toLowerCase().contains('password'));
    return map;
  }
}
