import 'dart:async';

import 'package:flutter/foundation.dart';

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

  const SleepTimerState({
    required this.mode,
    required this.targetValue,
    required this.remainingValue,
    required this.isActive,
    this.startTime,
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
    bool clearStartTime = false,
  }) {
    return SleepTimerState(
      mode: mode ?? this.mode,
      targetValue: targetValue ?? this.targetValue,
      remainingValue: remainingValue ?? this.remainingValue,
      isActive: isActive ?? this.isActive,
      startTime: clearStartTime ? null : (startTime ?? this.startTime),
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
      final startTime = _state.startTime;
      if (startTime == null) {
        _cancelTimer();
        return;
      }
      final elapsed = DateTime.now().difference(startTime).inSeconds;
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
  void startSongCountTimer(int songCount) {
    _cancelTimer();

    _state = SleepTimerState(
      mode: SleepTimerMode.songCount,
      targetValue: songCount,
      remainingValue: songCount,
      isActive: true,
    );
    onStateChanged?.call();
  }

  /// 歌曲播放完成时递减倒计时
  void onSongCompleted() {
    if (!_state.isActive || _state.mode != SleepTimerMode.songCount) {
      return;
    }

    final remaining = _state.remainingValue - 1;

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
