import 'package:flutter/foundation.dart';
import '../../data/models/song.dart';
import '../../data/services/audio_player_service.dart';
import '../../../lyrics/data/services/lyrics_parser.dart';

/// 播放器状态管理 Provider
/// 使用 ChangeNotifier 管理播放器状态，供 UI 层使用
class PlayerProvider extends ChangeNotifier {
  final AudioPlayerService _audioPlayerService;
  final LyricsParser _lyricsParser = LyricsParser();

  // 状态
  MysicPlayerState _playerState = MysicPlayerState.idle;
  Song? _currentSong;
  Duration _position = Duration.zero;
  Duration? _duration;
  List<Song> _playlist = [];
  int _currentIndex = -1;
  bool _isShuffleMode = false;
  MysicLoopMode _loopMode = MysicLoopMode.off;

  // 歌词状态
  LyricsResult _currentLyrics = LyricsResult.empty;

  // 扫描状态
  bool _isScanning = false;
  double? _scanProgress;

  PlayerProvider({AudioPlayerService? audioPlayerService})
      : _audioPlayerService = audioPlayerService ?? AudioPlayerService() {
    _init();
  }

  /// 初始化
  Future<void> _init() async {
    await _audioPlayerService.initialize();

    // 监听播放器状态变化
    _audioPlayerService.stateStream.listen((state) {
      _playerState = state;
      notifyListeners();
    });

    // 监听播放位置变化
    _audioPlayerService.positionStream.listen((position) {
      _position = position;
      notifyListeners();
    });

    // 监听歌曲时长变化
    _audioPlayerService.durationStream.listen((duration) {
      _duration = duration;
      notifyListeners();
    });

    // 监听当前歌曲变化
    _audioPlayerService.currentSongStream.listen((song) {
      _currentSong = song;
      // 加载歌词
      _loadLyricsForSong(song);
      notifyListeners();
    });
  }

  /// 加载当前歌曲的歌词
  Future<void> _loadLyricsForSong(Song? song) async {
    if (song == null) {
      _currentLyrics = LyricsResult.empty;
      return;
    }

    // 尝试查找歌词文件
    final lyricsPath = _lyricsParser.findLyricsFile(song.filePath);
    if (lyricsPath != null) {
      _currentLyrics = await _lyricsParser.parseFile(lyricsPath);
    } else {
      _currentLyrics = LyricsResult.empty;
    }
    notifyListeners();
  }

  // Getters
  MysicPlayerState get playerState => _playerState;
  Song? get currentSong => _currentSong;
  Duration get position => _position;
  Duration? get duration => _duration;
  List<Song> get playlist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;
  bool get isShuffleMode => _isShuffleMode;
  MysicLoopMode get loopMode => _loopMode;
  bool get isScanning => _isScanning;
  double? get scanProgress => _scanProgress;
  LyricsResult get currentLyrics => _currentLyrics;

  // 便捷 Getters
  bool get isPlaying => _playerState == MysicPlayerState.playing;
  bool get isPaused => _playerState == MysicPlayerState.paused;
  bool get isLoading => _playerState == MysicPlayerState.loading;
  bool get hasCurrentSong => _currentSong != null;
  bool get hasPlaylist => _playlist.isNotEmpty;
  bool get hasLyrics => _currentLyrics.isValid;

  /// 获取当前歌词行
  LyricLine? get currentLyricLine {
    if (!_currentLyrics.isValid) return null;
    return _currentLyrics.getCurrentLine(_position);
  }

  /// 获取下一行歌词
  LyricLine? get nextLyricLine {
    if (!_currentLyrics.isValid) return null;
    final currentIndex = _currentLyrics.getCurrentLineIndex(_position);
    if (currentIndex < 0 || currentIndex >= _currentLyrics.lines.length - 1) return null;
    return _currentLyrics.lines[currentIndex + 1];
  }

  /// 进度百分比 (0.0 - 1.0)
  double get progress {
    if (_duration == null || _duration!.inMilliseconds == 0) return 0.0;
    return _position.inMilliseconds / _duration!.inMilliseconds;
  }

  /// 格式化的当前位置 (mm:ss)
  String get formattedPosition => _formatDuration(_position);

