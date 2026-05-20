import 'dart:isolate';
import 'package:logger/logger.dart';

/// 应用日志封装类
///
/// 提供统一的日志输出格式：时间 [级别] [线程] 类名#方法名 - 消息
class AppLogger {
  static final Logger _logger = Logger(
    printer: CustomLogPrinter(),
    level: Level.debug,
  );

  /// DEBUG 级别日志
  static void d(String tag, String message) {
    _logger.d(message, time: DateTime.now(), error: tag);
  }

  /// INFO 级别日志
  static void i(String tag, String message) {
    _logger.i(message, time: DateTime.now(), error: tag);
  }

  /// WARN 级别日志
  static void w(String tag, String message) {
    _logger.w(message, time: DateTime.now(), error: tag);
  }

  /// ERROR 级别日志
  static void e(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    _logger.e(message, time: DateTime.now(), error: tag, stackTrace: stackTrace);
  }

  /// 获取当前线程名称
  static String getThreadName() {
    final isolate = Isolate.current;
    final debugName = isolate.debugName;
    if (debugName == null) {
      return 'main';
    }
    return debugName;
  }
}

/// 自定义日志打印器
///
/// 输出格式：2024-05-20 14:30:25.123 [INFO] [main] WavMetadataParser#parse - 消息
class CustomLogPrinter extends LogPrinter {
  @override
  List<String> log(LogEvent event) {
    final time = _formatTime(event.time);
    final level = _formatLevel(event.level);
    final thread = AppLogger.getThreadName();
    final tag = event.error?.toString() ?? '';
    final message = event.message;

    final output = '$time [$level] [$thread] $tag - $message';

    // 根据级别添加颜色
    final coloredOutput = _colorize(output, event.level);

    return [coloredOutput];
  }

  /// 格式化时间：yyyy-MM-dd HH:mm:ss.SSS
  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final year = time.year.toString().padLeft(4, '0');
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    final ms = time.millisecond.toString().padLeft(3, '0');
    return '$year-$month-$day $hour:$minute:$second.$ms';
  }

  /// 格式化级别
  String _formatLevel(Level level) {
    return switch (level) {
      Level.debug => 'DEBUG',
      Level.info => 'INFO',
      Level.warning => 'WARN',
      Level.error => 'ERROR',
      Level.fatal => 'FATAL',
      Level.trace => 'TRACE',
      Level.all => 'ALL',
      Level.off => 'OFF',
      _ => 'UNKNOWN',
    };
  }

  /// 添加颜色
  String _colorize(String text, Level level) {
    final color = switch (level) {
      Level.debug => AnsiColor.fg(12), // 蓝色
      Level.info => AnsiColor.fg(10), // 绿色
      Level.warning => AnsiColor.fg(208), // 橙色
      Level.error => AnsiColor.fg(196), // 红色
      Level.fatal => AnsiColor.fg(199), // 粉红
      _ => AnsiColor.none(),
    };
    return color(text);
  }
}
