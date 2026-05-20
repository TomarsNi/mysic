import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:charset_converter/charset_converter.dart';
import 'package:mysic_flutter/core/utils/app_logger.dart';

/// 歌词行数据模型
class LyricLine {
  final Duration timestamp;
  final String text;

  const LyricLine({
    required this.timestamp,
    required this.text,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LyricLine &&
        other.timestamp == timestamp &&
        other.text == text;
  }

  @override
  int get hashCode => Object.hash(timestamp, text);

  @override
  String toString() => 'LyricLine($timestamp, $text)';
}

/// 歌词解析结果
class LyricsResult {
  final List<LyricLine> lines;
  final Map<String, String> metadata;
  final bool isValid;

  const LyricsResult({
    required this.lines,
    required this.metadata,
    this.isValid = true,
  });

  /// 空歌词结果
  static const LyricsResult empty = LyricsResult(
    lines: [],
    metadata: {},
    isValid: false,
  );

  /// 获取标题
  String? get title => metadata['ti'];

  /// 获取艺术家
  String? get artist => metadata['ar'];

  /// 获取专辑
  String? get album => metadata['al'];

  /// 获取歌词作者
  String? get author => metadata['au'];

  /// 获取时长
  Duration? get duration {
    final length = metadata['length'];
    if (length == null) return null;
    return _parseTimeTag(length);
  }

  /// 根据时间获取当前歌词行索引
  int getCurrentLineIndex(Duration position) {
    if (lines.isEmpty) return -1;

    for (int i = lines.length - 1; i >= 0; i--) {
      if (position >= lines[i].timestamp) {
        return i;
      }
    }
    return 0;
  }

  /// 根据时间获取当前歌词行
  LyricLine? getCurrentLine(Duration position) {
    final index = getCurrentLineIndex(position);
    if (index < 0 || index >= lines.length) return null;
    return lines[index];
  }

  /// 解析时间标签 (mm:ss.xx 或 mm:ss)
  static Duration? _parseTimeTag(String tag) {
    // 支持格式: mm:ss.xx 或 mm:ss
    final regex = RegExp(r'(\d+):(\d+)(?:\.(\d+))?');
    final match = regex.firstMatch(tag);
    if (match == null) return null;

    final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
    final seconds = int.tryParse(match.group(2) ?? '0') ?? 0;
    final milliseconds = int.tryParse(match.group(3)?.padRight(3, '0') ?? '0') ?? 0;

    return Duration(
      minutes: minutes,
      seconds: seconds,
      milliseconds: milliseconds,
    );
  }
}

/// 歌词解析服务
/// 解析 .lrc 文件，支持时间标签
class LyricsParser {
  /// 时间标签正则表达式
  /// 支持格式: [mm:ss.xx], [mm:ss], [mm:ss:xx]
  static final RegExp _timeTagRegex = RegExp(
    r'\[(\d+):(\d+)(?:[.:](\d+))?\]',
  );

  /// 元数据标签正则表达式
  /// 支持格式: [ti:标题], [ar:艺术家], [al:专辑] 等
  static final RegExp _metadataRegex = RegExp(
    r'\[([a-zA-Z]+):(.+)\]',
  );

  /// 从字符串解析歌词
  LyricsResult parse(String content) {
    if (content.trim().isEmpty) {
      return LyricsResult.empty;
    }

    final lines = <LyricLine>[];
    final metadata = <String, String>{};

    // 按行分割
    final contentLines = content.split('\n');

    for (var line in contentLines) {
      line = line.trim();
      if (line.isEmpty) continue;

      // 检查是否是元数据行
      final metadataMatch = _metadataRegex.firstMatch(line);
      if (metadataMatch != null) {
        final key = metadataMatch.group(1)?.toLowerCase();
        final value = metadataMatch.group(2);
        if (key != null && value != null) {
          metadata[key] = value.trim();
        }
        continue;
      }

      // 解析时间标签
      final timeTags = _timeTagRegex.allMatches(line);
      if (timeTags.isEmpty) continue;

      // 获取歌词文本（移除时间标签）
      var text = line.replaceAll(_timeTagRegex, '').trim();
      if (text.isEmpty) continue;

      // 处理多个时间标签（同一行歌词可能有多个时间点）
      for (final timeMatch in timeTags) {
        final minutes = int.tryParse(timeMatch.group(1) ?? '0') ?? 0;
        final seconds = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
        final milliseconds = int.tryParse(
              (timeMatch.group(3) ?? '0').padRight(3, '0').substring(0, 3),
            ) ??
            0;

        final timestamp = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );

        lines.add(LyricLine(
          timestamp: timestamp,
          text: text,
        ));
      }
    }

