import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';

/// 后台音频处理器
/// 实现 audio_service 的回调，处理后台播放、通知栏控制
class MysicAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player;

  // 播放列表
  List<Song> _playlist = [];
  int _currentIndex = -1;

  // 循环模式
  bool _loopMode = false;

  // Stream 订阅管理
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  MysicAudioHandler(this._player) {
    _init();
  }

  void _init() {
    // 监听播放状态（合并状态更新和播放完成监听）
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      _updatePlaybackState();
      if (state.processingState == ProcessingState.completed) {
        _onSongCompleted();
      }
    });

    // 监听播放位置
    _positionSubscription = _player.positionStream.listen((position) {
      // 更新通知栏进度
    });

    // 监听歌曲时长
    _durationSubscription = _player.durationStream.listen((duration) {
      _updateMediaItem(duration);
    });
  }

  /// 释放资源
  void dispose() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
  }

  void _updatePlaybackState() {
    final state = _player.playerState;
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.rewind,
        if (state.playing) MediaControl.pause else MediaControl.play,
        MediaControl.fastForward,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 2, 4],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
        ProcessingState.buffering: AudioProcessingState.buffering,
      }[state.processingState]!,
      playing: state.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    ));
  }

  void _updateMediaItem(Duration? duration) {
    if (_currentIndex < 0 || _currentIndex >= _playlist.length) return;
    final song = _playlist[_currentIndex];
    mediaItem.add(MediaItem(
      id: song.id?.toString() ?? song.filePath,
      title: song.title,
      artist: song.artist ?? '未知艺术家',
      album: song.album ?? '未知专辑',
      duration: duration,
      artUri: song.albumArtPath != null ? Uri.file(song.albumArtPath!) : null,
    ));
  }

  void _onSongCompleted() {
    if (_loopMode || _currentIndex < _playlist.length - 1) {
      skipToNext();
    }
  }

  // AudioHandler 回调实现
  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_playlist.isEmpty) return;
    if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
    } else if (_loopMode) {
      _currentIndex = 0;
    } else {
      return;
    }
    await _playCurrentSong();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_playlist.isEmpty) return;
    if (_currentIndex > 0) {
      _currentIndex--;
    } else if (_loopMode) {
      _currentIndex = _playlist.length - 1;
    } else {
      await _player.seek(Duration.zero);
      return;
    }
    await _playCurrentSong();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    _currentIndex = index;
    await _playCurrentSong();
  }

  Future<void> _playCurrentSong() async {
    if (_currentIndex < 0 || _currentIndex >= _playlist.length) return;
    final song = _playlist[_currentIndex];
    try {
      await _player.setFilePath(song.filePath);
      await _player.play();
      _updateMediaItem(_player.duration);
    } catch (e) {
      // 加载失败，跳到下一首
      debugPrint('播放失败: $e');
      if (_currentIndex < _playlist.length - 1) {
        _currentIndex++;
        await _playCurrentSong();
      }
    }
  }

  /// 设置播放列表
  Future<void> setPlaylist(List<Song> songs, {int startIndex = 0}) async {
    _playlist = List.from(songs);
    _currentIndex = startIndex;
    queue.add(songs.map((s) => MediaItem(
      id: s.id?.toString() ?? s.filePath,
      title: s.title,
      artist: s.artist ?? '未知艺术家',
    )).toList());
  }

  /// 设置循环模式
  void setLoopMode(bool enabled) {
    _loopMode = enabled;
  }

  /// 获取当前歌曲
  Song? get currentSong =>
      _currentIndex >= 0 && _currentIndex < _playlist.length
          ? _playlist[_currentIndex]
          : null;

  /// 获取当前索引
  int get currentIndex => _currentIndex;

  /// 获取播放列表
  List<Song> get playlist => List.unmodifiable(_playlist);
}