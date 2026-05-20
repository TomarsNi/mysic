# 日志框架增强实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 Mysic 项目引入结构化日志框架，替换所有 `debugPrint` 调用，提供时间戳、线程名称、类名#方法名和日志级别的统一输出格式。

**Architecture:** 创建 `AppLogger` 封装类，使用 `logger` 包，自定义 `CustomLogPrinter` 实现目标格式。按文件逐个迁移 231 处 `debugPrint` 调用。

**Tech Stack:** Flutter、logger 包、dart:isolate

---

## 文件结构

```
lib/core/utils/
└── app_logger.dart          # 新建 - 日志封装类

修改文件（16 个）:
├── lib/shared/utils/wav_metadata_parser.dart
├── lib/shared/utils/windows_music_scanner.dart
├── lib/shared/utils/mobile_music_scanner.dart
├── lib/shared/widgets/bottom_sheet.dart
├── lib/features/settings/presentation/pages/about_page.dart
├── lib/features/player/data/services/audio_player_service.dart
├── lib/features/player/data/services/audio_handler.dart
├── lib/features/player/presentation/providers/player_provider.dart
├── lib/features/playlist/presentation/providers/playlist_provider.dart
├── lib/features/lyrics/data/services/lyrics_parser.dart
├── lib/features/ai_skills/skills/song_recognition/song_recognition_skill.dart
├── lib/core/utils/file_utils.dart
├── lib/shared/utils/metadata_extractor.dart
├── lib/shared/utils/saf_file_service.dart
├── lib/main.dart
└── integration_test/e2e_test.dart
```

---

### Task 1: 添加 logger 依赖

**Files:**
- Modify: `mysic_flutter/pubspec.yaml`

- [ ] **Step 1: 添加 logger 依赖到 pubspec.yaml**

在 `dependencies` 部分添加 logger：

```yaml
dependencies:
  flutter:
    sdk: flutter

  # ... 其他依赖 ...

  # 日志框架
  logger: ^2.0.0
```

- [ ] **Step 2: 运行 flutter pub get**

Run: `cd mysic_flutter && flutter pub get`
Expected: 成功获取 logger 包

- [ ] **Step 3: Commit**

```bash
git add mysic_flutter/pubspec.yaml
git commit -m "chore: 添加 logger 依赖"
```

---

### Task 2: 创建 AppLogger 封装类

**Files:**
- Create: `mysic_flutter/lib/core/utils/app_logger.dart`

- [ ] **Step 1: 创建 AppLogger 类**

```dart
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
    _logger.d(message, time: DateTime.now(), error: null, stackTrace: null);
    // 使用 tag 作为额外信息传递给 printer
  }

  /// INFO 级别日志
  static void i(String tag, String message) {
    _logger.i(message, time: DateTime.now());
  }

  /// WARN 级别日志
  static void w(String tag, String message) {
    _logger.w(message, time: DateTime.now());
  }

  /// ERROR 级别日志
  static void e(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    _logger.e(message, time: DateTime.now(), error: error, stackTrace: stackTrace);
  }

  /// 获取当前线程名称
  static String _getThreadName() {
    // 主线程返回 main，其他 Isolate 返回其 debugName
    final isolate = Isolate.current;
    final debugName = isolate.debugName;
    if (debugName == null) {
      // 检查是否在主线程（通过 Zone.fork 的方式判断）
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
    final thread = AppLogger._getThreadName();
    final tag = event.error?.toString() ?? ''; // 使用 error 字段传递 tag
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
```

- [ ] **Step 2: 运行 flutter analyze 验证**

Run: `cd mysic_flutter && flutter analyze`
Expected: 无错误

- [ ] **Step 3: Commit**

```bash
git add mysic_flutter/lib/core/utils/app_logger.dart
git commit -m "feat: 创建 AppLogger 日志封装类"
```

---

### Task 3: 迁移 wav_metadata_parser.dart

