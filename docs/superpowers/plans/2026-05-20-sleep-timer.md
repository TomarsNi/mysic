# 睡眠倒计时功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 Mysic 音乐播放器添加睡眠倒计时功能，支持按时间或按歌曲数自动暂停播放。

**Architecture:** 使用独立的 `SleepTimerProvider` 管理倒计时状态，通过 `Timer.periodic` 实现时间倒计时，通过监听 `PlayerProvider.currentIndex` 实现歌曲数倒计时。UI 采用底部面板（BottomSheet）提供设置界面。

**Tech Stack:** Flutter, Dart, Provider (ChangeNotifier), Timer

---

## 文件结构

```
lib/features/player/
├── data/
│   └── services/
│       └── sleep_timer_service.dart    # 新建：倒计时逻辑服务
├── presentation/
│   ├── providers/
│   │   └── sleep_timer_provider.dart   # 新建：倒计时状态管理
│   └── widgets/
│       ├── sleep_timer_button.dart     # 新建：主页左侧按钮
│       └── sleep_timer_sheet.dart      # 新建：底部设置面板

test/
└── features/player/
    └── presentation/
        └── providers/
            └── sleep_timer_provider_test.dart  # 新建：单元测试
```

---

### Task 1: 创建 SleepTimerService

**Files:**
- Create: `mysic_flutter/lib/features/player/data/services/sleep_timer_service.dart`

- [ ] **Step 1: 创建 SleepTimerService 文件**

```dart
import 'dart:async';

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

  const SleepTimerState({
    required this.mode,
    required this.targetValue,
    required this.remainingValue,
    required this.isActive,
    this.startTime,
    this.startSongIndex,
  });

  /// 创建未激活状态
  factory SleepTimerState.inactive() {
    return const SleepTimerState(
      mode: SleepTimerMode.time,
      targetValue: 0,
      remainingValue: 0,
      isActive: false,
    );
  }

  /// 复制并修改
  SleepTimerState copyWith({
    SleepTimerMode? mode,
    int? targetValue,
    int? remainingValue,
    bool? isActive,
    DateTime? startTime,
    int? startSongIndex,
    bool clearStartTime = false,
    bool clearStartSongIndex = false,
  }) {
    return SleepTimerState(
      mode: mode ?? this.mode,
      targetValue: targetValue ?? this.targetValue,
      remainingValue: remainingValue ?? this.remainingValue,
      isActive: isActive ?? this.isActive,
      startTime: clearStartTime ? null : (startTime ?? this.startTime),
      startSongIndex: clearStartSongIndex ? null : (startSongIndex ?? this.startSongIndex),
    );
  }
}

/// 倒计时服务
/// 负责管理倒计时逻辑
class SleepTimerService {
  Timer? _timer;
  SleepTimerState _state = SleepTimerState.inactive();

  /// 当前状态
  SleepTimerState get state => _state;

  /// 状态变化回调
  VoidCallback? onStateChanged;

  /// 倒计时完成回调
  VoidCallback? onComplete;

  /// 启动时间倒计时
  void startTimeTimer(int minutes) {
    _cancelTimer();

    final now = DateTime.now();
    final targetSeconds = minutes * 60;

    _state = SleepTimerState(
      mode: SleepTimerMode.time,
      targetValue: minutes,
      remainingValue: targetSeconds,
      isActive: true,
      startTime: now,
    );
    onStateChanged?.call();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final elapsed = DateTime.now().difference(_state.startTime!).inSeconds;
      final remaining = targetSeconds - elapsed;

      if (remaining <= 0) {
        _complete();
      } else {
        _state = _state.copyWith(remainingValue: remaining);
        onStateChanged?.call();
      }
    });
  }

  /// 启动歌曲数倒计时
  void startSongCountTimer(int songCount, int currentSongIndex) {
    _cancelTimer();

    _state = SleepTimerState(
      mode: SleepTimerMode.songCount,
      targetValue: songCount,
      remainingValue: songCount,
      isActive: true,
      startSongIndex: currentSongIndex,
    );
    onStateChanged?.call();
  }

  /// 更新歌曲数倒计时（当歌曲变化时调用）
  void updateSongCount(int currentSongIndex) {
    if (!_state.isActive || _state.mode != SleepTimerMode.songCount) {
      return;
    }

    final played = currentSongIndex - _state.startSongIndex!;
    final remaining = _state.targetValue - played;

    if (remaining <= 0) {
      _complete();
    } else {
      _state = _state.copyWith(remainingValue: remaining);
      onStateChanged?.call();
    }
  }

  /// 取消倒计时
  void cancel() {
    _cancelTimer();
    _state = SleepTimerState.inactive();
    onStateChanged?.call();
  }

  /// 完成倒计时
  void _complete() {
    _cancelTimer();
    _state = SleepTimerState.inactive();
    onStateChanged?.call();
    onComplete?.call();
  }

  /// 取消定时器
  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// 释放资源
  void dispose() {
    _cancelTimer();
  }
}
```

