import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/shared/utils/wav_metadata_parser.dart';

void main() {
  group('WavMetadataParser', () {
    test('解析有效的 WAV 文件（包含 RIFF INFO）', () async {
      // 构造一个包含 RIFF INFO 的 WAV 文件
      // 注意：RIFF INFO 使用 ANSI 编码，测试使用 ASCII 字符
      final wavBytes = _createWavWithRiffInfo(
        title: 'Test Song',
        artist: 'Test Artist',
        album: 'Test Album',
      );

      final result = WavMetadataParser.parseBytes(wavBytes);

      expect(result, isNotNull);
      expect(result!['title'], equals('Test Song'));
      expect(result['artist'], equals('Test Artist'));
      expect(result['album'], equals('Test Album'));
    });

    test('解析不包含 RIFF INFO 的 WAV 文件', () async {
      // 构造一个不包含 RIFF INFO 的 WAV 文件
      final wavBytes = _createWavWithoutRiffInfo();

      final result = WavMetadataParser.parseBytes(wavBytes);

      expect(result, isNull);
    });

    test('解析无效的 WAV 文件（非 RIFF 格式）', () async {
      final invalidBytes = Uint8List.fromList([0, 0, 0, 0]);

      final result = WavMetadataParser.parseBytes(invalidBytes);

      expect(result, isNull);
    });

    test('解析空的字节数组', () async {
      final emptyBytes = Uint8List(0);

      final result = WavMetadataParser.parseBytes(emptyBytes);

      expect(result, isNull);
    });

    test('解析部分有效的 WAV 文件（只有 RIFF 头）', () async {
      final partialBytes = Uint8List.fromList([
        ...'RIFF'.codeUnits,
        0, 0, 0, 0, // 文件大小
        ...'WAVE'.codeUnits,
      ]);

      final result = WavMetadataParser.parseBytes(partialBytes);

      expect(result, isNull); // 没有 INFO 块
    });
  });
}

/// 创建包含 RIFF INFO 的 WAV 文件字节
Uint8List _createWavWithRiffInfo({
  required String title,
  required String artist,
  required String album,
}) {
  final builder = BytesBuilder();

  // 构建 INFO 块内容
  final infoBuilder = BytesBuilder();
  infoBuilder.add('INFO'.codeUnits);

  // 添加各个标签
  _addInfoTag(infoBuilder, 'INAM', title);
  _addInfoTag(infoBuilder, 'IART', artist);
  _addInfoTag(infoBuilder, 'IPRD', album);

  final infoData = infoBuilder.takeBytes();

  // fmt 块
  final fmtBuilder = BytesBuilder();
  fmtBuilder.add('fmt '.codeUnits);
  fmtBuilder.add(_littleEndian32(16)); // PCM fmt 块大小
  fmtBuilder.add([1, 0]); // 音频格式 (PCM)
  fmtBuilder.add([1, 0]); // 声道数 (单声道)
  fmtBuilder.add(_littleEndian32(44100)); // 采样率
  fmtBuilder.add(_littleEndian32(88200)); // 字节率
  fmtBuilder.add([2, 0]); // 块对齐
  fmtBuilder.add([16, 0]); // 位深度
  final fmtData = fmtBuilder.takeBytes();

  // data 块（空）
  final dataBuilder = BytesBuilder();
  dataBuilder.add('data'.codeUnits);
  dataBuilder.add(_littleEndian32(0));
  final dataData = dataBuilder.takeBytes();

  // LIST INFO 块
  final listBuilder = BytesBuilder();
  listBuilder.add('LIST'.codeUnits);
  listBuilder.add(_littleEndian32(infoData.length));
  listBuilder.add(infoData);
  final listData = listBuilder.takeBytes();

  // 计算总文件大小（RIFF 头后的所有数据）
  final totalContentSize = 4 + fmtData.length + dataData.length + listData.length;

  // 构建完整文件
  builder.add('RIFF'.codeUnits);
  builder.add(_littleEndian32(totalContentSize));
  builder.add('WAVE'.codeUnits);
  builder.add(fmtData);
  builder.add(dataData);
  builder.add(listData);

  return builder.takeBytes();
}

/// 创建不包含 RIFF INFO 的 WAV 文件字节
Uint8List _createWavWithoutRiffInfo() {
  final builder = BytesBuilder();

  // RIFF 头
  builder.add('RIFF'.codeUnits);
  builder.add(_littleEndian32(36)); // 文件大小
  builder.add('WAVE'.codeUnits);

  // fmt 块
  builder.add('fmt '.codeUnits);
  builder.add(_littleEndian32(16));
  builder.add([1, 0]);
  builder.add([1, 0]);
  builder.add(_littleEndian32(44100));
  builder.add(_littleEndian32(88200));
  builder.add([2, 0]);
  builder.add([16, 0]);

  // data 块（空）
  builder.add('data'.codeUnits);
  builder.add(_littleEndian32(0));

  return builder.takeBytes();
}

/// 添加 INFO 标签
void _addInfoTag(BytesBuilder builder, String tagId, String value) {
  builder.add(tagId.codeUnits);
  final valueBytes = Uint8List.fromList([...value.codeUnits, 0]); // null 终止
  builder.add(_littleEndian32(valueBytes.length));
  builder.add(valueBytes);
  // 块对齐（偶数）
  if (valueBytes.length % 2 != 0) {
    builder.addByte(0);
  }
}

/// 32 位 little-endian 整数
Uint8List _littleEndian32(int value) {
  return Uint8List(4)
    ..[0] = value & 0xFF
    ..[1] = (value >> 8) & 0xFF
    ..[2] = (value >> 16) & 0xFF
    ..[3] = (value >> 24) & 0xFF;
}
