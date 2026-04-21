# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

Mysic 是一个跨平台本地音乐播放器，使用 Flutter 开发，支持 Android、iOS 和 Windows。主要功能包括本地音乐扫描、歌单管理、歌词显示（LRC 格式）和后台播放。

## UI 设计规范（必须遵循）

**设计稿**: `F:\opc\mysic\index.html` — 所有 UI 开发必须以此为基准，确保视觉效果一致。

### 核心视觉要素
- **颜色方案**: `#18181b`(surface)、`#27272a`(card)、`#10b981`(accent)、`#71717a`(muted)
- **字体**: Inter，标题 24px Bold，正文 16px，次要文字 14px
- **专辑封面**: 圆形 260px，播放时带 `pulse-glow` 动画（3s 周期，scale 1.08）
- **歌单图标**: 渐变色背景（如 `from-accent to-teal-600`、`from-rose-500 to-pink-600`）
- **进度条**: 8px 高，拇指 24px 圆形 accent 色，带阴影发光
- **底部面板**: 圆角顶部 `rounded-t-3xl`，拖拽指示条

### 动画规范
- 过渡时长: 150-300ms
- 缓动曲线: `cubic-bezier(0.4, 0, 0.2, 1)`
- 抽屉动画: `translateX` 280ms
- 底部面板: `translateY` 300ms

### 约束要求
1. 开发 UI 组件前，必须阅读 `index.html` 对应部分的 HTML/CSS
2. 实现完成后，需与设计稿进行视觉对比验证
3. 颜色、尺寸、动画参数必须精确匹配设计稿定义

## 常用命令

```bash
# 运行应用（Windows 桌面版）
cd mysic_flutter && flutter run -d windows

# 构建 Windows 版本
cd mysic_flutter && flutter build windows

# 运行所有测试
cd mysic_flutter && flutter test

# 运行单个测试文件
cd mysic_flutter && flutter test test/audio_player_service_test.dart

# 代码分析
cd mysic_flutter && flutter analyze

# 获取依赖
cd mysic_flutter && flutter pub get
```

## 架构

项目采用基于功能模块的分层架构：

```
lib/
├── main.dart                 # 应用入口，初始化 Windows SQLite FFI
├── core/                     # 核心工具
│   ├── theme/               # 主题和颜色
│   └── database/            # SQLite 数据库帮助类
├── features/                 # 功能模块
│   ├── player/              # 音频播放
│   │   ├── data/            # Song 模型、AudioPlayerService (just_audio)
│   │   └── presentation/    # PlayerProvider、组件、页面
│   ├── playlist/            # 歌单管理
│   │   ├── data/            # PlaylistRepository、SQLite CRUD
│   │   └── presentation/    # PlaylistProvider、组件
│   ├── lyrics/              # 歌词显示
│   │   ├── data/            # LRC 解析器
│   │   └── presentation/    # 歌词页面
│   └── settings/            # 应用设置
└── shared/                   # 跨功能组件
    ├── widgets/             # 可复用 UI 组件（AppDrawer、BottomSheet）
    └── utils/               # MusicScanner（平台适配）
```

## 关键技术细节

### 状态管理
- 使用 Provider (`ChangeNotifier`) 进行状态管理
- `PlayerProvider` 管理播放状态，委托给 `AudioPlayerService`
- `PlaylistProvider` 管理歌单，委托给 `PlaylistRepository`

### 音频播放
- `AudioPlayerService` 封装 `just_audio.AudioPlayer`
- 支持播放列表播放、随机播放、循环模式（关闭/单曲/列表）
- 使用 `ConcatenatingAudioSource` 管理播放列表
- 通过 `audio_service` 实现后台播放

### 数据库
- SQLite：移动端使用 `sqflite`，Windows 使用 `sqflite_common_ffi`
- 表结构：`songs`、`playlists`、`playlist_songs`、`lyrics`、`play_history`
- Windows 平台需在 `main.dart` 中初始化 FFI 后才能访问数据库

### 音乐扫描
- `MusicScanner` 委托给平台特定实现：
  - `WindowsMusicScanner`：Windows/Linux 文件系统扫描
  - `MobileMusicScanner`：Android/iOS 使用 `on_audio_query`
- 支持进度流和取消操作

### 平台特定说明
- Windows：需要 Visual Studio C++ 工作负载，需初始化 SQLite FFI
- Android：需要 `READ_EXTERNAL_STORAGE`、`READ_MEDIA_AUDIO` 权限
- iOS：需要在 Info.plist 中添加 `NSAppleMusicUsageDescription`

## Git 提交规范

提交信息格式：
```
<type>(<scope>): <描述>

- 完成任务: <task_id> - <task_name>
- 变更文件: <file_list>
```

类型：`feat`（新功能）、`fix`（修复）、`refactor`（重构）、`test`（测试）、`docs`（文档）、`chore`（构建/配置）
