import 'package:flutter/foundation.dart';
import 'app_exception.dart';

/// Uygulama genelinde logging sistem
enum LogLevel { debug, info, warning, error, critical }

class AppLogger {

  // Singleton pattern
  static final AppLogger _instance = AppLogger._internal();

  factory AppLogger() {
    return _instance;
  }

  AppLogger._internal();

  static void debug(String message, {String tag = 'DEBUG'}) {
    _log(LogLevel.debug, message, tag);
  }

  static void info(String message, {String tag = 'INFO'}) {
    _log(LogLevel.info, message, tag);
  }

  static void warning(String message, {String tag = 'WARNING'}) {
    _log(LogLevel.warning, message, tag);
  }

  static void error(String message, {String tag = 'ERROR', dynamic exception, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, tag, exception: exception, stackTrace: stackTrace);
  }

  static void critical(String message, {String tag = 'CRITICAL', dynamic exception, StackTrace? stackTrace}) {
    _log(LogLevel.critical, message, tag, exception: exception, stackTrace: stackTrace);
  }

  static void _log(
    LogLevel level,
    String message,
    String tag, {
    dynamic exception,
    StackTrace? stackTrace,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final levelName = level.toString().split('.').last.toUpperCase();
    final logMessage = '[$timestamp] [$levelName] [$tag] $message';

    if (kDebugMode) {
      print(logMessage);
      if (exception != null) {
        print('Exception: $exception');
      }
      if (stackTrace != null) {
        print('StackTrace: $stackTrace');
      }
    }

    // Production ortamında log kaydedilebilir
    // _saveLogToFile(logMessage, exception, stackTrace);
  }

  /// AppException'ları işlemek için özel metod
  static void logAppException(AppException exception, {String tag = 'APP_ERROR'}) {
    error(
      exception.message,
      tag: '${tag}_${exception.code}',
      exception: exception,
    );
  }
}