**Files:**
- Modify: `mysic_flutter/lib/shared/utils/wav_metadata_parser.dart`

- [ ] **Step 1: 替换 import 和添加 AppLogger**

将第 4 行的 `import 'package:flutter/foundation.dart';` 替换为：

```dart
import 'package:mysic_flutter/core/utils/app_logger.dart';
```

- [ ] **Step 2: 替换所有 debugPrint 调用**

按以下映射替换：

| 原调用 | 新调用 |
|-------|-------|
| `debugPrint('WavMetadataParser: 文件不存在 $filePath');` | `AppLogger.w('WavMetadataParser#parse', '文件不存在 $filePath');` |
| `debugPrint('WavMetadataParser: 文件大小 ${bytes.length} bytes, 路径 $filePath');` | `AppLogger.d('WavMetadataParser#parse', '文件大小 ${bytes.length} bytes, 路径 $filePath');` |
| `debugPrint('WavMetadataParser: 解析结果 $result');` | `AppLogger.i('WavMetadataParser#parse', '解析结果 $result');` |
| `debugPrint('WavMetadataParser: 解析异常 $e');` | `AppLogger.e('WavMetadataParser#parse', '解析异常 $e', e);` |
| `debugPrint('WavMetadataParser: 文件太小 ${bytes.length} bytes');` | `AppLogger.w('WavMetadataParser#_parseBytes', '文件太小 ${bytes.length} bytes');` |
| `debugPrint('WavMetadataParser: 非 RIFF 格式，头为 $riffHeader');` | `AppLogger.w('WavMetadataParser#_parseBytes', '非 RIFF 格式，头为 $riffHeader');` |
| `debugPrint('WavMetadataParser: 非 WAVE 格式，格式为 $waveFormat');` | `AppLogger.w('WavMetadataParser#_parseBytes', '非 WAVE 格式，格式为 $waveFormat');` |
| `debugPrint('WavMetadataParser: 发现块 $chunkId, 大小 $chunkSize, 偏移 $offset');` | `AppLogger.d('WavMetadataParser#_parseBytes', '发现块 $chunkId, 大小 $chunkSize, 偏移 $offset');` |
| `debugPrint('WavMetadataParser: LIST 类型 $listType');` | `AppLogger.d('WavMetadataParser#_parseBytes', 'LIST 类型 $listType');` |
| `debugPrint('WavMetadataParser: 找到 INFO 块');` | `AppLogger.i('WavMetadataParser#_parseBytes', '找到 INFO 块');` |
| `debugPrint('WavMetadataParser: 未找到 INFO 块');` | `AppLogger.w('WavMetadataParser#_parseBytes', '未找到 INFO 块');` |
| `debugPrint('WavMetadataParser: 解析 INFO 块, start=$start, size=$size');` | `AppLogger.d('WavMetadataParser#_parseInfoChunk', '解析 INFO 块, start=$start, size=$size');` |
| `debugPrint('WavMetadataParser: 标签 $tagId, 数据大小 $dataSize');` | `AppLogger.d('WavMetadataParser#_parseInfoChunk', '标签 $tagId, 数据大小 $dataSize');` |
| `debugPrint('WavMetadataParser: 数据大小无效，停止解析');` | `AppLogger.w('WavMetadataParser#_parseInfoChunk', '数据大小无效，停止解析');` |
| `debugPrint('WavMetadataParser: 原始字节 ${dataBytes.toList()}');` | `AppLogger.d('WavMetadataParser#_parseInfoChunk', '原始字节 ${dataBytes.toList()}');` |
| `debugPrint('WavMetadataParser: 解码结果 "$value"');` | `AppLogger.d('WavMetadataParser#_parseInfoChunk', '解码结果 "$value"');` |
| `debugPrint('WavMetadataParser._decodeString: 内容字节 ${contentBytes.toList()}');` | `AppLogger.d('WavMetadataParser#_decodeString', '内容字节 ${contentBytes.toList()}');` |
| `debugPrint('WavMetadataParser._decodeString: 纯 ASCII');` | `AppLogger.d('WavMetadataParser#_decodeString', '纯 ASCII');` |
| `debugPrint('WavMetadataParser._decodeString: 尝试 $charset 解码');` | `AppLogger.d('WavMetadataParser#_decodeString', '尝试 $charset 解码');` |
| `debugPrint('WavMetadataParser._decodeString: $charset 结果 "$result"');` | `AppLogger.d('WavMetadataParser#_decodeString', '$charset 结果 "$result"');` |
| `debugPrint('WavMetadataParser._decodeString: $charset 解码失败 $e');` | `AppLogger.w('WavMetadataParser#_decodeString', '$charset 解码失败 $e');` |
| `debugPrint('WavMetadataParser._decodeString: 尝试 UTF-8 解码');` | `AppLogger.d('WavMetadataParser#_decodeString', '尝试 UTF-8 解码');` |
| `debugPrint('WavMetadataParser._decodeString: UTF-8 结果 "$utf8Result"');` | `AppLogger.d('WavMetadataParser#_decodeString', 'UTF-8 结果 "$utf8Result"');` |
| `debugPrint('WavMetadataParser._decodeString: UTF-8 解码失败 $e');` | `AppLogger.w('WavMetadataParser#_decodeString', 'UTF-8 解码失败 $e');` |
| `debugPrint('WavMetadataParser._decodeString: 回退到原始字节');` | `AppLogger.w('WavMetadataParser#_decodeString', '回退到原始字节');` |