    // 按时间排序
    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return LyricsResult(
      lines: lines,
      metadata: metadata,
      isValid: lines.isNotEmpty,
    );
  }

  /// 从文件解析歌词
  /// 自动检测编码（支持 UTF-8 和 GBK）
  Future<LyricsResult> parseFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return LyricsResult.empty;
      }

      // 先读取字节
      final bytes = await file.readAsBytes();
      final content = await _decodeBytes(bytes);
      return parse(content);
    } catch (e) {
      return LyricsResult.empty;
    }
  }

  /// 从文件路径解析歌词（同步）
  /// 注意：同步方法仅支持 UTF-8 编码
  LyricsResult parseFileSync(String filePath) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        return LyricsResult.empty;
      }

      // 先读取字节
      final bytes = file.readAsBytesSync();
      final content = _decodeBytesSync(bytes);
      return parse(content);
    } catch (e) {
      return LyricsResult.empty;
    }
  }

  /// 解码字节数组，自动检测编码
  /// 优先尝试 UTF-8，失败则尝试 GBK
  Future<String> _decodeBytes(Uint8List bytes) async {
    // 尝试 UTF-8 解码
    try {
      final content = utf8.decode(bytes);
      // 检查是否有乱码特征（替换字符）
      if (!content.contains('�')) {
        AppLogger.i('LyricsParser#_decodeBytes', 'UTF-8 解码成功');
        return content;
      } else {
        AppLogger.d('LyricsParser#_decodeBytes', 'UTF-8 解码有乱码，尝试 GBK');
      }
    } catch (e) {
      AppLogger.w('LyricsParser#_decodeBytes', 'UTF-8 解码失败: $e');
    }

    // 尝试 GBK 解码（使用 charset_converter）
    // Windows 使用 cp936 (代码页 936)，其他平台使用 gbk
    final charsetNames = Platform.isWindows
        ? ['cp936', 'gb2312', 'gbk']
        : ['gbk', 'gb2312', 'cp936'];

    for (final charset in charsetNames) {
      try {
        AppLogger.d('LyricsParser#_decodeBytes', '尝试 $charset 解码，字节数: ${bytes.length}');
        final decoded = await CharsetConverter.decode(charset, bytes);
        AppLogger.i('LyricsParser#_decodeBytes', '$charset 解码成功');
        return decoded;
      } catch (e) {
        AppLogger.w('LyricsParser#_decodeBytes', '$charset 解码失败: $e');
      }
    }

    // 回退：返回容错 UTF-8
    AppLogger.d('LyricsParser#_decodeBytes', '回退到容错 UTF-8 解码');
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// 同步解码字节数组（仅支持 UTF-8）
  String _decodeBytesSync(Uint8List bytes) {
    try {
      final content = utf8.decode(bytes);
      if (!content.contains('�')) {
        return content;
      }
    } catch (_) {}
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// 将歌词转换为 LRC 格式字符串
  String toLrc(LyricsResult lyrics) {
    final buffer = StringBuffer();

    // 写入元数据
    for (final entry in lyrics.metadata.entries) {
      buffer.writeln('[${entry.key}:${entry.value}]');
    }

    // 写入歌词行
    for (final line in lyrics.lines) {
      final minutes = line.timestamp.inMinutes;
      final seconds = line.timestamp.inSeconds % 60;
      final milliseconds = line.timestamp.inMilliseconds % 1000;

      final timeTag = '[${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}.'
          '${milliseconds.toString().padLeft(3, '0')}]';

      buffer.writeln('$timeTag${line.text}');
    }

    return buffer.toString();
  }

  /// 根据音频文件路径查找对应的歌词文件
  /// 支持同名 .lrc 文件
  String? findLyricsFile(String audioFilePath) {
    final audioFile = File(audioFilePath);
    final directory = audioFile.parent;

    // 获取文件名（包含扩展名）
    final parts = audioFilePath.split(RegExp(r'[\\/]'));
    final fileName = parts.isNotEmpty ? parts.last : '';

    // 移除扩展名
    final baseName = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;

    // 查找同名 .lrc 文件
    final lrcFile = File('${directory.path}${Platform.pathSeparator}$baseName.lrc');
    if (lrcFile.existsSync()) {
      return lrcFile.path;
    }

    return null;
  }
}
