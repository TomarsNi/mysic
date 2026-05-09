import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/song.dart';

// 条件导入：移动端使用 just_audio，Windows 使用 audioplayers
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart' as audioplayers;
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
/// 使用混合方案：
/// - Android/iOS: just_audio + audio_service（后台播放支持）
/// - Windows: audioplayers（原生支持）
class AudioPlayerService {
  // 公共状态
  MysicPlayerState _state = MysicPlayerState.idle;
  Song? _currentSong;
  List<Song> _playlist = [];
  int _currentIndex = -1;
  bool _isShuffleMode = false;
  MysicLoopMode _loopMode = MysicLoopMode.off;
  Duration _position = Duration.zero;
  Duration? _duration;

  // 状态流控制器
  final _stateController = StreamController<MysicPlayerState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _currentSongController = StreamController<Song?>.broadcast();

  // 平台特定播放器
  just_audio.AudioPlayer? _justAudioPlayer;        // 移动端
  MysicAudioHandler? _audioHandler;     // 移动端后台服务
  audioplayers.AudioPlayer? _audioplayersPlayer;     // Windows

  // 公开的流
  Stream<MysicPlayerState> get stateStream => _stateController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;
  Stream<Song?> get currentSongStream => _currentSongController.stream;

  // 当前状态
  MysicPlayerState get state => _state;
  Song? get currentSong => _currentSong;
  Duration get position => _position;
  Duration? get duration => _duration;
  bool get isPlaying => _state == MysicPlayerState.playing;
  bool get isShuffleMode => _isShuffleMode;
  MysicLoopMode get loopMode => _loopMode;
  List<Song> get playlist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;

  /// 初始化音频播放服务
  Future<void> initialize() async {
    debugPrint('========== AudioPlayerService.initialize ==========');
    debugPrint('Platform: ${Platform.operatingSystem}');

    if (Platform.isAndroid || Platform.isIOS) {
      await _initMobile();
    } else {
      await _initWindows();
    }
  }

  // ========== 移动端初始化（just_audio + audio_service）==========
  Future<void> _initMobile() async {
    debugPrint('使用 just_audio + audio_service');

    _justAudioPlayer = just_audio.AudioPlayer();

    // 初始化 AudioHandler（后台播放服务）
    _audioHandler = await AudioService.init(
      builder: () => MysicAudioHandler(
        _justAudioPlayer!,
        onSongCompleted: _onSongCompleted,
      ),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.mysic.app.audio',
        androidNotificationChannelName: 'Mysic 播放器',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );

    // 监听播放器状态
    _justAudioPlayer!.playerStateStream.listen((state) {
      debugPrint('========== playerStateStream 事件: processingState=${state.processingState}, playing=${state.playing} ==========');
      _handleMobilePlayerState(state);
    });

    // 监听播放位置
    _justAudioPlayer!.positionStream.listen((position) {
      _position = position;
      _positionController.add(position);
    });

    // 监听歌曲时长
    _justAudioPlayer!.durationStream.listen((duration) {
      _duration = duration;
      _durationController.add(duration);
      debugPrint('========== durationStream 事件: $duration ==========');
    });

    debugPrint('移动端播放器初始化完成');
  }

  void _handleMobilePlayerState(just_audio.PlayerState state) {
    debugPrint('just_audio state: ${state.processingState}, playing: ${state.playing}');
    switch (state.processingState) {
      case just_audio.ProcessingState.idle:
        _updateState(MysicPlayerState.idle);
        break;
      case just_audio.ProcessingState.loading:
      case just_audio.ProcessingState.buffering:
        _updateState(MysicPlayerState.loading);
        break;
      case just_audio.ProcessingState.ready:
        _updateState(state.playing ? MysicPlayerState.playing : MysicPlayerState.paused);
        break;
      case just_audio.ProcessingState.completed:
        // completed 状态由 processingStateStream 单独处理
        break;
    }
  }

  // ========== Windows 初始化（audioplayers）==========
  Future<void> _initWindows() async {
    debugPrint('使用 audioplayers');

    _audioplayersPlayer = audioplayers.AudioPlayer();

    // 监听播放器状态
    _audioplayersPlayer!.onPlayerStateChanged.listen((state) {
      debugPrint('audioplayers state: $state');
      switch (state) {
        case audioplayers.PlayerState.stopped:
          _updateState(MysicPlayerState.idle);
          break;
        case audioplayers.PlayerState.playing:
          _updateState(MysicPlayerState.playing);
          break;
        case audioplayers.PlayerState.paused:
          _updateState(MysicPlayerState.paused);
          break;
        case audioplayers.PlayerState.completed:
          _onSongCompleted();
          break;
        case audioplayers.PlayerState.disposed:
          _updateState(MysicPlayerState.idle);
          break;
      }
    });

    // 监听播放位置
    _audioplayersPlayer!.onPositionChanged.listen((position) {
      _position = position;
      _positionController.add(position);
    });

    // 监听歌曲时长
    _audioplayersPlayer!.onDurationChanged.listen((duration) {
      _duration = duration;
      _durationController.add(duration);
      debugPrint('Duration changed: $duration');
    });

    debugPrint('Windows 播放器初始化完成');
  }

