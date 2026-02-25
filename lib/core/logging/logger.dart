import 'package:flutter/foundation.dart';

abstract class AppLogger {
  void debug(String message);
  void info(String message);
  void warning(String message);
  void error(String message, {Object? error, StackTrace? stackTrace});
}

class ConsoleLogger implements AppLogger {
  ConsoleLogger({required this.enabled});

  final bool enabled;

  @override
  void debug(String message) {
    _log('DEBUG', message);
  }

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    final details = [
      if (error != null) '$error',
      if (stackTrace != null) '$stackTrace',
    ].join('\n');
    _log('ERROR', details.isEmpty ? message : '$message\n$details');
  }

  @override
  void info(String message) {
    _log('INFO', message);
  }

  @override
  void warning(String message) {
    _log('WARN', message);
  }

  void _log(String level, String message) {
    if (!enabled) {
      return;
    }
    debugPrint('[$level] $message');
  }
}
