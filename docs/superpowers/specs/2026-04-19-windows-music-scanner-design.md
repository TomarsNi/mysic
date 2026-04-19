# Windows 全盘音乐扫描设计

## 概述

为 Mysic 音乐播放器实现 Windows 平台的全盘音乐扫描功能，扫描所有可用驱动器上的音频文件。

## 需求

- 扫描所有驱动器（C:、D:、E: 等）
- 静默跳过无权限目录
- 识别常见音频格式：mp3、flac、wav、m4a、aac、ogg、wma
- 显示进度条、当前扫描路径、可取消按钮

## 架构

### 平台适配器模式

```
PlatformMusicScanner (抽象类)
├── WindowsMusicScanner (dart:io 文件遍历)
└── MobileMusicScanner (on_audio_query)
```

`MusicScanner` 作为门面类，内部委托给平台实现。调用方代码无需修改。

### 文件结构

```
lib/shared/utils/
├── music_scanner.dart           # 门面类（修改）
├── platform_music_scanner.dart  # 抽象基类（新增）
├── windows_music_scanner.dart   # Windows 实现（新增）
└── mobile_music_scanner.dart    # 移动端实现（新增）
```

## Windows 扫描流程

1. 获取所有可用驱动器
2. 对每个驱动器递归遍历目录
3. 跳过无权限目录和系统目录（如 `Windows`、`System Volume Information`）
4. 匹配音频文件扩展名
5. 提取元数据（标题、艺术家、时长）
6. 保存到数据库

### 跳过的目录

- `$RECYCLE.BIN`
- `System Volume Information`
- `Windows`
- `Program Files`
- `Program Files (x86)`
- `ProgramData`

### 音频格式

支持格式：`.mp3`, `.flac`, `.wav`, `.m4a`, `.aac`, `.ogg`, `.wma`

## 元数据提取

- **时长**：通过 `just_audio` 解析
- **标题**：从文件名提取（去除扩展名）
- **艺术家**：默认"未知艺术家"
- **专辑**：默认"未知专辑"

## 进度与取消机制

```dart
class ScanProgress {
  final String currentPath;      // 当前扫描路径
  final int filesScanned;        // 已扫描文件数
  final int songsFound;          // 发现的歌曲数
  final double progress;         // 进度百分比
}

// 取消扫描
scanner.cancelScan();
```

通过 `Stream<ScanProgress>` 实时推送进度，UI 层监听并更新界面。

## 性能考虑

- 使用 `Isolate` 执行扫描，避免阻塞 UI 线程
- 批量插入数据库，减少 I/O 次数
- 限制并发目录遍历数量，避免内存溢出

## 测试策略

- 单元测试：文件扩展名匹配、路径过滤
- 集成测试：模拟目录结构验证扫描结果
- 手动测试：在真实 Windows 环境验证全盘扫描
