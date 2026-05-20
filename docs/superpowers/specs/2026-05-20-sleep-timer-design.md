# 睡眠倒计时功能设计

## 概述

为 Mysic 音乐播放器添加睡眠倒计时功能，支持两种模式：
- **时间模式**：设置倒计时分钟数，到时间后暂停播放
- **歌曲数模式**：设置播放歌曲数，播完后暂停播放

## 功能需求

### 核心功能
1. 用户可选择按时间或按歌曲数设置倒计时
2. 倒计时结束后自动暂停播放，并显示 SnackBar 提示
3. 倒计时进行中可随时修改或取消
4. 倒计时结束后自动清除状态

### 交互设计

#### 入口
- 主页播放控制区域左侧新增倒计时按钮
- 与右侧歌单队列按钮对称布局

#### 按钮状态
- **未激活**：显示时钟图标，默认颜色
- **激活中**：显示剩余值（时间格式 `mm:ss` 或 `N首`），accent 背景色

#### 设置面板（底部 Sheet）
- 两个选项卡切换：时间 / 歌曲数
- 时间选项卡：5、10、15、30、60 分钟快捷按钮 + 自定义输入
- 歌曲数选项卡：1、3、5、10 首快捷按钮 + 自定义输入
- 倒计时进行中：显示当前状态和取消按钮
- 修改设置时直接替换旧倒计时

## 技术设计

### 文件结构

```
lib/features/player/
├── data/
│   └── services/
│       └── sleep_timer_service.dart    # 倒计时逻辑服务
├── presentation/
│   ├── providers/
│   │   └── sleep_timer_provider.dart   # 倒计时状态管理
│   └── widgets/
│       ├── sleep_timer_button.dart     # 主页左侧按钮
│       └── sleep_timer_sheet.dart      # 底部设置面板
```

### 数据模型

```dart
/// 倒计时模式
enum SleepTimerMode {
  time,       // 按时间
  songCount,  // 按歌曲数
}

/// 倒计时状态
class SleepTimerState {
  final SleepTimerMode mode;
  final int targetValue;       // 目标值：时间(分钟) 或 歌曲数
  final int remainingValue;    // 剩余值：时间(秒) 或 歌曲数
  final bool isActive;
  final DateTime? startTime;   // 开始时间（时间模式）
  final int? startSongIndex;   // 开始时的歌曲索引（歌曲数模式）
}
```

### SleepTimerService

负责倒计时核心逻辑：

**时间模式实现：**
```dart
class SleepTimerService {
  Timer? _timer;

  void startTimeTimer(int minutes, VoidCallback onComplete) {
    final targetSeconds = minutes * 60;
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      final elapsed = DateTime.now().difference(startTime).inSeconds;
      final remaining = targetSeconds - elapsed;
      if (remaining <= 0) {
        timer.cancel();
        onComplete();
      }
      // 更新状态
    });
  }
}
```

**歌曲数模式实现：**
```dart
void startSongCountTimer(int songCount, int currentSongIndex, VoidCallback onComplete) {
  startSongIndex = currentSongIndex;
  targetSongCount = songCount;
  // 监听 currentIndex 变化，在 Provider 中处理
}
```

### SleepTimerProvider

继承 `ChangeNotifier`，管理倒计时状态：

```dart
class SleepTimerProvider extends ChangeNotifier {
  SleepTimerState _state = SleepTimerState.inactive();

  // 监听 PlayerProvider 的 currentIndex 变化
  void onSongChanged(int newIndex) {
    if (_state.mode == SleepTimerMode.songCount && _state.isActive) {
      final played = newIndex - _state.startSongIndex!;
      final remaining = _state.targetValue - played;
      if (remaining <= 0) {
        _complete();
      } else {
        _state = _state.copyWith(remainingValue: remaining);
        notifyListeners();
      }
    }
  }

  void startTimer(SleepTimerMode mode, int value) { ... }
  void cancelTimer() { ... }
}
```

### UI 组件

#### SleepTimerButton

```dart
class SleepTimerButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SleepTimerProvider>(
      builder: (context, provider, _) {
        final state = provider.state;
        return GestureDetector(
          onTap: () => _showSleepTimerSheet(context),
          child: Container(
            // 圆形按钮，激活时 accent 背景
            child: state.isActive
              ? Text(_formatRemaining(state))  // "23:45" 或 "3首"
              : Icon(Icons.timer_outlined),
          ),
        );
      },
    );
  }
}
```

#### SleepTimerSheet

```dart
class SleepTimerSheet extends StatefulWidget {
  // 底部面板，圆角顶部
  // TabBar: 时间 | 歌曲数
  // 快捷选项网格 + 自定义输入
}
```

### 集成点

**main.dart 修改：**

1. 在 `MultiProvider` 中注册 `SleepTimerProvider`
2. 在播放控制区域 `Stack` 中添加左侧按钮
3. 在 `PlayerProvider` 歌曲变化时通知 `SleepTimerProvider`

```dart
// MultiProvider
MultiProvider(
  providers: [
    // ... 现有 providers
    ChangeNotifierProvider(create: (_) => SleepTimerProvider()),
  ],
)

// 播放控制区域
Stack(
  children: [
    PlayControls(...),
    Positioned(right: 0, child: _PlaylistQueueButton(...)),
    Positioned(left: 0, child: SleepTimerButton(...)),  // 新增
  ],
)
```

**PlayerProvider 修改：**

在 `_currentSongController` 监听中添加对 `SleepTimerProvider` 的通知：

```dart
_audioPlayerService.currentSongStream.listen((song) {
  // ... 现有逻辑

  // 通知 SleepTimerProvider 歌曲变化
  final sleepTimerProvider = context.read<SleepTimerProvider>();
  sleepTimerProvider.onSongChanged(_currentIndex);
});
```

## 用户流程

### 设置倒计时
1. 用户点击左侧倒计时按钮
2. 底部弹出设置面板，默认显示"时间"选项卡
3. 用户选择预设值或输入自定义值
4. 倒计时开始，按钮显示剩余值

### 修改/取消倒计时
1. 用户再次点击按钮
2. 面板显示当前状态和取消按钮
3. 用户可选择新值（直接替换）或点击取消

### 倒计时结束
1. 播放暂停
2. 显示 SnackBar："睡眠倒计时已结束"
3. 按钮恢复未激活状态

## 设计规范参考

遵循 `index.html` 设计稿：
- 颜色：`#18181b`(surface)、`#27272a`(card)、`#10b981`(accent)、`#71717a`(muted)
- 底部面板：圆角顶部 `rounded-t-3xl`，拖拽指示条
- 按钮：圆形，hover 时 `bg-white/10`
- 过渡动画：150-300ms，`cubic-bezier(0.4, 0, 0.2, 1)`
