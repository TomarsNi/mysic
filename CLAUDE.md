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


**权衡：** 这些准则偏向谨慎而非速度。对于简单任务，请自行判断。

## 1. 编码前先思考

**不要假设。不要隐藏困惑。展示权衡。**

实现之前：
- 明确陈述你的假设。如果不确定，就问。
- 如果存在多种解释，全部呈现出来——不要静默选择。
- 如果有更简单的方法，说出来。必要时提出反对。
- 如果有不清楚的地方，停下来。指出困惑之处。提问。

## 2. 简单优先

**用最少的代码解决问题。不做推测性设计。**

- 不添加未被要求的功能。
- 不为单次使用的代码创建抽象。
- 不添加未被要求的"灵活性"或"可配置性"。
- 不为不可能发生的场景编写错误处理。
- 如果你写了 200 行代码而实际上 50 行就够了，重写它。

问问自己："资深工程师会认为这过于复杂吗？"如果是，简化它。

## 3. 精准修改

**只修改必须修改的部分。只清理自己造成的混乱。**

编辑现有代码时：
- 不要"改进"相邻的代码、注释或格式。
- 不要重构没有问题的代码。
- 匹配现有风格，即使你会用不同的方式。
- 如果你发现无关的死代码，提出来——不要删除它。

当你的修改产生孤立代码时：
- 删除因你的修改而变得未使用的导入/变量/函数。
- 除非被要求，否则不要删除原本就存在的死代码。

检验标准：每一行修改都应直接追溯到用户的请求。

## 4. 目标驱动执行

**定义成功标准。循环直到验证通过。**

将任务转化为可验证的目标：
- "添加验证" → "为无效输入编写测试，然后让测试通过"
- "修复 bug" → "编写一个能复现它的测试，然后让测试通过"
- "重构 X" → "确保重构前后测试都通过"

对于多步骤任务，陈述简要计划：
```
1. [步骤] → 验证: [检查项]
2. [步骤] → 验证: [检查项]
3. [步骤] → 验证: [检查项]
```

强有力的成功标准让你能够独立循环。弱标准（"让它工作"）需要不断澄清。

---

**这些准则有效的标志：** diff 中不必要的修改更少，因过度复杂导致的重写更少，澄清问题在实现之前提出而非在犯错之后。