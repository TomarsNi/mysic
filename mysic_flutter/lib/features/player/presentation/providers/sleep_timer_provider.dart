import 'package:flutter/foundation.dart';

import '../../data/services/sleep_timer_service.dart';

/// 睡眠倒计时状态管理
class SleepTimerProvider extends ChangeNotifier {
  final SleepTimerService _service;

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
  }

  /// 启动歌曲数倒计时
  void startSongCountTimer(int songCount) {
    _service.startSongCountTimer(songCount);
  }

  /// 歌曲播放完成时调用（递减倒计时）
  void onSongCompleted() {
    _service.onSongCompleted();
  }

  /// 取消倒计时
  void cancel() {
    _service.cancel();
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