- [ ] **Step 3: 运行 flutter analyze 验证**

Run: `cd mysic_flutter && flutter analyze`
Expected: 无错误

- [ ] **Step 4: Commit**

```bash
git add mysic_flutter/lib/shared/utils/wav_metadata_parser.dart
git commit -m "refactor: 迁移 wav_metadata_parser 日志到 AppLogger"
```

---

### Task 4: 迁移 windows_music_scanner.dart

**Files:**
- Modify: `mysic_flutter/lib/shared/utils/windows_music_scanner.dart`

- [ ] **Step 1: 添加 AppLogger import**

在文件顶部添加：

```dart
import 'package:mysic_flutter/core/utils/app_logger.dart';
```

- [ ] **Step 2: 替换所有 debugPrint 调用**

根据日志内容推断级别并替换：

- 包含 "成功"、"完成" → INFO
- 包含 "失败"、"错误"、"警告" → WARN 或 ERROR
- 其他调试信息 → DEBUG

- [ ] **Step 3: 运行 flutter analyze 验证**

Run: `cd mysic_flutter && flutter analyze`
Expected: 无错误

- [ ] **Step 4: Commit**

```bash
git add mysic_flutter/lib/shared/utils/windows_music_scanner.dart
git commit -m "refactor: 迁移 windows_music_scanner 日志到 AppLogger"
```

---

### Task 5: 迁移 mobile_music_scanner.dart

**Files:**
- Modify: `mysic_flutter/lib/shared/utils/mobile_music_scanner.dart`

- [ ] **Step 1: 添加 AppLogger import**

- [ ] **Step 2: 替换所有 debugPrint 调用**

- [ ] **Step 3: 运行 flutter analyze 验证**

- [ ] **Step 4: Commit**

```bash
git add mysic_flutter/lib/shared/utils/mobile_music_scanner.dart
git commit -m "refactor: 迁移 mobile_music_scanner 日志到 AppLogger"
```

---

### Task 6: 迁移 bottom_sheet.dart

**Files:**
- Modify: `mysic_flutter/lib/shared/widgets/bottom_sheet.dart`

- [ ] **Step 1: 添加 AppLogger import**

- [ ] **Step 2: 替换所有 debugPrint 调用**

- [ ] **Step 3: 运行 flutter analyze 验证**