  /// 格式化的总时长 (mm:ss)
  String get formattedDuration => _duration != null ? _formatDuration(_duration!) : '--:--';

  /// 格式化时长
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// 播放歌曲
  Future<void> playSong(Song song) async {
    await _audioPlayerService.playSong(song);
    _currentSong = song;
    notifyListeners();
  }

  /// 设置播放列表
  Future<void> setPlaylist(List<Song> songs, {int startIndex = 0}) async {
    _playlist = List.from(songs);
    _currentIndex = startIndex;
    notifyListeners();

    await _audioPlayerService.setPlaylist(songs, startIndex: startIndex);
  }

  /// 播放
  Future<void> play() async {
    await _audioPlayerService.play();
  }

  /// 暂停
  Future<void> pause() async {
    await _audioPlayerService.pause();
  }

  /// 切换播放/暂停
  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// 停止
  Future<void> stop() async {
    await _audioPlayerService.stop();
    _playlist = [];
    _currentIndex = -1;
    notifyListeners();
  }

  /// 播放下一首
  Future<void> next() async {
    await _audioPlayerService.next();
    if (_audioPlayerService.currentIndex >= 0) {
      _currentIndex = _audioPlayerService.currentIndex;
      notifyListeners();
    }
  }

  /// 播放上一首
  Future<void> previous() async {
    await _audioPlayerService.previous();
    if (_audioPlayerService.currentIndex >= 0) {
      _currentIndex = _audioPlayerService.currentIndex;
      notifyListeners();
    }
  }

  /// 跳转到指定位置
  Future<void> seek(Duration position) async {
    await _audioPlayerService.seek(position);
    _position = position;
    notifyListeners();
  }

  /// 跳转到指定进度 (0.0 - 1.0)
  Future<void> seekToProgress(double progress) async {
    if (_duration == null) return;
    final position = Duration(
      milliseconds: (_duration!.inMilliseconds * progress).round(),
    );
    await seek(position);
  }

  /// 跳转到指定歌曲
  Future<void> seekToIndex(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    await _audioPlayerService.seekToIndex(index);
    _currentIndex = index;
    notifyListeners();
  }

  /// 设置播放速度
  Future<void> setSpeed(double speed) async {
    await _audioPlayerService.setSpeed(speed);
  }

  /// 切换随机模式
  Future<void> toggleShuffleMode() async {
    await _audioPlayerService.toggleShuffleMode();
    _isShuffleMode = _audioPlayerService.isShuffleMode;
    notifyListeners();
  }

  /// 设置循环模式
  Future<void> setLoopMode(MysicLoopMode mode) async {
    await _audioPlayerService.setLoopMode(mode);
    _loopMode = mode;
    notifyListeners();
  }

  /// 切换循环模式
  Future<void> toggleLoopMode() async {
    await _audioPlayerService.toggleLoopMode();
    _loopMode = _audioPlayerService.loopMode;
    notifyListeners();
  }

  /// 添加歌曲到播放列表末尾
  void addToPlaylist(Song song) {
    _playlist.add(song);
    notifyListeners();
  }

  /// 从播放列表移除歌曲
  void removeFromPlaylist(int index) {
    if (index < 0 || index >= _playlist.length) return;

    _playlist.removeAt(index);

    // 调整当前索引
    if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex) {
      // 如果移除的是当前播放的歌曲，播放下一首
      if (_playlist.isNotEmpty) {
        if (_currentIndex >= _playlist.length) {
          _currentIndex = _playlist.length - 1;
        }
        seekToIndex(_currentIndex);
      } else {
        stop();
      }
    }

    notifyListeners();
  }

  /// 清空播放列表
  Future<void> clearPlaylist() async {
    await stop();
    _playlist = [];
    _currentIndex = -1;
    notifyListeners();
  }

  /// 开始扫描
  void startScan() {
    _isScanning = true;
    _scanProgress = 0.0;
    notifyListeners();
  }

  /// 更新扫描进度
  void updateScanProgress(double progress) {
    _scanProgress = progress;
    notifyListeners();
  }

  /// 完成扫描
  void finishScan() {
    _isScanning = false;
    _scanProgress = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _audioPlayerService.dispose();
    super.dispose();
  }
}
