import 'package:flutter/foundation.dart';

/// 统一日志工具，替代空 catch 块
///
/// 参考：ui-ux-pro-max 规则 - 错误处理必须有日志输出
/// 仅在 debug 模式下输出日志，release 模式下不输出
class AppLogger {
  /// 记录错误日志
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[ERROR] $message');
      if (error != null) debugPrint('  Error: $error');
      if (stackTrace != null) debugPrint('  Stack: $stackTrace');
    }
  }

  /// 记录信息日志
  static void info(String message) {
    if (kDebugMode) {
      debugPrint('[INFO] $message');
    }
  }

  /// 记录警告日志
  static void warn(String message) {
    if (kDebugMode) {
      debugPrint('[WARN] $message');
    }
  }
}
