# WAV 元数据扫描修复设计

## 问题背景

使用 `audiotags` 包扫描 WAV 文件时失败，错误信息：
```
AudioTagsError.openFile(message: Wav: Failed to read RIFF INFO item value)
```

这是 `audiotags` 底层的 `lofty` Rust 库在读取 WAV 文件 RIFF INFO 元数据时的已知 bug。

## 解决方案

采用纯 Dart RIFF INFO 解析方案，所有平台统一使用：

| 平台 | WAV 元数据方案 | 其他格式方案 |
|------|---------------|-------------|
| Windows/Linux | 纯 Dart RIFF INFO 解析 | audiotags |
| Android/iOS/macOS | 纯 Dart RIFF INFO 解析 | audiotags |

**优势：**
- 无需额外原生依赖
- 跨平台一致性
- 包体积不增加

## 架构设计

### 新增文件

```
lib/shared/utils/
├── wav_metadata_parser.dart  # 纯 Dart RIFF INFO 解析器
└── metadata_extractor.dart   # 统一元数据提取接口
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
      ┌───────────────────────┐       ┌───────────────┐
      │ WavMetadataParser     │       │  audiotags    │
      │ (纯 Dart RIFF INFO)   │       └───────────────┘
      └───────────────────────┘
              │
              ▼
      ┌───────────────────────┐
      │ 解析失败时回退到       │
      │ audiotags 或文件名     │
      └───────────────────────┘
```

## 组件设计

### WavMetadataParser（纯 Dart）

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

### MetadataExtractor（统一接口）

```dart
class MetadataExtractor {
  /// 提取音频文件元数据
  static Future<AudioMetadata?> extract(String filePath) async {
    final extension = filePath.toLowerCase();

    if (extension.endsWith('.wav')) {
      return _extractWavMetadata(filePath);
    }

    // 其他格式使用 audiotags
    return _extractWithAudiotags(filePath);
  }
}
```

## 错误处理

所有元数据提取方法都遵循优雅降级原则：

1. RIFF INFO 解析失败时，尝试 audiotags
2. audiotags 失败时，返回 null
3. 调用方收到 null 后，回退到文件名提取

## 测试计划

1. **单元测试**
   - RIFF INFO 解析器测试（有效/无效/空 WAV 文件）

2. **集成测试**
   - Windows: 扫描包含 WAV 文件的目录

## 实现顺序

1. 实现 `WavMetadataParser`（纯 Dart）
2. 实现 `MetadataExtractor` 统一接口
3. 修改 `WindowsMusicScanner` 和 `MobileMusicScanner` 使用新接口
4. 编写测试