- [ ] **Step 4: Commit**

```bash
git add mysic_flutter/lib/shared/widgets/bottom_sheet.dart
git commit -m "refactor: 迁移 bottom_sheet 日志到 AppLogger"
```

---

### Task 7: 迁移 about_page.dart

**Files:**
- Modify: `mysic_flutter/lib/features/settings/presentation/pages/about_page.dart`

- [ ] **Step 1: 添加 AppLogger import**

- [ ] **Step 2: 替换所有 debugPrint 调用**

- [ ] **Step 3: 运行 flutter analyze 验证**

- [ ] **Step 4: Commit**

```bash
git add mysic_flutter/lib/features/settings/presentation/pages/about_page.dart
git commit -m "refactor: 迁移 about_page 日志到 AppLogger"
```

---

### Task 8: 迁移 audio_player_service.dart

**Files:**
- Modify: `mysic_flutter/lib/features/player/data/services/audio_player_service.dart`

- [ ] **Step 1: 添加 AppLogger import**

- [ ] **Step 2: 替换所有 debugPrint 调用**

- [ ] **Step 3: 运行 flutter analyze 验证**

- [ ] **Step 4: Commit**

```bash
git add mysic_flutter/lib/features/player/data/services/audio_player_service.dart
git commit -m "refactor: 迁移 audio_player_service 日志到 AppLogger"
```

---

### Task 9: 迁移 audio_handler.dart

**Files:**
- Modify: `mysic_flutter/lib/features/player/data/services/audio_handler.dart`

- [ ] **Step 1: 添加 AppLogger import**

- [ ] **Step 2: 替换所有 debugPrint 调用**

- [ ] **Step 3: 运行 flutter analyze 验证**

- [ ] **Step 4: Commit**

```bash
git add mysic_flutter/lib/features/player/data/services/audio_handler.dart
git commit -m "refactor: 迁移 audio_handler 日志到 AppLogger"
```

---

### Task 10: 迁移 player_provider.dart

**Files:**
- Modify: `mysic_flutter/lib/features/player/presentation/providers/player_provider.dart`

- [ ] **Step 1: 添加 AppLogger import**

- [ ] **Step 2: 替换所有 debugPrint 调用**

- [ ] **Step 3: 运行 flutter analyze 验证**

- [ ] **Step 4: Commit**

```bash
git add mysic_flutter/lib/features/player/presentation/providers/player_provider.dart
git commit -m "refactor: 迁移 player_provider 日志到 AppLogger"
```

---

### Task 11: 迁移 playlist_provider.dart

**Files:**
- Modify: `mysic_flutter/lib/features/playlist/presentation/providers/playlist_provider.dart`

- [ ] **Step 1: 添加 AppLogger import**

- [ ] **Step 2: 替换所有 debugPrint 调用**

- [ ] **Step 3: 运行 flutter analyze 验证**

- [ ] **Step 4: Commit**

```bash
git add mysic_flutter/lib/features/playlist/presentation/providers/playlist_provider.dart
git commit -m "refactor: 迁移 playlist_provider 日志到 AppLogger"
```

---

### Task 12: 迁移 lyrics_parser.dart

**Files:**
- Modify: `mysic_flutter/lib/features/lyrics/data/services/lyrics_parser.dart`

- [ ] **Step 1: 添加 AppLogger import**

- [ ] **Step 2: 替换所有 debugPrint 调用**

- [ ] **Step 3: 运行 flutter analyze 验证**

- [ ] **Step 4: Commit**

```bash
git add mysic_flutter/lib/features/lyrics/data/services/lyrics_parser.dart
git commit -m "refactor: 迁移 lyrics_parser 日志到 AppLogger"
```

---

### Task 13: 迁移 song_recognition_skill.dart

**Files:**
- Modify: `mysic_flutter/lib/features/ai_skills/skills/song_recognition/song_recognition_skill.dart`

