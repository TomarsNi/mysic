import 'dart:io';
import 'dart:typed_data';

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
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      return _parseBytes(bytes);
    } catch (e) {
      return null;
    }
  }

  /// 从字节数组解析 RIFF INFO（公开方法，用于测试）
  static Map<String, String>? parseBytes(Uint8List bytes) => _parseBytes(bytes);

  /// 从字节数组解析 RIFF INFO
  static Map<String, String>? _parseBytes(Uint8List bytes) {
    if (bytes.length < 12) return null;

    // 验证 RIFF 头
    final riffHeader = String.fromCharCodes(bytes.sublist(0, 4));
    if (riffHeader != 'RIFF') return null;

    // 验证 WAVE 格式
    final waveFormat = String.fromCharCodes(bytes.sublist(8, 12));
    if (waveFormat != 'WAVE') return null;

    // 查找 LIST INFO 块
    int offset = 12;
    while (offset < bytes.length - 8) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = _readLittleEndian32(bytes, offset + 4);

      if (chunkId == 'LIST' && offset + 8 + chunkSize <= bytes.length) {
        final listType = String.fromCharCodes(bytes.sublist(offset + 8, offset + 12));
        if (listType == 'INFO') {
          return _parseInfoChunk(bytes, offset + 12, chunkSize - 4);
        }
      }

      offset += 8 + chunkSize;
      // 块对齐（偶数）
      if (chunkSize % 2 != 0) offset++;
    }

    return null; // 未找到 INFO 块
  }

  /// 解析 INFO 块内容
  static Map<String, String> _parseInfoChunk(Uint8List bytes, int start, int size) {
    final result = <String, String>{};
    int offset = start;
    final end = start + size;

    while (offset < end - 8) {
      // 读取标签 ID（4 字节）
      final tagId = String.fromCharCodes(bytes.sublist(offset, offset + 4));

      // 读取数据大小（4 字节，little-endian）
      final dataSize = _readLittleEndian32(bytes, offset + 4);

      if (dataSize <= 0 || offset + 8 + dataSize > end) break;

      // 读取数据（null-terminated string）
      final dataBytes = bytes.sublist(offset + 8, offset + 8 + dataSize);
      final value = _decodeString(dataBytes);

      // 映射到标准字段名
      final fieldName = _tagMapping[tagId];
      if (fieldName != null && value.isNotEmpty) {
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

  /// 解码字符串（移除 null 终止符）
  static String _decodeString(Uint8List bytes) {
    // 查找 null 终止符
    int end = bytes.length;
    for (int i = 0; i < bytes.length; i++) {
      if (bytes[i] == 0) {
        end = i;
        break;
      }
    }

    if (end == 0) return '';

    try {
      // 尝试 UTF-8 解码
      return String.fromCharCodes(bytes.sublist(0, end)).trim();
    } catch (e) {
      return '';
    }
  }
}
