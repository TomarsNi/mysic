# Mysic 音乐播放器 - 外部依赖清单

> 创建时间: 2026-04-18
> 状态: 待配置

## 1. 开发环境依赖

### 1.1 必需工具

| 工具 | 版本要求 | 检查命令 | 状态 |
|------|---------|---------|------|
| Flutter SDK | 3.35+ | `flutter --version` | ⏳ 待检查 |
| Dart SDK | 3.9+ | `dart --version` | ⏳ 待检查 |
| Android Studio | 最新 | - | ⏳ 待检查 |
| VS Code | 最新 | - | ⏳ 待检查 |

### 1.2 平台特定工具

| 平台 | 工具 | 说明 |
|------|------|------|
| Android | Android SDK | 通过 Android Studio 安装 |
| Android | Java/JDK | Flutter 自带 |
| iOS | Xcode | 仅 macOS 需要 |
| iOS | CocoaPods | `sudo gem install cocoapods` |
| Windows | Visual Studio 2022 | C++ 桌面开发工作负载 |

## 2. 外部服务依赖

### 2.1 无需外部服务

本项目为本地音乐播放器，不需要：
- ❌ 后端 API
- ❌ 云服务
- ❌ 第三方 SDK Key
- ❌ 数据库服务

### 2.2 可选服务

| 服务 | 用途 | 是否必需 |
|------|------|---------|
| GitHub | 代码托管 | 可选 |
| Firebase Analytics | 使用统计 | 可选 |

## 3. 权限配置

### 3.1 Android 权限

需要在 `android/app/src/main/AndroidManifest.xml` 中添加：

```xml
<!-- 读取存储（Android 12 及以下） -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>

<!-- 读取音频文件（Android 13+） -->
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>

<!-- 后台播放服务 -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>

<!-- 保持唤醒 -->
<uses-permission android:name="android.permission.WAKE_LOCK"/>

<!-- 网络（用于加载在线封面） -->
<uses-permission android:name="android.permission.INTERNET"/>
```

### 3.2 iOS 权限

需要在 `ios/Runner/Info.plist` 中添加：

```xml
<!-- 访问音乐库 -->
<key>NSAppleMusicUsageDescription</key>
<string>需要访问您的音乐库以播放本地音乐</string>

<!-- 访问媒体库 -->
<key>NSMediaLibraryUsageDescription</key>
<string>需要访问媒体库以扫描本地音乐</string>
```

### 3.3 Windows 权限

Windows 平台需要：
- 文件系统访问权限（默认已有）
- 音频播放权限（默认已有）

## 4. 环境变量

本项目不需要配置环境变量。

## 5. 配置检查清单

### 5.1 开发环境检查

```bash
# 检查 Flutter
flutter doctor

# 预期输出应包含：
# [✓] Flutter (Channel stable, 3.35+)
# [✓] Android toolchain
# [✓] Chrome (for web development)
# [✓] Android Studio
# [✓] VS Code
```

### 5.2 平台构建检查

```bash
# Android 构建
cd mysic_flutter
flutter build apk --debug

# Windows 构建
flutter build windows --debug

# iOS 构建（仅 macOS）
flutter build ios --debug
```

## 6. 配置步骤

### 步骤 1: 检查 Flutter 环境

```bash
flutter doctor -v
```

确保所有必需项都显示 ✓

### 步骤 2: 安装项目依赖

```bash
cd mysic_flutter
flutter pub get
```

### 步骤 3: 配置平台权限

- [ ] 编辑 AndroidManifest.xml
- [ ] 编辑 Info.plist
- [ ] 确认 Windows 权限

### 步骤 4: 验证构建

```bash
flutter build apk --debug
flutter build windows --debug
```

---

## 依赖确认状态

| 项目 | 状态 |
|------|------|
| Flutter SDK | ⏳ 待确认 |
| Android 工具链 | ⏳ 待确认 |
| Windows 工具链 | ⏳ 待确认 |
| 项目依赖 | ⏳ 待确认 |
| 权限配置 | ⏳ 待确认 |

**下一步**: 请确认以上依赖都已配置完成，然后可以运行 `run.sh` 开始自动执行。
