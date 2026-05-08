# Android 后台播放自动切歌修复设计

## 问题描述

Android 版本后台播放时，一首歌播放完成后无法自动播放下一首。

### 问题表现
- 前台播放：自动切歌正常
- 后台播放（Home 键）：无法自动切歌
- 锁屏播放：无法自动切歌
- 与循环模式无关
- 播放列表有多首歌曲时出现

### 根本原因

`audioplayers` 包在 Android 后台时，`onPlayerComplete` 事件无法可靠触发，或播放器无法自动开始下一首。

---

## 解决方案

切换到 `just_audio` + `audio_service`，这是 Flutter 后台媒体播放的标准方案。

### 方案优势
- 官方推荐的后台播放方案
- 完整支持后台播放、通知栏控制、锁屏控制
- 多端通用：Android、iOS、Windows
- 活跃维护，社区支持好

---

## 技术设计

### 1. 依赖变更

**pubspec.yaml**

```yaml
dependencies:
  # 移除
  # audioplayers: ^6.0.0

  # 添加
  just_audio: ^0.9.40
  audio_service: ^0.18.15

  # 保留
  audio_session: ^0.1.21
```

### 2. 文件结构

```
lib/features/player/data/
├── models/
│   └── song.dart                    # 保持不变
├── services/
│   ├── audio_player_service.dart    # 重写，使用 just_audio
│   └── audio_handler.dart           # 新增，实现 AudioHandler
```

### 3. AudioHandler 实现

新增 `audio_handler.dart`，实现后台播放回调：

```dart
class MysicAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player;

  // 实现：
  // - 播放列表管理
  // - 通知栏媒体控制
  // - 蓝牙/耳机控制事件
  // - 播放完成自动切歌
}
```

### 4. AudioPlayerService 重写

保持现有 API 接口不变：

- `initialize()` - 初始化播放器和 AudioHandler
- `playSong(Song)` - 播放单曲
- `setPlaylist(List<Song>, startIndex, autoPlay)` - 设置播放列表
- `play()` / `pause()` / `stop()` - 播放控制
- `next()` / `previous()` - 切歌
- `seek(Duration)` - 跳转
- `seekToIndex(int)` - 跳转到指定歌曲
- `setSpeed(double)` - 播放速度
- `toggleShuffleMode()` - 随机模式
- `setLoopMode(MysicLoopMode)` - 循环模式

### 5. PlayerProvider

无需修改，保持现有接口调用。

### 6. 平台配置

**Android：** 现有权限已足够
```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

**iOS：** 需确认 `Info.plist` 包含后台音频模式

**Windows：** `just_audio_windows` 自动处理

---

## 实现步骤

1. 更新 `pubspec.yaml` 依赖
2. 创建 `AudioHandler` 实现
3. 重写 `AudioPlayerService`
4. 更新 `main.dart` 初始化
5. 测试三平台后台播放

---

## 风险评估

- **低风险**：API 接口保持不变，上层代码无需修改
- **兼容性**：`just_audio` 支持 Android 5.0+、iOS 12.0+、Windows 10+

---

## 验收标准

- [ ] Android 后台播放自动切歌正常
- [ ] Android 锁屏播放自动切歌正常
- [ ] 通知栏媒体控制正常
- [ ] iOS 后台播放正常
- [ ] Windows 播放正常
- [ ] 现有功能不受影响（播放、暂停、切歌、循环、随机）
