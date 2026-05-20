# 日志框架增强设计

## 概述

为 Mysic 项目引入结构化日志框架，替换现有的 `debugPrint` 调用，提供时间戳、线程名称、类名#方法名和日志级别的统一输出格式。

## 需求

- **日志框架**: 使用 `logger` 包
- **输出目标**: 仅控制台
- **日志级别**: DEBUG、INFO、WARN、ERROR
- **输出格式**: `时间 [级别] [线程] 类名#方法名 - 消息`
- **迁移策略**: 全部迁移现有 231 处 `debugPrint` 调用

## 架构

### 文件结构

```
lib/core/utils/
└── app_logger.dart    # 日志封装类
```

### AppLogger 类设计

```dart
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 120,
      colors: true,
      printEmojis: false,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: Level.debug,
  );

  // 日志级别方法
  static void d(String tag, String message) { ... }
  static void i(String tag, String message) { ... }
  static void w(String tag, String message) { ... }
  static void e(String tag, String message, [Object? error, StackTrace? stackTrace]) { ... }

  // 线程名称获取
  static String _getThreadName() { ... }
}
```

### 自定义 Printer

创建 `CustomLogPrinter` 继承 `LogPrinter`，实现目标格式：

```
2024-05-20 14:30:25.123 [INFO] [main] WavMetadataParser#parse - 文件不存在 /path/to/file.wav
```

**格式组成：**
- 时间：`yyyy-MM-dd HH:mm:ss.SSS`
- 级别：`DEBUG`、`INFO`、`WARN`、`ERROR`（带颜色）
- 线程：`main` 或 `Isolate.current.debugName`
- 标签：手动传入的 `类名#方法名`
- 消息：日志内容

### 线程名称获取

- 主线程：`main`
- 其他 Isolate：`Isolate.current.debugName ?? 'isolate-${Isolate.current.hashCode}'`

## 迁移策略

### 迁移映射规则

现有 `debugPrint` 调用按内容推断级别：

| 内容特征 | 目标级别 |
|---------|---------|
| 包含 "错误"、"失败"、"异常"、"error"、"exception" | ERROR |
| 包含 "警告"、"warn" | WARN |
| 包含 "完成"、"成功"、"结果" | INFO |
| 其他调试信息 | DEBUG |

### 标签提取

从现有日志字符串提取类名作为标签前缀：

```dart
// 原有格式
debugPrint('WavMetadataParser: 文件不存在 $filePath');

// 新格式
AppLogger.w('WavMetadataParser#parse', '文件不存在 $filePath');
```

### 迁移文件清单

16 个文件，231 处调用：

1. `lib/shared/utils/wav_metadata_parser.dart` (25 处)
2. `lib/shared/utils/windows_music_scanner.dart` (7 处)
3. `lib/shared/utils/mobile_music_scanner.dart` (62 处)
4. `lib/shared/widgets/bottom_sheet.dart` (4 处)
5. `lib/features/settings/presentation/pages/about_page.dart` (2 处)
6. `lib/features/player/data/services/audio_player_service.dart` (27 处)
7. `lib/features/player/data/services/audio_handler.dart` (15 处)
8. `lib/features/player/presentation/providers/player_provider.dart` (35 处)
9. `lib/features/playlist/presentation/providers/playlist_provider.dart` (20 处)
10. `lib/features/lyrics/data/services/lyrics_parser.dart` (7 处)
11. `lib/features/ai_skills/skills/song_recognition/song_recognition_skill.dart` (1 处)
12. `lib/core/utils/file_utils.dart` (1 处)
13. `lib/shared/utils/metadata_extractor.dart` (2 处)
14. `lib/shared/utils/saf_file_service.dart` (10 处)
15. `lib/main.dart` (12 处)
16. `integration_test/e2e_test.dart` (1 处)

## 实现步骤

1. 添加 `logger` 依赖到 `pubspec.yaml`
2. 创建 `lib/core/utils/app_logger.dart`
3. 创建自定义 `CustomLogPrinter`
4. 按文件逐个迁移 `debugPrint` 调用
5. 运行测试验证功能正常

## 测试验证

- 运行应用，观察日志输出格式
- 验证各级别日志颜色区分
- 确认线程名称正确显示
- 运行 `flutter test` 确保无破坏性变更