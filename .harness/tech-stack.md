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

### 2.5 本地存储: SharedPreferences

**选择理由**:
- 简单易用
- 跨平台支持
- 适合存储歌单等简单数据

**替代方案**:
- Hive: 性能更好，但需要额外学习
- SQLite: 功能强大，但对于歌单管理过于复杂

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
│   └── router/                  # 路由配置
├── features/                    # 功能模块
│   ├── player/                  # 播放器模块
│   │   ├── data/                # 数据层
│   │   ├── domain/              # 业务逻辑层
│   │   └── presentation/        # 展示层
│   ├── playlist/                # 歌单模块
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
  shared_preferences: ^2.2.2

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

---

**确认状态**: ✅ 已确认

**确认结果**:
1. 技术选型认可
2. 依赖包版本确定
3. 架构设计合理
