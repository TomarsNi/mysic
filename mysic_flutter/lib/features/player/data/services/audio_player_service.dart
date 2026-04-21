import 'dart:async';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:audio_session/audio_session.dart';
import '../models/song.dart';

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
  off,   // 关闭循环
  one,   // 单曲循环
  all,   // 列表循环
}

/// 音频播放服务
/// 使用 just_audio 实现音频播放核心功能
class AudioPlayerService {
  final just_audio.AudioPlayer _player = just_audio.AudioPlayer();
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
  bool get isPlaying => _player.playing;
  bool get isShuffleMode => _isShuffleMode;
  MysicLoopMode get loopMode => _loopMode;
  List<Song> get playlist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;

  /// 初始化音频播放服务
  Future<void> initialize() async {
    // 配置音频会话
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // 监听播放器状态
    _player.playerStateStream.listen((playerState) {
      _handlePlayerStateChange(playerState);
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
      if (state == just_audio.ProcessingState.completed) {
        _onSongCompleted();
      }
    });
  }

  /// 处理播放器状态变化
  void _handlePlayerStateChange(just_audio.PlayerState playerState) {
    if (playerState.playing) {
      _updateState(MysicPlayerState.playing);
    } else if (playerState.processingState == just_audio.ProcessingState.ready) {
      _updateState(MysicPlayerState.paused);
    } else if (playerState.processingState == just_audio.ProcessingState.loading) {
      _updateState(MysicPlayerState.loading);
    } else if (playerState.processingState == just_audio.ProcessingState.idle) {
      _updateState(MysicPlayerState.idle);
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
    } catch (e) {
      _updateState(MysicPlayerState.error);
      rethrow;
    }
  }

  /// 设置播放列表
  Future<void> setPlaylist(List<Song> songs, {int startIndex = 0, bool autoPlay = false}) async {
    if (songs.isEmpty) return;

    _playlist = List.from(songs);
    _currentIndex = startIndex;

    // 创建音频源列表
    final sources = songs.map((song) => just_audio.AudioSource.file(song.filePath)).toList();
    final playlist = just_audio.ConcatenatingAudioSource(children: sources);

    _updateState(MysicPlayerState.loading);

    await _player.setAudioSource(
      playlist,
      initialIndex: startIndex,
      initialPosition: Duration.zero,
    );

    _currentSong = songs[startIndex];
    _currentSongController.add(_currentSong);

    if (autoPlay) {
      await _player.play();
      _updateState(MysicPlayerState.playing);
    } else {
      _updateState(MysicPlayerState.ready);
    }
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
      // 随机模式：随机选择下一首
      final randomIndex = _getRandomIndex();
      await _player.seek(Duration.zero, index: randomIndex);
      _currentIndex = randomIndex;
    } else {
      // 顺序模式
      if (_currentIndex < _playlist.length - 1) {
        _currentIndex++;
      } else if (_loopMode == MysicLoopMode.all) {
        _currentIndex = 0;
      } else {
        return; // 已是最后一首且未开启列表循环
      }
      await _player.seekToNext();
    }

    _currentSong = _playlist[_currentIndex];
    _currentSongController.add(_currentSong);
    await _player.play();
  }

  /// 播放上一首
  Future<void> previous() async {
    if (_playlist.isEmpty) return;

    // 如果当前播放超过3秒，重新播放当前歌曲
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }

    if (_currentIndex > 0) {
      _currentIndex--;
    } else if (_loopMode == MysicLoopMode.all) {
      _currentIndex = _playlist.length - 1;
    } else {
      await _player.seek(Duration.zero);
      return;
    }

    await _player.seekToPrevious();
    _currentSong = _playlist[_currentIndex];
    _currentSongController.add(_currentSong);
    await _player.play();
  }

  /// 跳转到指定位置
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// 跳转到指定歌曲
  Future<void> seekToIndex(int index) async {
    if (index < 0 || index >= _playlist.length) return;

    _currentIndex = index;
    await _player.seek(Duration.zero, index: index);
    _currentSong = _playlist[_currentIndex];
    _currentSongController.add(_currentSong);
    await _player.play();
  }

  /// 设置播放速度
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  /// 切换随机模式
  Future<void> toggleShuffleMode() async {
    _isShuffleMode = !_isShuffleMode;
    await _player.setShuffleModeEnabled(_isShuffleMode);
  }

  /// 设置循环模式
  Future<void> setLoopMode(MysicLoopMode mode) async {
    _loopMode = mode;
    // 转换为 just_audio 的 LoopMode
    just_audio.LoopMode justAudioLoopMode;
    switch (mode) {
      case MysicLoopMode.off:
        justAudioLoopMode = just_audio.LoopMode.off;
        break;
      case MysicLoopMode.one:
        justAudioLoopMode = just_audio.LoopMode.one;
        break;
      case MysicLoopMode.all:
        justAudioLoopMode = just_audio.LoopMode.all;
        break;
    }
    await _player.setLoopMode(justAudioLoopMode);
  }

  /// 切换循环模式 (关闭 -> 单曲循环 -> 列表循环 -> 关闭)
  Future<void> toggleLoopMode() async {
    switch (_loopMode) {
      case MysicLoopMode.off:
        await setLoopMode(MysicLoopMode.one);
        break;
      case MysicLoopMode.one:
        await setLoopMode(MysicLoopMode.all);
        break;
      case MysicLoopMode.all:
        await setLoopMode(MysicLoopMode.off);
        break;
    }
  }

  /// 歌曲播放完成回调
  void _onSongCompleted() {
    if (_loopMode == MysicLoopMode.one) {
      // 单曲循环：重新播放
      _player.seek(Duration.zero);
      _player.play();
    } else if (_currentIndex < _playlist.length - 1 || _loopMode == MysicLoopMode.all) {
      // 自动播放下一首
      next();
    } else {
      // 播放完成
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

  /// 释放资源
  Future<void> dispose() async {
    await _player.dispose();
    await _stateController.close();
    await _positionController.close();
    await _durationController.close();
    await _currentSongController.close();
  }
}