  /// 更新状态
  void _updateState(MysicPlayerState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(_state);
    }
  }

  // ========== 播放控制（统一 API）==========

  /// 播放歌曲
  Future<void> playSong(Song song) async {
    try {
      _updateState(MysicPlayerState.loading);
      _currentSong = song;
      _currentSongController.add(_currentSong);

      if (Platform.isAndroid || Platform.isIOS) {
        await _justAudioPlayer!.setFilePath(song.filePath);
        await _justAudioPlayer!.play();
      } else {
        await _audioplayersPlayer!.play(audioplayers.DeviceFileSource(song.filePath));
      }
      // 不手动更新状态，依赖流的状态更新
    } catch (e) {
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
    _currentSong = songs[startIndex];
    _currentSongController.add(_currentSong);

    // 同步到 AudioHandler（移动端）
    if (_audioHandler != null) {
      await _audioHandler!.setPlaylist(songs, startIndex: startIndex);
    }

    _updateState(MysicPlayerState.loading);

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // 移动端：just_audio
        await _justAudioPlayer!.stop();
        await _justAudioPlayer!.setFilePath(songs[startIndex].filePath);

        // 等待 duration 加载完成（最多等待 2 秒）
        // 优先使用流事件的值，确保获取到正确的 duration
        Duration? loadedDuration = _justAudioPlayer!.duration;
        if (loadedDuration == null) {
          try {
            loadedDuration = await _justAudioPlayer!.durationStream
                .where((d) => d != null)
                .timeout(const Duration(seconds: 2))
                .first;
          } catch (_) {
            debugPrint('等待 duration 超时，尝试再次获取');
            loadedDuration = _justAudioPlayer!.duration;
          }
        }
        // 同步 duration 到本地变量
        _duration = loadedDuration;
        _durationController.add(_duration);
        debugPrint('Duration loaded: $_duration');

        if (autoPlay) {
          await _justAudioPlayer!.play();
          // 不手动更新状态，依赖 playerStateStream 的状态更新
          debugPrint('播放命令已执行');
        } else {
          // 非自动播放时，手动设置为 ready 状态
          _updateState(MysicPlayerState.ready);
        }
      } else {
        // Windows：audioplayers
        await _audioplayersPlayer!.stop();
        await _audioplayersPlayer!.setSource(audioplayers.DeviceFileSource(songs[startIndex].filePath));

        // 等待时长加载
        await Future.delayed(const Duration(milliseconds: 100));

        if (autoPlay) {
          await _audioplayersPlayer!.resume();
          // 不手动更新状态，依赖 onPlayerStateChanged 的状态更新
          debugPrint('播放命令已执行');
        } else {
          _updateState(MysicPlayerState.ready);
        }
      }

      debugPrint('========== AudioPlayerService.setPlaylist 完成，state=$_state, duration=$_duration ==========');
    } catch (e) {
      debugPrint('播放错误: $e');
      _updateState(MysicPlayerState.error);
      rethrow;
    }
  }

  /// 播放
  Future<void> play() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await _justAudioPlayer!.play();
    } else {
      await _audioplayersPlayer!.resume();
    }
  }

  /// 暂停
  Future<void> pause() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await _justAudioPlayer!.pause();
    } else {
      await _audioplayersPlayer!.pause();
    }
  }

  /// 停止
  Future<void> stop() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await _justAudioPlayer!.stop();
    } else {
      await _audioplayersPlayer!.stop();
    }
    _currentSong = null;
    _currentIndex = -1;
    _position = Duration.zero;
    _duration = null;
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

    if (Platform.isAndroid || Platform.isIOS) {
      await _justAudioPlayer!.stop();
      await _justAudioPlayer!.setFilePath(_currentSong!.filePath);
      // 立即更新通知栏歌曲信息
      _audioHandler?.setMediaItem(_currentSong!, duration: _justAudioPlayer!.duration);
      await _justAudioPlayer!.play();
    } else {
      await _audioplayersPlayer!.stop();
      await _audioplayersPlayer!.setSource(audioplayers.DeviceFileSource(_currentSong!.filePath));
      await _audioplayersPlayer!.resume();
    }
    // 不手动更新状态，依赖流的状态更新
  }

  /// 播放上一首
  Future<void> previous() async {
    if (_playlist.isEmpty) return;

    if (_currentIndex > 0) {
      _currentIndex--;
    } else if (_loopMode == MysicLoopMode.all) {
      _currentIndex = _playlist.length - 1;
    } else {
      if (Platform.isAndroid || Platform.isIOS) {
        await _justAudioPlayer!.seek(Duration.zero);
      } else {
        await _audioplayersPlayer!.seek(Duration.zero);
      }
      return;
    }

    _currentSong = _playlist[_currentIndex];
    _currentSongController.add(_currentSong);
    _updateState(MysicPlayerState.loading);

    if (Platform.isAndroid || Platform.isIOS) {
      await _justAudioPlayer!.stop();
      await _justAudioPlayer!.setFilePath(_currentSong!.filePath);
      // 立即更新通知栏歌曲信息
      _audioHandler?.setMediaItem(_currentSong!, duration: _justAudioPlayer!.duration);
      await _justAudioPlayer!.play();
    } else {
      await _audioplayersPlayer!.stop();
      await _audioplayersPlayer!.setSource(audioplayers.DeviceFileSource(_currentSong!.filePath));
      await _audioplayersPlayer!.resume();
    }
    // 不手动更新状态，依赖流的状态更新
  }

  /// 跳转到指定位置
  Future<void> seek(Duration position) async {
    if (Platform.isAndroid || Platform.isIOS) {
      await _justAudioPlayer!.seek(position);
    } else {
      await _audioplayersPlayer!.seek(position);
    }
    _position = position;
    _positionController.add(position);
  }

  /// 跳转到指定歌曲
  Future<void> seekToIndex(int index) async {
    if (index < 0 || index >= _playlist.length) return;

    _currentIndex = index;
    _currentSong = _playlist[_currentIndex];
    _currentSongController.add(_currentSong);
    _updateState(MysicPlayerState.loading);

    if (Platform.isAndroid || Platform.isIOS) {
      await _justAudioPlayer!.stop();
      await _justAudioPlayer!.setFilePath(_currentSong!.filePath);
      // 立即更新通知栏歌曲信息
      _audioHandler?.setMediaItem(_currentSong!, duration: _justAudioPlayer!.duration);
      await _justAudioPlayer!.play();
    } else {
      await _audioplayersPlayer!.stop();
      await _audioplayersPlayer!.setSource(audioplayers.DeviceFileSource(_currentSong!.filePath));
      await _audioplayersPlayer!.resume();
    }
    // 不手动更新状态，依赖流的状态更新
  }

  /// 设置播放速度
  Future<void> setSpeed(double speed) async {
    if (Platform.isAndroid || Platform.isIOS) {
      await _justAudioPlayer!.setSpeed(speed);
    } else {
      await _audioplayersPlayer!.setPlaybackRate(speed);
    }
  }

  /// 切换随机模式
  Future<void> toggleShuffleMode() async {
    _isShuffleMode = !_isShuffleMode;
  }

  /// 设置循环模式
  Future<void> setLoopMode(MysicLoopMode mode) async {
    _loopMode = mode;
    _audioHandler?.setLoopMode(mode == MysicLoopMode.all);

    if (Platform.isAndroid || Platform.isIOS) {
      await _justAudioPlayer!.setLoopMode(
        mode == MysicLoopMode.all ? just_audio.LoopMode.all : just_audio.LoopMode.off,
      );
    } else {
      await _audioplayersPlayer!.setReleaseMode(
        mode == MysicLoopMode.all ? audioplayers.ReleaseMode.loop : audioplayers.ReleaseMode.stop,
      );
    }
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
    debugPrint('========== _onSongCompleted ==========');
    debugPrint('currentIndex: $_currentIndex, playlist length: ${_playlist.length}, loopMode: $_loopMode');

    if (_currentIndex < _playlist.length - 1 || _loopMode == MysicLoopMode.all) {
      debugPrint('准备播放下一首');
      next();
    } else {
      debugPrint('播放列表结束');
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
    _audioHandler?.updateSong(updatedSong);
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
          if (Platform.isAndroid || Platform.isIOS) {
            await _justAudioPlayer!.stop();
            await _justAudioPlayer!.setFilePath(_currentSong!.filePath);
            await _justAudioPlayer!.play();
          } else {
            await _audioplayersPlayer!.stop();
            await _audioplayersPlayer!.setSource(audioplayers.DeviceFileSource(_currentSong!.filePath));
            await _audioplayersPlayer!.resume();
          }
          // 不手动更新状态，依赖流的状态更新
        } else {
          if (Platform.isAndroid || Platform.isIOS) {
            await _justAudioPlayer!.stop();
            await _justAudioPlayer!.setFilePath(_currentSong!.filePath);
          } else {
            await _audioplayersPlayer!.stop();
            await _audioplayersPlayer!.setSource(audioplayers.DeviceFileSource(_currentSong!.filePath));
          }
          _updateState(MysicPlayerState.ready);
        }
      } else {
        _currentIndex = -1;
        _currentSong = null;
        _currentSongController.add(null);
        if (Platform.isAndroid || Platform.isIOS) {
          await _justAudioPlayer!.stop();
        } else {
          await _audioplayersPlayer!.stop();
        }
        _updateState(MysicPlayerState.idle);
      }
    }

    _audioHandler?.removeSong(index);
    return _playlist.isEmpty;
  }

  /// 释放资源
  Future<void> dispose() async {
    await _justAudioPlayer?.dispose();
    await _audioplayersPlayer?.dispose();
    await _stateController.close();
    await _positionController.close();
    await _durationController.close();
    await _currentSongController.close();
  }
}
