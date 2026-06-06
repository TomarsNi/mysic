# Mysic

一款跨平台本地音乐播放器，使用 Flutter 开发，支持 Android、iOS 和 Windows。

## 功能特性

- **本地音乐扫描**：自动扫描设备中的音乐文件，支持 MP3、FLAC、WAV 等格式
- **歌单管理**：创建、编辑、删除歌单，支持收藏功能
- **歌词显示**：支持 LRC 格式歌词，时间同步高亮，支持时间偏移调整
- **后台播放**：通过 `audio_service` 实现后台播放和通知栏控制
- **AI 技能**：集成 AI 功能，支持歌曲识别和歌词搜索
- **睡眠定时**：支持设置睡眠倒计时，自动暂停播放
- **搜索功能**：支持按歌曲名、艺术家搜索本地音乐

## 技术栈

- **Flutter 3.9+** - 跨平台 UI 框架
- **Provider** - 状态管理
- **just_audio + audio_service** - 音频播放与后台服务
- **sqflite** - SQLite 数据库（移动端）
- **sqflite_common_ffi** - Windows 平台 SQLite 支持
- **go_router** - 路由管理

## 项目结构

```
lib/
├── main.dart                          # 应用入口
├── core/                              # 核心模块
│   ├── database/                      # 数据库帮助类
│   ├── services/                      # 核心服务
│   ├── theme/                           # 主题与颜色定义
│   └── utils/                           # 工具类
├── features/                          # 功能模块
│   ├── ai_skills/                     # AI 技能
│   │   ├── core/                        # 核心逻辑
│   │   ├── presentation/                # UI 层
│   │   └── skills/                      # 具体技能实现
│   ├── lyrics/                        # 歌词功能
│   │   ├── data/                        # 数据层
│   │   └── presentation/                # UI 层
│   ├── player/                        # 音频播放
│   │   ├── data/                        # 数据层（模型、仓库、服务）
│   │   └── presentation/                # UI 层（Provider、组件）
│   ├── playlist/                      # 歌单管理
│   │   ├── data/                        # 数据层
│   │   └── presentation/                # UI 层
│   └── settings/                      # 应用设置
│       ├── data/                        # 数据层
│       └── presentation/                # UI 层
└── shared/                            # 共享组件
    ├── utils/                           # 工具函数
    └── widgets/                         # 可复用 UI 组件
```

## 开发环境

### 前置要求

- Flutter SDK ^3.9.0
- Dart SDK ^3.9.0
- Android Studio / Xcode（对应平台）
- Visual Studio（Windows 桌面版，需 C++ 工作负载）

### 安装依赖

```bash
cd mysic_flutter
flutter pub get
```

### 运行应用

```bash
# Windows 桌面版
flutter run -d windows

# Android
flutter run -d android

# iOS
flutter run -d ios
```

### 构建发布版本

```bash
# Windows
flutter build windows

# Android
flutter build apk --release

# iOS
flutter build ios --release
```

## 数据库

应用使用 SQLite 存储数据，包含以下表：

- `songs` - 歌曲信息
- `playlists` - 歌单信息
- `playlist_songs` - 歌单与歌曲关联
- `lyrics` - 歌词数据
- `play_history` - 播放历史

## 平台特定说明

### Windows

- 需要 Visual Studio C++ 工作负载
- 在 `main.dart` 中初始化 SQLite FFI 后才能访问数据库
- 使用 `sqflite_common_ffi` 提供 SQLite 支持

### Android

- 需要 `READ_EXTERNAL_STORAGE`、`READ_MEDIA_AUDIO` 权限
- 支持 Android 13+ 的通知权限请求

### iOS

- 需要在 `Info.plist` 中添加 `NSAppleMusicUsageDescription`

## 测试

```bash
# 运行所有测试
flutter test

# 运行单个测试文件
flutter test test/audio_player_service_test.dart

# 代码分析
flutter analyze
```

## 依赖

主要依赖包：

| 包名 | 用途 |
|------|------|
| `provider` | 状态管理 |
| `just_audio` | 音频播放 |
| `audio_service` | 后台播放支持 |
| `sqflite` | SQLite 数据库 |
| `go_router` | 路由管理 |
| `permission_handler` | 权限管理 |
| `cached_network_image` | 图片缓存 |

完整依赖列表见 [`pubspec.yaml`](mysic_flutter/pubspec.yaml)。

## 设计规范

UI 设计参考 `index.html` 设计稿，核心视觉要素：

- **颜色方案**：`#18181b`(surface)、`#27272a`(card)、`#10b981`(accent)、`#71717a`(muted)
- **字体**：Inter，标题 24px Bold，正文 16px，次要文字 14px
- **专辑封面**：圆形 260px，播放时带 `pulse-glow` 动画
- **动画**：过渡时长 150-300ms，缓动曲线 `cubic-bezier(0.4, 0, 0.2, 1)`

## 许可证

[MIT](LICENSE)
