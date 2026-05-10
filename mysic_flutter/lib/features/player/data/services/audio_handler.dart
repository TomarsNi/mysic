import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';

/// 后台音频处理器
/// 实现 audio_service 的回调，处理后台播放、通知栏控制
/// 仅用于 Android/iOS 平台
class MysicAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player;
  final void Function()? onSongCompleted;
  final void Function(Song song, int index)? onSongChanged;

  // 播放列表
  List<Song> _playlist = [];
  int _currentIndex = -1;

  // 循环模式
  bool _loopMode = false;

  MysicAudioHandler(this._player, {this.onSongCompleted, this.onSongChanged}) {
    _init();
  }

  void _init() {
    // 监听播放状态
    _player.playerStateStream.listen((state) {
      _updatePlaybackState();
    });

    // 监听播放位置
    _player.positionStream.listen((position) {
      // 更新通知栏进度（通过 playbackState）
      _updatePlaybackState();
    });

    // 监听歌曲时长
    _player.durationStream.listen((duration) {
      debugPrint('========== durationStream 触发 _updateMediaItem ==========');
      debugPrint('currentIndex: $_currentIndex, playlist length: ${_playlist.length}');
      if (_currentIndex >= 0 && _currentIndex < _playlist.length) {
        debugPrint('当前歌曲: ${_playlist[_currentIndex].title}');
      }
      _updateMediaItem(duration);
    });

    // 监听播放完成
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _handleSongCompleted();
      }
    });
  }

  void _updatePlaybackState() {
    final state = _player.playerState;
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (state.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 2],
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
    debugPrint('========== _updateMediaItem ==========');
    debugPrint('currentIndex: $_currentIndex, playlist length: ${_playlist.length}');
    if (_currentIndex < 0 || _currentIndex >= _playlist.length) return;
    final song = _playlist[_currentIndex];
    debugPrint('更新为歌曲: ${song.title}');
    mediaItem.add(MediaItem(
      id: song.id?.toString() ?? song.filePath,
      title: song.title,
      artist: song.artist ?? '未知艺术家',
      album: song.album ?? '未知专辑',
      duration: duration,
      artUri: song.albumArtPath != null ? Uri.file(song.albumArtPath!) : null,
    ));
  }

  void _handleSongCompleted() {
    if (onSongCompleted != null) {
      onSongCompleted!();
    } else if (_loopMode || _currentIndex < _playlist.length - 1) {
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
    debugPrint('========== MysicAudioHandler.skipToNext ==========');
    debugPrint('playlist length: ${_playlist.length}, currentIndex: $_currentIndex');
    if (_playlist.isEmpty) return;
    if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
    } else if (_loopMode) {
      _currentIndex = 0;
    } else {
      return;
    }
    debugPrint('new currentIndex: $_currentIndex');
    await _playCurrentSong();
    // 通知 AudioPlayerService 同步状态
    onSongChanged?.call(currentSong!, _currentIndex);
    debugPrint('========== MysicAudioHandler.skipToNext 完成 ==========');
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
    // 通知 AudioPlayerService 同步状态
    onSongChanged?.call(currentSong!, _currentIndex);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    _currentIndex = index;
    await _playCurrentSong();
    // 通知 AudioPlayerService 同步状态
    onSongChanged?.call(currentSong!, _currentIndex);
  }

  Future<void> _playCurrentSong() async {
    if (_currentIndex < 0 || _currentIndex >= _playlist.length) return;
    final song = _playlist[_currentIndex];
    debugPrint('========== _playCurrentSong ==========');
    debugPrint('歌曲: ${song.title}, id: ${song.id}');

    // 立即更新通知栏歌曲信息（不等待 duration）
    final newMediaItem = MediaItem(
      id: song.id?.toString() ?? song.filePath,
      title: song.title,
      artist: song.artist ?? '未知艺术家',
      album: song.album ?? '未知专辑',
      duration: _player.duration, // 可能为 null，后续由 durationStream 更新
      artUri: song.albumArtPath != null ? Uri.file(song.albumArtPath!) : null,
    );
    debugPrint('更新 mediaItem: title=${newMediaItem.title}, id=${newMediaItem.id}');
    mediaItem.add(newMediaItem);

    await _player.setFilePath(song.filePath);
    await _player.play();
    debugPrint('========== _playCurrentSong 完成 ==========');
  }

  /// 更新当前索引（不播放，仅同步状态）
  void updateCurrentIndex(int index) {
    if (index < 0 || index >= _playlist.length) return;
    _currentIndex = index;
    debugPrint('========== updateCurrentIndex ==========');
    debugPrint('新索引: $_currentIndex, 歌曲: ${_playlist[_currentIndex].title}');
  }

  /// 更新播放列表
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

  /// 更新播放列表中的歌曲
  void updateSong(Song updatedSong) {
    final index = _playlist.indexWhere((s) => s.id == updatedSong.id);
    if (index != -1) {
      _playlist[index] = updatedSong;
    }
  }

  /// 从播放列表移除歌曲
  void removeSong(int index) {
    if (index < 0 || index >= _playlist.length) return;
    _playlist.removeAt(index);
    if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex) {
      // 当前歌曲被移除，需要处理
    }
  }

  /// 更新通知栏显示的歌曲信息
  void setMediaItem(Song song, {Duration? duration}) {
    mediaItem.add(MediaItem(
      id: song.id?.toString() ?? song.filePath,
      title: song.title,
      artist: song.artist ?? '未知艺术家',
      album: song.album ?? '未知专辑',
      duration: duration,
      artUri: song.albumArtPath != null ? Uri.file(song.albumArtPath!) : null,
    ));
  }
}