- [ ] **Step 2: 验证文件创建成功**

Run: `cd mysic_flutter && flutter analyze lib/features/player/data/services/sleep_timer_service.dart`
Expected: No issues found

- [ ] **Step 3: 提交**

```bash
cd mysic_flutter
git add lib/features/player/data/services/sleep_timer_service.dart
git commit -m "feat(player): 添加 SleepTimerService 倒计时服务"
```

---

### Task 2: 创建 SleepTimerProvider

**Files:**
- Create: `mysic_flutter/lib/features/player/presentation/providers/sleep_timer_provider.dart`
- Create: `mysic_flutter/test/features/player/presentation/providers/sleep_timer_provider_test.dart`

- [ ] **Step 1: 创建测试文件**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/features/player/presentation/providers/sleep_timer_provider.dart';
import 'package:mysic_flutter/features/player/data/services/sleep_timer_service.dart';

void main() {
  group('SleepTimerProvider', () {
    test('initial state is inactive', () {
      final provider = SleepTimerProvider();
      expect(provider.state.isActive, isFalse);
    });

    test('startTimeTimer sets active state', () {
      final provider = SleepTimerProvider();
      provider.startTimeTimer(5);
      expect(provider.state.isActive, isTrue);
      expect(provider.state.mode, SleepTimerMode.time);
      expect(provider.state.targetValue, 5);
    });

    test('startSongCountTimer sets active state', () {
      final provider = SleepTimerProvider();
      provider.startSongCountTimer(3, 0);
      expect(provider.state.isActive, isTrue);
      expect(provider.state.mode, SleepTimerMode.songCount);
      expect(provider.state.targetValue, 3);
    });

    test('cancel resets state to inactive', () {
      final provider = SleepTimerProvider();
      provider.startTimeTimer(5);
      expect(provider.state.isActive, isTrue);

      provider.cancel();
      expect(provider.state.isActive, isFalse);
    });

    test('onSongChanged updates remaining count in song mode', () {
      final provider = SleepTimerProvider();
      provider.startSongCountTimer(3, 0);
      expect(provider.state.remainingValue, 3);

      provider.onSongChanged(1);
      expect(provider.state.remainingValue, 2);

      provider.onSongChanged(2);
      expect(provider.state.remainingValue, 1);
    });

    test('onSongChanged does nothing in time mode', () {
      final provider = SleepTimerProvider();
      provider.startTimeTimer(5);

      provider.onSongChanged(1);
      expect(provider.state.mode, SleepTimerMode.time);
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd mysic_flutter && flutter test test/features/player/presentation/providers/sleep_timer_provider_test.dart`
Expected: FAIL - SleepTimerProvider not found

- [ ] **Step 3: 创建 SleepTimerProvider**

```dart
import 'package:flutter/foundation.dart';
import '../../data/services/sleep_timer_service.dart';

/// 睡眠倒计时状态管理
class SleepTimerProvider extends ChangeNotifier {
  final SleepTimerService _service;
  bool _isCompleting = false;

  SleepTimerProvider({SleepTimerService? service})
      : _service = service ?? SleepTimerService() {
    _service.onStateChanged = _onStateChanged;
  }

  /// 当前状态
  SleepTimerState get state => _service.state;

  /// 状态变化回调
  void _onStateChanged() {
    notifyListeners();
  }

  /// 启动时间倒计时
  void startTimeTimer(int minutes) {
    _service.startTimeTimer(minutes);
    notifyListeners();
  }

  /// 启动歌曲数倒计时
  void startSongCountTimer(int songCount, int currentSongIndex) {
    _service.startSongCountTimer(songCount, currentSongIndex);
    notifyListeners();
  }

  /// 歌曲变化时调用
  void onSongChanged(int newIndex) {
    _service.updateSongCount(newIndex);
  }

  /// 取消倒计时
  void cancel() {
    _service.cancel();
    notifyListeners();
  }

  /// 设置完成回调（用于暂停播放）
  void setOnComplete(VoidCallback onComplete) {
    _service.onComplete = onComplete;
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `cd mysic_flutter && flutter test test/features/player/presentation/providers/sleep_timer_provider_test.dart`
Expected: All tests pass

- [ ] **Step 5: 提交**

```bash
cd mysic_flutter
git add lib/features/player/presentation/providers/sleep_timer_provider.dart
git add test/features/player/presentation/providers/sleep_timer_provider_test.dart
git commit -m "feat(player): 添加 SleepTimerProvider 状态管理"
```

---

### Task 3: 创建 SleepTimerButton 组件

**Files:**
- Create: `mysic_flutter/lib/features/player/presentation/widgets/sleep_timer_button.dart`

- [ ] **Step 1: 创建 SleepTimerButton**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/sleep_timer_provider.dart';
import '../../data/services/sleep_timer_service.dart';
import 'sleep_timer_sheet.dart';

/// 睡眠倒计时按钮
/// 显示在播放控制区域左侧
class SleepTimerButton extends StatefulWidget {
  const SleepTimerButton({super.key});

  @override
  State<SleepTimerButton> createState() => _SleepTimerButtonState();
}

class _SleepTimerButtonState extends State<SleepTimerButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<SleepTimerProvider>(
      builder: (context, provider, _) {
        final state = provider.state;
        final isActive = state.isActive;

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: GestureDetector(
            onTap: () => _showSleepTimerSheet(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? AppColors.accent
                    : (_isHovering ? Colors.white.withValues(alpha: 0.1) : Colors.transparent),
              ),
              child: Center(
                child: isActive
                    ? _buildActiveContent(state)
                    : Icon(
                        Icons.timer_outlined,
                        size: 24,
                        color: AppColors.muted,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建激活状态内容
  Widget _buildActiveContent(SleepTimerState state) {
    final text = state.mode == SleepTimerMode.time
        ? _formatTime(state.remainingValue)
        : '${state.remainingValue}首';

    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }

  /// 格式化时间（秒转为 mm:ss）
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  /// 显示设置面板
  void _showSleepTimerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const SleepTimerSheet(),
    );
  }
}
```

- [ ] **Step 2: 验证文件创建成功**

Run: `cd mysic_flutter && flutter analyze lib/features/player/presentation/widgets/sleep_timer_button.dart`
Expected: No issues found (可能有 sleep_timer_sheet.dart 不存在的警告，下一步会解决)

- [ ] **Step 3: 提交**

```bash
cd mysic_flutter
git add lib/features/player/presentation/widgets/sleep_timer_button.dart
git commit -m "feat(player): 添加 SleepTimerButton 按钮组件"
```

---

### Task 4: 创建 SleepTimerSheet 底部面板

**Files:**
- Create: `mysic_flutter/lib/features/player/presentation/widgets/sleep_timer_sheet.dart`

- [ ] **Step 1: 创建 SleepTimerSheet**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/sleep_timer_provider.dart';
import '../../data/services/sleep_timer_service.dart';

/// 睡眠倒计时设置面板
class SleepTimerSheet extends StatefulWidget {
  const SleepTimerSheet({super.key});

  @override
  State<SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends State<SleepTimerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _customController = TextEditingController();

  /// 时间预设选项（分钟）
  static const List<int> _timePresets = [5, 10, 15, 30, 60];

  /// 歌曲数预设选项
  static const List<int> _songCountPresets = [1, 3, 5, 10];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SleepTimerProvider>(
      builder: (context, provider, _) {
        final state = provider.state;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              // 拖动指示器
              _buildDragHandle(),
              const SizedBox(height: 20),
              // 标题
              _buildHeader(state),
              const SizedBox(height: 16),
              // 选项卡
              _buildTabBar(),
              const SizedBox(height: 16),
              // 内容区域
              SizedBox(
                height: 200,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTimeTab(provider),
                    _buildSongCountTab(provider),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 当前状态和取消按钮
              if (state.isActive) _buildActiveState(provider, state),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  /// 拖动指示器
  Widget _buildDragHandle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  /// 标题
  Widget _buildHeader(SleepTimerState state) {
    return Row(
      children: [
        Icon(
          Icons.timer_outlined,
          color: state.isActive ? AppColors.accent : AppColors.muted,
        ),
        const SizedBox(width: 12),
        Text(
          '睡眠倒计时',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
      ],
    );
  }

  /// 选项卡栏
  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppColors.white,
        unselectedLabelColor: AppColors.muted,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: '按时间'),
          Tab(text: '按歌曲数'),
        ],
      ),
    );
  }

  /// 时间选项卡
  Widget _buildTimeTab(SleepTimerProvider provider) {
    return Column(
      children: [
        // 预设按钮
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _timePresets.map((minutes) {
            return _buildPresetButton(
              label: '$minutes 分钟',
              onTap: () => _setTimeTimer(provider, minutes),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        // 自定义输入
        _buildCustomInput(
          hint: '自定义分钟数',
          onSubmitted: (value) {
            final minutes = int.tryParse(value);
            if (minutes != null && minutes > 0) {
              _setTimeTimer(provider, minutes);
            }
          },
        ),
      ],
    );
  }

  /// 歌曲数选项卡
  Widget _buildSongCountTab(SleepTimerProvider provider) {
    // 获取当前歌曲索引
    final playerProvider = context.read<dynamic>();
    final currentIndex = playerProvider.currentIndex as int? ?? 0;

    return Column(
      children: [
        // 预设按钮
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _songCountPresets.map((count) {
            return _buildPresetButton(
              label: '$count 首',
              onTap: () => _setSongCountTimer(provider, count, currentIndex),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        // 自定义输入
        _buildCustomInput(
          hint: '自定义歌曲数',
          onSubmitted: (value) {
            final count = int.tryParse(value);
            if (count != null && count > 0) {
              _setSongCountTimer(provider, count, currentIndex);
            }
          },
        ),
      ],
    );
  }

  /// 预设按钮
  Widget _buildPresetButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.card),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.white,
            ),
          ),
        ),
      ),
    );
  }

  /// 自定义输入框
  Widget _buildCustomInput({
    required String hint,
    required void Function(String) onSubmitted,
  }) {
    return TextField(
      controller: _customController,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onSubmitted: onSubmitted,
      style: const TextStyle(color: AppColors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.muted),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  /// 激活状态显示
  Widget _buildActiveState(SleepTimerProvider provider, SleepTimerState state) {
    final modeText = state.mode == SleepTimerMode.time ? '时间' : '歌曲数';
    final valueText = state.mode == SleepTimerMode.time
        ? _formatTime(state.remainingValue)
        : '${state.remainingValue} 首';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.timer_outlined,
            color: AppColors.accent,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前：$modeText模式',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
                Text(
                  '剩余 $valueText',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
          // 取消按钮
          TextButton(
            onPressed: () {
              provider.cancel();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
            ),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  /// 设置时间倒计时
  void _setTimeTimer(SleepTimerProvider provider, int minutes) {
    provider.startTimeTimer(minutes);
    Navigator.pop(context);
    _showSnackBar('已设置 $minutes 分钟后暂停');
  }

  /// 设置歌曲数倒计时
  void _setSongCountTimer(SleepTimerProvider provider, int count, int currentIndex) {
    provider.startSongCountTimer(count, currentIndex);
    Navigator.pop(context);
    _showSnackBar('已设置 $count 首后暂停');
  }

  /// 显示提示
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.accent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 格式化时间
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}
```

- [ ] **Step 2: 验证文件创建成功**

Run: `cd mysic_flutter && flutter analyze lib/features/player/presentation/widgets/sleep_timer_sheet.dart`
Expected: No issues found

- [ ] **Step 3: 提交**

```bash
cd mysic_flutter
git add lib/features/player/presentation/widgets/sleep_timer_sheet.dart
git commit -m "feat(player): 添加 SleepTimerSheet 设置面板"
```

---

### Task 5: 集成到 main.dart

**Files:**
- Modify: `mysic_flutter/lib/main.dart`

- [ ] **Step 1: 添加 SleepTimerProvider 导入和注册**

在 `main.dart` 文件顶部添加导入：

```dart
import 'features/player/presentation/providers/sleep_timer_provider.dart';
import 'features/player/presentation/widgets/sleep_timer_button.dart';
```

找到 `MultiProvider` 部分（约第82-89行），添加 `SleepTimerProvider`：

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => PlayerProvider()),
    ChangeNotifierProvider(create: (_) => PlaylistProvider()),
    ChangeNotifierProvider(create: (_) => ApiConfigProvider()..load()),
    ChangeNotifierProvider(create: (_) => AiSkillsProvider()),
    ChangeNotifierProvider(create: (_) => ScanOptionsProvider()..load()),
    ChangeNotifierProvider(create: (_) => SleepTimerProvider()),  // 新增
  ],
  // ...
)
```

- [ ] **Step 2: 在播放控制区域添加 SleepTimerButton**

找到播放控制区域的 `Stack` 组件（约第414-435行），添加左侧按钮：

```dart
Stack(
  alignment: Alignment.center,
  children: [
    // 播放控制 - 水平居中
    PlayControls(
      isPlaying: isPlaying,
      isLoading: isLoading,
      hasPlaylist: hasPlaylist,
      onPlayPause: () => playerProvider.togglePlayPause(),
      onNext: () => playerProvider.next(),
      onPrevious: () => playerProvider.previous(),
    ),

    // 歌单按钮 - 固定右侧
    if (hasPlaylist)
      Positioned(
        right: 0,
        child: _PlaylistQueueButton(
          onTap: () => _showPlaylistQueue(context),
        ),
      ),

    // 睡眠倒计时按钮 - 固定左侧（新增）
    Positioned(
      left: 0,
      child: SleepTimerButton(),
    ),
  ],
)
```

- [ ] **Step 3: 设置倒计时完成回调**

在 `_HomePageState` 的 `initState` 方法中，添加倒计时完成回调设置。找到 `WidgetsBinding.instance.addPostFrameCallback` 回调内部，在 `_restoreLastPlaylist()` 之后添加：

```dart
WidgetsBinding.instance.addPostFrameCallback((_) async {
  await _loadPlaylists();
  await _restoreLastPlaylist();

  // 设置睡眠倒计时完成回调
  final sleepTimerProvider = context.read<SleepTimerProvider>();
  sleepTimerProvider.setOnComplete(() {
    final playerProvider = context.read<PlayerProvider>();
    playerProvider.pause();

    // 显示提示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('睡眠倒计时已结束'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 3),
        ),
      );
    }
  });
});
```

- [ ] **Step 4: 在歌曲变化时通知 SleepTimerProvider**

找到 `PlayerProvider` 的 `_init` 方法中监听 `currentSongStream` 的部分（约第87-100行）。由于 `PlayerProvider` 无法直接访问 `SleepTimerProvider`，我们需要在 `main.dart` 中添加监听。

在 `_HomePageState` 的 `build` 方法中，使用 `Consumer` 监听 `PlayerProvider.currentIndex` 变化。但更好的方式是在 `PlayerProvider` 中添加一个回调。

修改 `PlayerProvider`，添加歌曲变化回调：

在 `player_provider.dart` 中添加：

```dart
/// 歌曲变化回调（用于通知 SleepTimerProvider）
VoidCallback? onSongChanged;

// 在 _init 方法的 currentSongStream 监听中，添加：
_audioPlayerService.currentSongStream.listen((song) {
  // ... 现有逻辑
  onSongChanged?.call();
});
```

然后在 `main.dart` 的 `_HomePageState.initState` 中设置：

```dart
WidgetsBinding.instance.addPostFrameCallback((_) async {
  await _loadPlaylists();
  await _restoreLastPlaylist();

  final playerProvider = context.read<PlayerProvider>();
  final sleepTimerProvider = context.read<SleepTimerProvider>();

  // 设置歌曲变化通知
  playerProvider.onSongChanged = () {
    sleepTimerProvider.onSongChanged(playerProvider.currentIndex);
  };

  // 设置倒计时完成回调
  sleepTimerProvider.setOnComplete(() {
    playerProvider.pause();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('睡眠倒计时已结束'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 3),
        ),
      );
    }
  });
});
```

- [ ] **Step 5: 验证编译通过**

Run: `cd mysic_flutter && flutter analyze`
Expected: No issues found

- [ ] **Step 6: 提交**

```bash
cd mysic_flutter
git add lib/main.dart lib/features/player/presentation/providers/player_provider.dart
git commit -m "feat(player): 集成睡眠倒计时功能到主页"
```

---

### Task 6: 运行测试和验证

**Files:**
- 无新文件

- [ ] **Step 1: 运行所有测试**

Run: `cd mysic_flutter && flutter test`
Expected: All tests pass

- [ ] **Step 2: 运行应用验证功能**

Run: `cd mysic_flutter && flutter run -d windows`
Expected: 应用启动，播放控制区域左侧显示倒计时按钮

手动验证：
1. 点击倒计时按钮，底部面板弹出
2. 选择时间预设（如 5 分钟），面板关闭，按钮显示剩余时间
3. 再次点击按钮，面板显示当前状态
4. 点击取消，倒计时清除
5. 测试歌曲数模式

- [ ] **Step 3: 最终提交**

```bash
cd mysic_flutter
git add -A
git commit -m "feat(player): 完成睡眠倒计时功能"
```

---

## 验收标准

1. 主页播放控制区域左侧显示倒计时按钮
2. 点击按钮弹出底部设置面板，包含时间和歌曲数两个选项卡
3. 时间选项卡提供 5、10、15、30、60 分钟预设和自定义输入
4. 歌曲数选项卡提供 1、3、5、10 首预设和自定义输入
5. 设置倒计时后，按钮显示剩余时间或剩余歌曲数
6. 倒计时结束后自动暂停播放并显示 SnackBar 提示
7. 倒计时进行中可随时修改或取消
