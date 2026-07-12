import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class DevLogs {
  static final Logger _logger = Logger();
  static void logInfo(String msg) {
    developer.log('\x1B[34m$msg\x1B[0m');
    if (kDebugMode) {
      _logger.i(msg);
    }
  }

  static void logSuccess(String msg) {
    developer.log('\x1B[32m$msg\x1B[0m');
    if (kDebugMode) {
      _logger.i(msg);
    }
  }

  static void logWarning(String msg) {
    developer.log('\x1B[33m$msg\x1B[0m');
    if (kDebugMode) {
      _logger.w(msg);
    }
  }

  static void logError(String msg) {
    developer.log('\x1B[31m$msg\x1B[0m');
    if (kDebugMode) {
      _logger.e(msg);
    }
  }
}