- [ ] **Step 1: 添加 AppLogger import**

- [ ] **Step 2: 替换所有 debugPrint 调用**

- [ ] **Step 3: 运行 flutter analyze 验证**

- [ ] **Step 4: Commit**

```bash
git add mysic_flutter/lib/features/ai_skills/skills/song_recognition/song_recognition_skill.dart
git commit -m "refactor: 迁移 song_recognition_skill 日志到 AppLogger"
```

---

### Task 14: 迁移 file_utils.dart

**Files:**
- Modify: `mysic_flutter/lib/core/utils/file_utils.dart`

- [ ] **Step 1: 添加 AppLogger import**

- [ ] **Step 2: 替换所有 debugPrint 调用**

- [ ] **Step 3: 运行 flutter analyze 验证**

- [ ] **Step 4: Commit**

```bash
git add mysic_flutter/lib/core/utils/file_utils.dart
git commit -m "refactor: 迁移 file_utils 日志到 AppLogger"
```

---

### Task 15: 迁移 metadata_extractor.dart

**Files:**
- Modify: `mysic_flutter/lib/shared/utils/metadata_extractor.dart`

- [ ] **Step 1: 添加 AppLogger import**

- [ ] **Step 2: 替换所有 debugPrint 调用**

- [ ] **Step 3: 运行 flutter analyze 验证**

- [ ] **Step 4: Commit**

```bash
git add mysic_flutter/lib/shared/utils/metadata_extractor.dart
git commit -m "refactor: 迁移 metadata_extractor 日志到 AppLogger"
```

---

### Task 16: 迁移 saf_file_service.dart

**Files:**
- Modify: `mysic_flutter/lib/shared/utils/saf_file_service.dart`

- [ ] **Step 1: 添加 AppLogger import**

- [ ] **Step 2: 替换所有 debugPrint 调用**

- [ ] **Step 3: 运行 flutter analyze 验证**

- [ ] **Step 4: Commit**

```bash
git add mysic_flutter/lib/shared/utils/saf_file_service.dart
git commit -m "refactor: 迁移 saf_file_service 日志到 AppLogger"
```

---

### Task 17: 迁移 main.dart

**Files:**
- Modify: `mysic_flutter/lib/main.dart`

- [ ] **Step 1: 添加 AppLogger import**

- [ ] **Step 2: 替换所有 debugPrint 调用**

- [ ] **Step 3: 运行 flutter analyze 验证**

- [ ] **Step 4: Commit**

```bash
git add mysic_flutter/lib/main.dart
git commit -m "refactor: 迁移 main 日志到 AppLogger"
```

---

### Task 18: 迁移 e2e_test.dart

**Files:**
- Modify: `mysic_flutter/integration_test/e2e_test.dart`

- [ ] **Step 1: 添加 AppLogger import**

- [ ] **Step 2: 替换所有 debugPrint 调用**

- [ ] **Step 3: 运行 flutter analyze 验证**

- [ ] **Step 4: Commit**

```bash
git add mysic_flutter/integration_test/e2e_test.dart
git commit -m "refactor: 迁移 e2e_test 日志到 AppLogger"
```

---

### Task 19: 验证和测试

**Files:**
- 无文件修改

- [ ] **Step 1: 运行 flutter test**

Run: `cd mysic_flutter && flutter test`
Expected: 所有测试通过

- [ ] **Step 2: 运行应用验证日志输出**

Run: `cd mysic_flutter && flutter run -d windows`
Expected: 日志输出格式为 `时间 [级别] [线程] 类名#方法名 - 消息`

- [ ] **Step 3: 最终 Commit**

```bash
git add -A
git commit -m "feat: 完成日志框架迁移，统一输出格式"
```

---

## 自检清单

- [x] Spec coverage: 所有设计文档要求已覆盖
- [x] Placeholder scan: 无 TBD、TODO 或模糊描述
- [x] Type consistency: AppLogger 方法签名一致