# Mysic 音乐播放器 - 技术选型

> 创建时间: 2026-04-18
> 更新时间: 2026-04-18
> 状态: ✅ 已确认

## 1. 技术栈总览

| 层级 | 技术选型 | 版本 | 说明 |
|------|---------|------|------|
| 框架 | Flutter | 3.35+ | 跨平台 UI 框架 |
| 语言 | Dart | 3.9+ | 编程语言 |
| 状态管理 | Provider | ^6.1.1 | 轻量级状态管理 |
| 路由 | GoRouter | ^13.0.0 | 声明式路由 |
| 音频播放 | just_audio | ^0.9.36 | 音频播放核心 |
| 后台播放 | audio_service | ^0.18.12 | 后台播放支持 |
| 本地音乐 | on_audio_query | ^2.6.1 | 本地音乐查询 |
| 本地存储 | SharedPreferences | ^2.2.2 | 键值存储 |
| 动画 | flutter_animate | ^4.3.0 | 声明式动画 |

## 2. 详细选型说明

### 2.1 框架选择: Flutter

**选择理由**:
- 一套代码支持 Android、iOS、Windows 三端
- 高性能渲染引擎 (Skia)
- 丰富的 UI 组件库
- 热重载提升开发效率

**替代方案**:
- React Native: JavaScript 生态，性能略逊
- 原生开发: 需要维护多套代码

### 2.2 状态管理: Provider

**选择理由**:
- 官方推荐方案
- 学习曲线平缓
- 性能优秀
- 社区支持完善

**替代方案**:
- Riverpod: 更现代，但学习成本更高
- Bloc: 过于复杂，适合大型项目
- GetX: 功能全面但过于臃肿

### 2.3 音频播放: just_audio + audio_service

**选择理由**:
- just_audio: 纯 Dart 实现，跨平台兼容性好
- audio_service: 官方推荐的后台播放方案
- 支持多种音频格式
- 支持锁屏控制、通知栏控制

**替代方案**:
- audioplayers: 功能较少，后台播放支持不完善
- assets_audio_player: 主要用于播放 assets 资源

### 2.4 本地音乐查询: on_audio_query

**选择理由**:
- 专为 Flutter 设计
- 支持查询本地音乐文件
- 支持获取元数据和封面
- 支持 Android、iOS

**替代方案**:
- flutter_audio_query: 维护不活跃
- 手动文件扫描: 实现复杂，兼容性差

### 2.5 本地存储: SQLite + 文件存储

**选择理由**:
- SQLite: 结构化数据存储，支持复杂查询
- 文件存储: 歌词、封面等大文件
- 为后期歌词功能扩展做准备

**数据存储分工**:
| 存储类型 | 数据内容 |
|---------|---------|
| SQLite | 歌单、播放历史、歌词元数据、用户设置 |
| 文件存储 | 歌词文件(.lrc)、封面图片缓存 |

**替代方案**:
- SharedPreferences: 功能有限，不支持复杂查询
- Hive: 性能好，但 SQL 查询能力不如 SQLite

### 2.6 歌词解析: 自定义 LRC 解析器

**选择理由**:
- LRC 格式简单，易于解析
- 支持时间标签 [mm:ss.xx]
- 支持逐字/逐行歌词
- 可扩展支持在线歌词 API

**LRC 格式示例**:
```
[ti:歌曲标题]
[ar:艺术家]
[al:专辑]
[00:00.00]第一行歌词
[00:05.50]第二行歌词
```

## 3. 项目架构

### 3.1 分层架构

```
┌─────────────────────────────────────┐
│         Presentation Layer          │
│  (Pages, Widgets, Providers)        │
├─────────────────────────────────────┤
│          Domain Layer               │
│  (Use Cases, Entities)              │
├─────────────────────────────────────┤
│           Data Layer                │
│  (Repositories, Data Sources)       │
└─────────────────────────────────────┘
```

### 3.2 目录结构

```
lib/
├── main.dart                    # 应用入口
├── app.dart                     # App 配置
├── core/                        # 核心功能
│   ├── theme/                   # 主题配置
│   ├── constants/               # 常量定义
│   ├── router/                  # 路由配置
│   └── database/                # 数据库帮助类
├── features/                    # 功能模块
│   ├── player/                  # 播放器模块
│   │   ├── data/                # 数据层
│   │   ├── domain/              # 业务逻辑层
│   │   └── presentation/        # 展示层
│   ├── playlist/                # 歌单模块
│   ├── lyrics/                  # 歌词模块
│   │   ├── data/                # 数据层（LRC 解析）
│   │   └── presentation/        # 展示层（歌词页面）
│   └── settings/                # 设置模块
└── shared/                      # 共享组件
    ├── widgets/                 # 通用组件
    └── utils/                   # 工具类
```

## 4. 依赖清单

```yaml
dependencies:
  flutter:
    sdk: flutter

  # 状态管理
  provider: ^6.1.1

  # 路由
  go_router: ^13.0.0

  # 音频播放
  just_audio: ^0.9.36
  audio_session: ^0.1.18
  audio_service: ^0.18.12

  # 本地音乐
  on_audio_query: ^2.6.1
  permission_handler: ^11.1.0

  # 本地存储
  sqflite: ^2.3.0
  sqflite_common_ffi: ^2.3.0  # Windows 支持
  path: ^1.8.0

  # 动画
  flutter_animate: ^4.3.0

  # 图片缓存
  cached_network_image: ^3.3.0

  # 路径
  path_provider: ^2.1.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

## 5. 平台特定配置

### 5.1 Android

```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

### 5.2 iOS

```xml
<!-- Info.plist -->
<key>NSAppleMusicUsageDescription</key>
<string>需要访问您的音乐库以播放本地音乐</string>
```

### 5.3 Windows

- 需要文件系统访问权限
- Visual Studio 2022 with C++ workload
- SQLite FFI 支持（通过 sqflite_common_ffi）

### 5.4 数据库设计

```sql
-- 歌曲信息缓存
CREATE TABLE songs (
    id TEXT PRIMARY KEY,
    title TEXT,
    artist TEXT,
    album TEXT,
    duration INTEGER,
    path TEXT,
    cover_path TEXT,
    created_at INTEGER
);

-- 歌单
CREATE TABLE playlists (
    id TEXT PRIMARY KEY,
    name TEXT,
    icon TEXT,
    color TEXT,
    created_at INTEGER
);

-- 歌单-歌曲关联
CREATE TABLE playlist_songs (
    playlist_id TEXT,
    song_id TEXT,
    position INTEGER,
    added_at INTEGER,
    PRIMARY KEY (playlist_id, song_id)
);

-- 歌词元数据（为后期扩展准备）
CREATE TABLE lyrics (
    song_id TEXT PRIMARY KEY,
    source TEXT,           -- 'local' | 'online' | 'cached'
    local_path TEXT,       -- 本地 .lrc 文件路径
    is_cached INTEGER,     -- 是否已缓存
    fetched_at INTEGER     -- 获取时间
);

-- 播放历史
CREATE TABLE play_history (
    song_id TEXT PRIMARY KEY,
    played_at INTEGER,
    play_count INTEGER
);

---

**确认状态**: ✅ 已确认

**确认结果**:
1. 技术选型认可
2. 依赖包版本确定
3. 架构设计合理
