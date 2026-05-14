# WAV 元数据扫描修复设计

## 问题背景

使用 `audiotags` 包扫描 WAV 文件时失败，错误信息：
```
AudioTagsError.openFile(message: Wav: Failed to read RIFF INFO item value)
```

这是 `audiotags` 底层的 `lofty` Rust 库在读取 WAV 文件 RIFF INFO 元数据时的已知 bug。

## 解决方案

采用平台差异化方案：

| 平台 | WAV 元数据方案 | 其他格式方案 |
|------|---------------|-------------|
| Windows | 纯 Dart 解析 RIFF INFO | audiotags |
| Android/iOS/macOS | ffmpeg_kit_flutter | audiotags |

## 架构设计

### 新增文件

```
lib/shared/utils/
├── wav_metadata_parser.dart      # 纯 Dart RIFF INFO 解析器
├── ffmpeg_metadata_extractor.dart # FFmpeg 元数据提取器（移动端）
└── metadata_extractor.dart        # 统一元数据提取接口
```

### 元数据提取流程

```
┌─────────────────────────────────────────────────────────────┐
│                    _extractMetadata(filePath)               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ 判断文件扩展名   │
                    └─────────────────┘
                              │
              ┌───────────────┴───────────────┐
              │                               │
              ▼                               ▼
      ┌───────────────┐               ┌───────────────┐
      │  WAV 文件     │               │  其他格式     │
      └───────────────┘               └───────────────┘
              │                               │
              ▼                               ▼
      ┌───────────────┐               ┌───────────────┐
      │ 判断平台       │               │  audiotags    │
      └───────────────┘               └───────────────┘
              │
    ┌─────────┴─────────┐
    │                   │
    ▼                   ▼
┌─────────┐       ┌─────────────────┐
│ Windows │       │ Android/iOS/macOS│
└─────────┘       └─────────────────┘
    │                   │
    ▼                   ▼
┌─────────────────┐ ┌─────────────────┐
│ RIFF INFO 解析器 │ │ FFmpeg 提取器   │
│ (纯 Dart)       │ │ (ffmpeg_kit)   │
└─────────────────┘ └─────────────────┘
```

## 组件设计

### 1. WavMetadataParser（纯 Dart）

解析 WAV 文件的 RIFF INFO 块，提取：
- title (INAM)
- artist (IART)
- album (IPRD)
- creation date (ICRD)

**WAV 文件结构：**
```
RIFF header (12 bytes)
  ├── 'RIFF' (4 bytes)
  ├── file size (4 bytes, little-endian)
  └── 'WAVE' (4 bytes)

fmt chunk
  ├── 'fmt ' (4 bytes)
  ├── chunk size (4 bytes)
  └── format data

data chunk
  ├── 'data' (4 bytes)
  ├── chunk size (4 bytes)
  └── audio data

LIST INFO chunk (可选)
  ├── 'LIST' (4 bytes)
  ├── chunk size (4 bytes)
  ├── 'INFO' (4 bytes)
  └── info items
        ├── 'INAM' + size + title
        ├── 'IART' + size + artist
        ├── 'IPRD' + size + album
        └── ...
```

### 2. FFmpegMetadataExtractor（移动端）

使用 `ffmpeg_kit_flutter` 提取元数据：
- 通过 `-i` 参数读取文件信息
- 解析 FFmpeg 输出的 metadata

### 3. MetadataExtractor（统一接口）

```dart
class MetadataExtractor {
  /// 提取音频文件元数据
  static Future<AudioMetadata?> extract(String filePath) async {
    final extension = filePath.toLowerCase();

    if (extension.endsWith('.wav')) {
      if (Platform.isWindows || Platform.isLinux) {
        return WavMetadataParser.parse(filePath);
      } else {
        return FFmpegMetadataExtractor.extract(filePath);
      }
    }

    // 其他格式使用 audiotags
    return _extractWithAudiotags(filePath);
  }
}
```

## 依赖变更

### pubspec.yaml 新增

```yaml
dependencies:
  ffmpeg_kit_flutter_min: ^6.0.3  # 最小化版本，减少包体积
```

**注意：** `ffmpeg_kit_flutter_min` 只支持 Android/iOS/macOS，Windows/Linux 使用纯 Dart 方案。

## 错误处理

所有元数据提取方法都遵循优雅降级原则：

1. 提取失败时，返回 `null`
2. 调用方收到 `null` 后，回退到文件名提取
3. 时长可通过 `just_audio` 获取（项目已有依赖）

## 测试计划

1. **单元测试**
   - RIFF INFO 解析器测试（有效/无效/空 WAV 文件）
   - FFmpeg 输出解析测试

2. **集成测试**
   - Windows: 扫描包含 WAV 文件的目录
   - Android: 扫描包含 WAV 文件的目录

## 风险评估

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| ffmpeg_kit 增加包体积 | 中 | 使用 `_min` 版本，约 5-10MB |
| RIFF INFO 不是所有 WAV 都有 | 低 | 回退到文件名提取 |
| FFmpeg 未安装在移动端 | 无 | ffmpeg_kit 内嵌 FFmpeg |

## 实现顺序

1. 实现 `WavMetadataParser`（纯 Dart）
2. 添加 `ffmpeg_kit_flutter_min` 依赖
3. 实现 `FFmpegMetadataExtractor`
4. 实现 `MetadataExtractor` 统一接口
5. 修改 `WindowsMusicScanner` 和 `MobileMusicScanner` 使用新接口
6. 编写测试
