import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:charset_converter/charset_converter.dart';
import 'package:mysic_flutter/core/utils/app_logger.dart';

/// WAV 文件 RIFF INFO 元数据解析器
///
/// WAV 文件的元数据存储在 LIST INFO 块中，常见的标签包括：
/// - INAM: 标题
/// - IART: 艺术家
/// - IPRD: 专辑
/// - ICRD: 创建日期
class WavMetadataParser {
  /// RIFF INFO 标签映射
  static const Map<String, String> _tagMapping = {
    'INAM': 'title',
    'IART': 'artist',
    'IPRD': 'album',
    'ICRD': 'date',
  };

  /// 解析 WAV 文件的 RIFF INFO 元数据
  ///
  /// 返回包含元数据的 Map，如果解析失败返回 null
  static Future<Map<String, String>?> parse(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        AppLogger.w('WavMetadataParser#parse', '文件不存在 $filePath');
        return null;
      }

      final bytes = await file.readAsBytes();
      AppLogger.d('WavMetadataParser#parse', '文件大小 ${bytes.length} bytes, 路径 $filePath');
      final result = await _parseBytes(bytes);
      AppLogger.i('WavMetadataParser#parse', '解析结果 $result');
      return result;
    } catch (e) {
      AppLogger.e('WavMetadataParser#parse', '解析异常 $e', e);
      return null;
    }
  }

  /// 从字节数组解析 RIFF INFO（公开方法，用于测试）
  static Future<Map<String, String>?> parseBytes(Uint8List bytes) => _parseBytes(bytes);

  /// 从字节数组解析 RIFF INFO
  static Future<Map<String, String>?> _parseBytes(Uint8List bytes) async {
    if (bytes.length < 12) {
      AppLogger.w('WavMetadataParser#_parseBytes', '文件太小 ${bytes.length} bytes');
      return null;
    }

    // 验证 RIFF 头
    final riffHeader = String.fromCharCodes(bytes.sublist(0, 4));
    if (riffHeader != 'RIFF') {
      AppLogger.w('WavMetadataParser#_parseBytes', '非 RIFF 格式，头为 $riffHeader');
      return null;
    }

    // 验证 WAVE 格式
    final waveFormat = String.fromCharCodes(bytes.sublist(8, 12));
    if (waveFormat != 'WAVE') {
      AppLogger.w('WavMetadataParser#_parseBytes', '非 WAVE 格式，格式为 $waveFormat');
      return null;
    }

    // 查找 LIST INFO 块
    int offset = 12;
    while (offset < bytes.length - 8) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = _readLittleEndian32(bytes, offset + 4);
      AppLogger.d('WavMetadataParser#_parseBytes', '发现块 $chunkId, 大小 $chunkSize, 偏移 $offset');

      if (chunkId == 'LIST' && offset + 8 + chunkSize <= bytes.length) {
        final listType = String.fromCharCodes(bytes.sublist(offset + 8, offset + 12));
        AppLogger.d('WavMetadataParser#_parseBytes', 'LIST 类型 $listType');
        if (listType == 'INFO') {
          AppLogger.i('WavMetadataParser#_parseBytes', '找到 INFO 块');
          return await _parseInfoChunk(bytes, offset + 12, chunkSize - 4);
        }
      }

      offset += 8 + chunkSize;
      // 块对齐（偶数）
      if (chunkSize % 2 != 0) offset++;
    }

    AppLogger.w('WavMetadataParser#_parseBytes', '未找到 INFO 块');
    return null; // 未找到 INFO 块
  }

  /// 解析 INFO 块内容
  static Future<Map<String, String>> _parseInfoChunk(Uint8List bytes, int start, int size) async {
    final result = <String, String>{};
    int offset = start;
    final end = start + size;

    AppLogger.d('WavMetadataParser#_parseInfoChunk', '解析 INFO 块, start=$start, size=$size');

    while (offset < end - 8) {
      // 读取标签 ID（4 字节）
      final tagId = String.fromCharCodes(bytes.sublist(offset, offset + 4));

      // 读取数据大小（4 字节，little-endian）
      final dataSize = _readLittleEndian32(bytes, offset + 4);

      AppLogger.d('WavMetadataParser#_parseInfoChunk', '标签 $tagId, 数据大小 $dataSize');

      if (dataSize <= 0 || offset + 8 + dataSize > end) {
        AppLogger.w('WavMetadataParser#_parseInfoChunk', '数据大小无效，停止解析');
        break;
      }

      // 读取数据（null-terminated string）
      final dataBytes = bytes.sublist(offset + 8, offset + 8 + dataSize);
      AppLogger.d('WavMetadataParser#_parseInfoChunk', '原始字节 ${dataBytes.toList()}');
      final value = await _decodeString(dataBytes);
      AppLogger.d('WavMetadataParser#_parseInfoChunk', '解码结果 "$value"');

      // 映射到标准字段名
      // 跳过无效值（全是问号或乱码）
      final fieldName = _tagMapping[tagId];
      if (fieldName != null && value.isNotEmpty && !_isInvalidMetadata(value)) {
        result[fieldName] = value;
      }

      offset += 8 + dataSize;
      // 块对齐（偶数）
      if (dataSize % 2 != 0) offset++;
    }

    return result;
  }

  /// 读取 32 位 little-endian 整数
  static int _readLittleEndian32(Uint8List bytes, int offset) {
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }

  /// 解码字符串
  ///
  /// WAV 文件 RIFF INFO 通常使用 ANSI 编码（中文 Windows 为 GBK）。
  /// 策略：优先 GBK 解码，失败后尝试 UTF-8，最后回退到原始字节。
  static Future<String> _decodeString(Uint8List bytes) async {
    // 查找 null 终止符
    int end = bytes.length;
    for (int i = 0; i < bytes.length; i++) {
      if (bytes[i] == 0) {
        end = i;
        break;
      }
    }

    if (end == 0) return '';

    final contentBytes = bytes.sublist(0, end);
    AppLogger.d('WavMetadataParser#_decodeString', '内容字节 ${contentBytes.toList()}');

    // 纯 ASCII 字节可以直接解码
    if (_isPureAscii(contentBytes)) {
      AppLogger.d('WavMetadataParser#_decodeString', '纯 ASCII');
      return String.fromCharCodes(contentBytes).trim();
    }

    // 优先尝试 GBK 解码（WAV 文件通常来自 Windows 中文系统）
    // 尝试多种编码名称：GBK, gb18030, GB2312
    final gbkCharsets = ['GBK', 'gb18030', 'GB2312'];
    for (final charset in gbkCharsets) {
      try {
        AppLogger.d('WavMetadataParser#_decodeString', '尝试 $charset 解码');
        final result = await CharsetConverter.decode(charset, contentBytes);
        AppLogger.d('WavMetadataParser#_decodeString', '$charset 结果 "$result"');
        // 检查结果是否有效（不包含大量问号或乱码）
        if (result.isNotEmpty && !_isGarbled(result)) {
          return result.trim();
        }
      } catch (e) {
        AppLogger.w('WavMetadataParser#_decodeString', '$charset 解码失败 $e');
      }
    }

    // GBK 失败，尝试 UTF-8 解码
    try {
      AppLogger.d('WavMetadataParser#_decodeString', '尝试 UTF-8 解码');
      final utf8Result = utf8.decode(contentBytes);
      AppLogger.d('WavMetadataParser#_decodeString', 'UTF-8 结果 "$utf8Result"');
      return utf8Result.trim();
    } catch (e) {
      AppLogger.w('WavMetadataParser#_decodeString', 'UTF-8 解码失败 $e');
    }

    // 最后回退到原始字节解码
    AppLogger.w('WavMetadataParser#_decodeString', '回退到原始字节');
    return String.fromCharCodes(contentBytes).trim();
  }

  /// 检查字节是否为纯 ASCII（0x00-0x7F）
  static bool _isPureAscii(Uint8List bytes) {
    for (final b in bytes) {
      if (b > 0x7F) return false;
    }
    return true;
  }

  /// 检查字符串是否为乱码
  /// 乱码特征：大量问号、替换字符、或无效 Unicode 字符
  static bool _isGarbled(String text) {
    if (text.isEmpty) return true;

    int garbledCount = 0;
    for (int i = 0; i < text.length; i++) {
      final codeUnit = text.codeUnitAt(i);
      // 替换字符 (U+FFFD) 或问号
      if (codeUnit == 0xFFFD || codeUnit == 0x3F) {
        garbledCount++;
      }
    }

    // 如果超过 30% 是乱码字符，认为解码失败
    return garbledCount > text.length * 0.3;
  }

  /// 检查元数据是否无效
  /// 无效元数据：全是问号、空字符串、或只有问号
  static bool _isInvalidMetadata(String value) {
    if (value.isEmpty) return true;

    // 检查是否全是问号
    for (int i = 0; i < value.length; i++) {
      if (value.codeUnitAt(i) != 0x3F) {
        return false; // 有非问号字符，有效
      }
    }
    return true; // 全是问号，无效
  }
}
