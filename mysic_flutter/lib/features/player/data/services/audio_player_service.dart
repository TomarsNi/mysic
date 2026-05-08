import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import 'audio_handler.dart';

/// 播放器状态
enum MysicPlayerState {
  idle,
  loading,
  ready,
  playing,
  paused,
  completed,
  error,
}

/// 循环模式
enum MysicLoopMode {
  off,
  all,
}

/// 音频播放服务
/// 使用 just_audio + audio_service 实现音频播放核心功能
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  MysicAudioHandler? _audioHandler;
  MysicPlayerState _state = MysicPlayerState.idle;
  Song? _currentSong;
  List<Song> _playlist = [];
  int _currentIndex = -1;
  bool _isShuffleMode = false;
  MysicLoopMode _loopMode = MysicLoopMode.off;

  // 状态流控制器
  final _stateController = StreamController<MysicPlayerState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _currentSongController = StreamController<Song?>.broadcast();

  // 公开的流
  Stream<MysicPlayerState> get stateStream => _stateController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;
  Stream<Song?> get currentSongStream => _currentSongController.stream;

  // 当前状态
  MysicPlayerState get state => _state;
  Song? get currentSong => _currentSong;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  bool get isPlaying => _state == MysicPlayerState.playing;
  bool get isShuffleMode => _isShuffleMode;
  MysicLoopMode get loopMode => _loopMode;
  List<Song> get playlist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;

  /// 初始化音频播放服务
  Future<void> initialize() async {
    // 初始化 AudioHandler
    _audioHandler = await AudioService.init(
      builder: () => MysicAudioHandler(_player),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.mysic.app.audio',
        androidNotificationChannelName: 'Mysic 播放器',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );

    // 监听播放器状态
    _player.playerStateStream.listen((state) {
      _handlePlayerStateChange(state);
    });

    // 监听播放位置
    _player.positionStream.listen((position) {
      _positionController.add(position);
    });

    // 监听歌曲时长
    _player.durationStream.listen((duration) {
      _durationController.add(duration);
    });

    // 监听播放完成
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _onSongCompleted();
      }
    });
  }

  /// 处理播放器状态变化
  void _handlePlayerStateChange(PlayerState state) {
    switch (state.processingState) {
      case ProcessingState.idle:
        _updateState(MysicPlayerState.idle);
        break;
      case ProcessingState.loading:
      case ProcessingState.buffering:
        _updateState(MysicPlayerState.loading);
        break;
      case ProcessingState.ready:
        _updateState(state.playing ? MysicPlayerState.playing : MysicPlayerState.ready);
        break;
      case ProcessingState.completed:
        _updateState(MysicPlayerState.completed);
        break;
    }
  }

  /// 更新状态
  void _updateState(MysicPlayerState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(_state);
    }
  }

  /// 播放歌曲
  Future<void> playSong(Song song) async {
    try {
      _updateState(MysicPlayerState.loading);
      _currentSong = song;
      _currentSongController.add(_currentSong);

      await _player.setFilePath(song.filePath);
      await _player.play();

      _updateState(MysicPlayerState.playing);
    } on Exception catch (e) {
      _updateState(MysicPlayerState.error);
      debugPrint('播放失败: $e');
      rethrow;
    }
  }

  /// 设置播放列表
  Future<void> setPlaylist(List<Song> songs, {int startIndex = 0, bool autoPlay = false}) async {
    if (songs.isEmpty) return;

    debugPrint('========== AudioPlayerService.setPlaylist 开始 ==========');
    debugPrint('歌曲数量: ${songs.length}, startIndex: $startIndex, autoPlay: $autoPlay');

    _playlist = List.from(songs);
    _currentIndex = startIndex;

    // 同步到 AudioHandler
    await _audioHandler?.setPlaylist(songs, startIndex: startIndex);

    _updateState(MysicPlayerState.loading);

    _currentSong = songs[startIndex];
    _currentSongController.add(_currentSong);

    if (autoPlay) {
      debugPrint('准备播放: ${songs[startIndex].filePath}');
      try {
        await _player.setFilePath(songs[startIndex].filePath);
        await _player.play();
        debugPrint('播放命令已执行');
      } on Exception catch (e) {
        debugPrint('播放错误: $e');
      }
      _updateState(MysicPlayerState.playing);
    } else {
      await _player.setFilePath(songs[startIndex].filePath);
      _updateState(MysicPlayerState.ready);
    }
    debugPrint('========== AudioPlayerService.setPlaylist 完成 ==========');
  }

  /// 播放
  Future<void> play() async {
    await _player.play();
  }

  /// 暂停
  Future<void> pause() async {
    await _player.pause();
  }

  /// 停止
  Future<void> stop() async {
    await _player.stop();
    _currentSong = null;
    _currentIndex = -1;
    _currentSongController.add(null);
    _updateState(MysicPlayerState.idle);
  }

  /// 播放下一首
  Future<void> next() async {
    if (_playlist.isEmpty) return;

    if (_isShuffleMode) {
      final randomIndex = _getRandomIndex();
      _currentIndex = randomIndex;
    } else {
      if (_currentIndex < _playlist.length - 1) {
        _currentIndex++;
      } else if (_loopMode == MysicLoopMode.all) {
        _currentIndex = 0;
      } else {
        return;
      }
    }

    _currentSong = _playlist[_currentIndex];
    _currentSongController.add(_currentSong);
    _updateState(MysicPlayerState.loading);
    await _player.setFilePath(_currentSong!.filePath);
    await _player.play();
    _updateState(MysicPlayerState.playing);
  }

  /// 播放上一首
  Future<void> previous() async {
    if (_playlist.isEmpty) return;

    if (_currentIndex > 0) {
      _currentIndex--;
    } else if (_loopMode == MysicLoopMode.all) {
      _currentIndex = _playlist.length - 1;
    } else {
      await _player.seek(Duration.zero);
      return;
    }

    _currentSong = _playlist[_currentIndex];
    _currentSongController.add(_currentSong);
    _updateState(MysicPlayerState.loading);
    await _player.setFilePath(_currentSong!.filePath);
    await _player.play();
    _updateState(MysicPlayerState.playing);
  }

  /// 跳转到指定位置
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// 跳转到指定歌曲
  Future<void> seekToIndex(int index) async {
    if (index < 0 || index >= _playlist.length) return;

    _currentIndex = index;
    _currentSong = _playlist[_currentIndex];
    _currentSongController.add(_currentSong);
    _updateState(MysicPlayerState.loading);
    await _player.setFilePath(_currentSong!.filePath);
    await _player.play();
    _updateState(MysicPlayerState.playing);
  }

  /// 设置播放速度
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  /// 切换随机模式
  Future<void> toggleShuffleMode() async {
    _isShuffleMode = !_isShuffleMode;
  }

  /// 设置循环模式
  Future<void> setLoopMode(MysicLoopMode mode) async {
    _loopMode = mode;
    _audioHandler?.setLoopMode(mode == MysicLoopMode.all);
  }

  /// 切换循环模式
  Future<void> toggleLoopMode() async {
    switch (_loopMode) {
      case MysicLoopMode.off:
        await setLoopMode(MysicLoopMode.all);
        break;
      case MysicLoopMode.all:
        await setLoopMode(MysicLoopMode.off);
        break;
    }
  }

  /// 歌曲播放完成回调
  void _onSongCompleted() {
    if (_currentIndex < _playlist.length - 1 || _loopMode == MysicLoopMode.all) {
      next();
    } else {
      _updateState(MysicPlayerState.completed);
    }
  }

  /// 获取随机索引
  int _getRandomIndex() {
    if (_playlist.length <= 1) return 0;

    int randomIndex;
    do {
      randomIndex = DateTime.now().millisecondsSinceEpoch % _playlist.length;
    } while (randomIndex == _currentIndex);

    return randomIndex;
  }

  /// 更新播放列表中的歌曲信息
  void updateSongInPlaylist(Song updatedSong) {
    final index = _playlist.indexWhere((s) => s.id == updatedSong.id);
    if (index != -1) {
      _playlist[index] = updatedSong;
    }
    if (_currentSong?.id == updatedSong.id) {
      _currentSong = updatedSong;
      _currentSongController.add(_currentSong);
    }
  }

  /// 从播放列表移除歌曲
  Future<bool> removeFromPlaylist(int index) async {
    if (index < 0 || index >= _playlist.length) return false;

    final wasPlayingCurrent = index == _currentIndex;
    final wasPlaying = _state == MysicPlayerState.playing;
    _playlist.removeAt(index);

    if (index < _currentIndex) {
      _currentIndex--;
    } else if (wasPlayingCurrent) {
      if (_playlist.isNotEmpty) {
        if (_currentIndex >= _playlist.length) {
          _currentIndex = _playlist.length - 1;
        }
        _currentSong = _playlist[_currentIndex];
        _currentSongController.add(_currentSong);

        if (wasPlaying) {
          _updateState(MysicPlayerState.loading);
          await _player.setFilePath(_currentSong!.filePath);
          await _player.play();
        } else {
          await _player.setFilePath(_currentSong!.filePath);
          _updateState(MysicPlayerState.ready);
        }
      } else {
        _currentIndex = -1;
        _currentSong = null;
        _currentSongController.add(null);
        await _player.stop();
        _updateState(MysicPlayerState.idle);
      }
    }

    return _playlist.isEmpty;
  }

  /// 释放资源
  Future<void> dispose() async {
    await _player.dispose();
    await _stateController.close();
    await _positionController.close();
    await _durationController.close();
    await _currentSongController.close();
  }
}
