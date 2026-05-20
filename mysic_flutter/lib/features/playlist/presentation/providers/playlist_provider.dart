import 'package:flutter/foundation.dart';
import 'package:mysic_flutter/core/utils/app_logger.dart';
import '../../data/playlist_repository.dart';
import '../../../player/data/models/song.dart';
import '../../../player/data/models/playlist.dart';
import '../../../../core/utils/file_utils.dart';

/// 歌单状态管理 Provider
/// 使用 ChangeNotifier 管理歌单状态，供 UI 层使用
class PlaylistProvider extends ChangeNotifier {
  final PlaylistRepository _repository;

  // 状态
  List<Playlist> _playlists = [];
  Playlist? _selectedPlaylist;
  List<Song> _selectedPlaylistSongs = [];
  List<Song> _allSongs = [];
  List<Song> _playHistory = [];
  Set<int> _excludedSongIds = {}; // 排除歌曲 ID 缓存
  int? _systemPlaylistId; // 系统歌单 ID 缓存
  Playlist? _favoritesPlaylist; // 收藏歌单
  Set<int> _favoriteSongIds = {}; // 已收藏歌曲 ID 缓存
  bool _isLoading = false;
  String? _error;
  bool _initialized = false; // 防止重复初始化

  PlaylistProvider({PlaylistRepository? repository})
      : _repository = repository ?? PlaylistRepository() {
    _loadData();
  }

  // Getters
  List<Playlist> get playlists => List.unmodifiable(_playlists);
  Playlist? get selectedPlaylist => _selectedPlaylist;
  List<Song> get selectedPlaylistSongs => List.unmodifiable(_selectedPlaylistSongs);
  List<Song> get allSongs => List.unmodifiable(_allSongs);
  List<Song> get playHistory => List.unmodifiable(_playHistory);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasPlaylists => _playlists.isNotEmpty;
  bool get hasSongs => _allSongs.isNotEmpty;
  int get playlistCount => _playlists.length;
  int get songCount => _allSongs.length;
  int? get systemPlaylistId => _systemPlaylistId;
  Set<int> get excludedSongIds => Set.unmodifiable(_excludedSongIds);
  Playlist? get favoritesPlaylist => _favoritesPlaylist;
  Set<int> get favoriteSongIds => Set.unmodifiable(_favoriteSongIds);

  /// 加载初始数据
  Future<void> _loadData() async {
    if (_initialized) return; // 防止重复初始化
    _initialized = true;

    _setLoading(true);
    try {
      // 确保系统歌单存在
      await _ensureSystemPlaylistExists();

      // 确保收藏歌单存在
      await ensureFavoritesPlaylistExists();

      await Future.wait([
        _loadPlaylists(),
        _loadAllSongs(),
        _loadPlayHistory(),
        _loadExcludedSongIds(),
      ]);
    } catch (e) {
      _setError('加载数据失败: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// 加载所有歌单
  Future<void> _loadPlaylists() async {
    _playlists = await _repository.getAllPlaylistsWithSongs();
    AppLogger.i('PlaylistProvider#_loadPlaylists', '加载歌单列表，数量: ${_playlists.length}');
    for (final p in _playlists) {
      AppLogger.d('PlaylistProvider#_loadPlaylists', '歌单: id=${p.id}, name=${p.name}, isSystem=${p.isSystem}');
    }
    notifyListeners();
  }

  /// 加载所有歌曲
  Future<void> _loadAllSongs() async {
    _allSongs = await _repository.getAllSongs();
    notifyListeners();
  }

  /// 加载播放历史
  Future<void> _loadPlayHistory() async {
    _playHistory = await _repository.getPlayHistory();
    notifyListeners();
  }

  /// 确保系统歌单存在
  Future<void> _ensureSystemPlaylistExists() async {
    AppLogger.d('PlaylistProvider#_ensureSystemPlaylistExists', '========== 开始 ==========');

    // 先检查是否已有系统歌单
    final systemPlaylist = await _repository.getSystemPlaylist();
    AppLogger.d('PlaylistProvider#_ensureSystemPlaylistExists', '系统歌单查询结果: ${systemPlaylist?.id} - ${systemPlaylist?.name}');
    if (systemPlaylist != null) {
      _systemPlaylistId = systemPlaylist.id;
      AppLogger.i('PlaylistProvider#_ensureSystemPlaylistExists', '已存在系统歌单，ID: $_systemPlaylistId');
      return;
    }

    // 检查是否存在名为"本地音乐"的普通歌单，如果有则升级为系统歌单
    final existingPlaylist = await _repository.getLocalMusicPlaylist();
    AppLogger.d('PlaylistProvider#_ensureSystemPlaylistExists', '本地音乐歌单查询结果: ${existingPlaylist?.id} - ${existingPlaylist?.name}');
    if (existingPlaylist != null) {
      await _repository.upgradeToSystemPlaylist(existingPlaylist.id!);
      _systemPlaylistId = existingPlaylist.id;
      AppLogger.i('PlaylistProvider#_ensureSystemPlaylistExists', '升级现有歌单为系统歌单，ID: $_systemPlaylistId');
      return;
    }

    // 都不存在，创建新的系统歌单
    final created = await _repository.createSystemPlaylist(
      name: '本地音乐',
      description: '自动同步本地扫描的所有音乐',
    );
    _systemPlaylistId = created.id;
    AppLogger.i('PlaylistProvider#_ensureSystemPlaylistExists', '创建新的系统歌单，ID: $_systemPlaylistId');
    AppLogger.d('PlaylistProvider#_ensureSystemPlaylistExists', '========== 结束 ==========');
  }

  /// 确保收藏歌单存在
  Future<void> ensureFavoritesPlaylistExists() async {
    AppLogger.d('PlaylistProvider#ensureFavoritesPlaylistExists', '========== 开始 ==========');
    _favoritesPlaylist = await _repository.getFavoritesPlaylist();

    if (_favoritesPlaylist == null) {
      _favoritesPlaylist = await _repository.createFavoritesPlaylist();
      AppLogger.i('PlaylistProvider#ensureFavoritesPlaylistExists', '创建新的收藏歌单，ID: ${_favoritesPlaylist?.id}');
    } else {
      AppLogger.i('PlaylistProvider#ensureFavoritesPlaylistExists', '已存在收藏歌单，ID: ${_favoritesPlaylist?.id}');
    }

    // 加载收藏歌曲 ID
    await _loadFavoriteSongIds();
    AppLogger.d('PlaylistProvider#ensureFavoritesPlaylistExists', '========== 结束 ==========');
  }

  /// 加载收藏歌曲 ID 列表
  Future<void> _loadFavoriteSongIds() async {
    if (_favoritesPlaylist == null) {
      _favoriteSongIds = {};
      return;
    }
    _favoriteSongIds =
        _favoritesPlaylist!.songs?.map((s) => s.id!).toSet() ?? {};
    AppLogger.i('PlaylistProvider#_loadFavoriteSongIds', '加载收藏歌曲 ID，数量: ${_favoriteSongIds.length}');
  }

  /// 刷新收藏数据
  Future<void> refreshFavorites() async {
    _favoritesPlaylist = await _repository.getFavoritesPlaylist();
    await _loadFavoriteSongIds();
    notifyListeners();
  }

  /// 切换收藏状态
  Future<bool> toggleFavorite(Song song) async {
    if (song.id == null) return false;

    final songId = song.id!;
    final isFavorite = _favoriteSongIds.contains(songId);

    bool success;
    if (isFavorite) {
      success = await _repository.removeFromFavorites(songId);
      if (success) {
        _favoriteSongIds.remove(songId);
        // 更新歌单状态
        if (_favoritesPlaylist != null) {
          final updatedSongs =
              _favoritesPlaylist!.songs?.where((s) => s.id != songId).toList() ??
                  [];
          _favoritesPlaylist = _favoritesPlaylist!.copyWith(songs: updatedSongs);
        }
      }
    } else {
      success = await _repository.addToFavorites(song);
      if (success) {
        _favoriteSongIds.add(songId);
        // 更新歌单状态
        if (_favoritesPlaylist != null) {
          final updatedSongs = <Song>[..._favoritesPlaylist!.songs ?? [], song];
          _favoritesPlaylist = _favoritesPlaylist!.copyWith(songs: updatedSongs);
        }
      }
    }

    if (success) {
      notifyListeners();
    }
    return success;
  }

  /// 检查歌曲是否已收藏（同步方法，使用缓存）
  bool isSongFavorite(int songId) {
    return _favoriteSongIds.contains(songId);
  }

  /// 加载排除歌曲 ID 列表
  Future<void> _loadExcludedSongIds() async {
    _excludedSongIds = await _repository.getExcludedSongIds();
  }

  /// 同步歌曲到本地音乐歌单
  Future<void> syncToLocalMusicPlaylist(List<Song> scannedSongs) async {
    if (_systemPlaylistId == null) {
      await _ensureSystemPlaylistExists();
    }

    if (_systemPlaylistId == null) return;

    int addedCount = 0;
    for (final song in scannedSongs) {
      // 跳过已排除的歌曲
      if (_excludedSongIds.contains(song.id)) continue;

      // 添加到本地音乐歌单
      final success = await _repository.addSongToPlaylist(
        _systemPlaylistId!,
        song,
      );
      if (success) addedCount++;
    }

    if (addedCount > 0) {
      await _loadPlaylists(); // _loadPlaylists 内部会调用 notifyListeners
    }
  }

  /// 从本地音乐移除并排除
  Future<bool> removeFromLocalMusic(int songId) async {
    if (_systemPlaylistId == null) return false;

    try {
      // 1. 从歌单移除
      final success = await _repository.removeSongFromPlaylist(
        _systemPlaylistId!,
        songId,
      );

      // 2. 添加到排除列表
      if (success) {
        await _repository.excludeSong(songId);
        _excludedSongIds.add(songId);
        notifyListeners();
      }

      return success;
    } catch (e) {
      _setError('移除歌曲失败: $e');
      return false;
    }
  }

  /// 恢复歌曲到本地音乐
  Future<bool> restoreToLocalMusic(int songId) async {
    if (_systemPlaylistId == null) return false;

    try {
      // 1. 获取歌曲信息（在修改之前）
      final song = await _repository.getSongById(songId);
      if (song == null) {
        _setError('歌曲不存在');
        return false;
      }

      // 2. 添加到歌单（可能失败的操作先执行）
      await _repository.addSongToPlaylist(_systemPlaylistId!, song);

      // 3. 成功后才从排除列表移除
      await _repository.restoreSong(songId);
      _excludedSongIds.remove(songId);

      await _loadPlaylists();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('恢复歌曲失败: $e');
      return false;
    }
  }

  /// 刷新所有数据
  Future<void> refresh() async {
    await _loadData();
  }

  // ==================== 歌单操作 ====================

  /// 创建歌单
  Future<Playlist?> createPlaylist({
    required String name,
    String? description,
    String? coverPath,
  }) async {
    _setLoading(true);
    try {
      final playlist = await _repository.createPlaylist(
        name: name,
        description: description,
        coverPath: coverPath,
      );
      _playlists.insert(0, playlist);
      notifyListeners();
      return playlist;
    } catch (e) {
      _setError('创建歌单失败: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// 选择歌单
  Future<void> selectPlaylist(int playlistId) async {
    AppLogger.d('PlaylistProvider#selectPlaylist', '========== 开始, playlistId=$playlistId ==========');
    _setLoading(true);
    try {
      _selectedPlaylist = await _repository.getPlaylistById(playlistId);
      AppLogger.d('PlaylistProvider#selectPlaylist', '获取到的歌单: id=${_selectedPlaylist?.id}, name=${_selectedPlaylist?.name}');
      _selectedPlaylistSongs = _selectedPlaylist?.songs ?? [];
      AppLogger.i('PlaylistProvider#selectPlaylist', '歌曲数量: ${_selectedPlaylistSongs.length}');
      if (_selectedPlaylistSongs.isNotEmpty) {
        AppLogger.d('PlaylistProvider#selectPlaylist', '第一首歌: ${_selectedPlaylistSongs.first.title}');
      }
      notifyListeners();
    } catch (e) {
      AppLogger.e('PlaylistProvider#selectPlaylist', 'selectPlaylist 错误', e);
      _setError('加载歌单失败: $e');
    } finally {
      _setLoading(false);
    }
    AppLogger.d('PlaylistProvider#selectPlaylist', '========== 完成 ==========');
  }

  /// 取消选择歌单
  void deselectPlaylist() {
    _selectedPlaylist = null;
    _selectedPlaylistSongs = [];
    notifyListeners();
  }

  /// 更新歌单名称
  Future<bool> updatePlaylistName(int playlistId, String newName) async {
    try {
      final success = await _repository.updatePlaylistName(playlistId, newName);
      if (success) {
        final index = _playlists.indexWhere((p) => p.id == playlistId);
        if (index != -1) {
          _playlists[index] = _playlists[index].copyWith(
            name: newName,
            updatedAt: DateTime.now(),
          );
          // 移到列表开头（最近更新）
          final playlist = _playlists.removeAt(index);
          _playlists.insert(0, playlist);
          notifyListeners();
        }
      }
      return success;
    } catch (e) {
      _setError('更新歌单失败: $e');
      return false;
    }
  }

  /// 删除歌单
  Future<bool> deletePlaylist(int playlistId) async {
    try {
      final success = await _repository.deletePlaylist(playlistId);
      if (success) {
        _playlists.removeWhere((p) => p.id == playlistId);
        if (_selectedPlaylist?.id == playlistId) {
          _selectedPlaylist = null;
          _selectedPlaylistSongs = [];
        }
        notifyListeners();
      }
      return success;
    } catch (e) {
      _setError('删除歌单失败: $e');
      return false;
    }
  }

  /// 搜索歌单
  Future<List<Playlist>> searchPlaylists(String query) async {
    if (query.isEmpty) return _playlists;
    return await _repository.searchPlaylists(query);
  }

  // ==================== 歌单歌曲操作 ====================

  /// 添加歌曲到歌单
  Future<bool> addSongToPlaylist(int playlistId, Song song) async {
    try {
      final success = await _repository.addSongToPlaylist(playlistId, song);
      if (success) {
        // 更新本地状态
        final index = _playlists.indexWhere((p) => p.id == playlistId);
        if (index != -1) {
          final updatedSongs = <Song>[...(_playlists[index].songs ?? []), song];
          _playlists[index] = _playlists[index].copyWith(
            songs: updatedSongs,
            updatedAt: DateTime.now(),
          );
        }
        if (_selectedPlaylist?.id == playlistId) {
          _selectedPlaylistSongs.add(song);
        }
        notifyListeners();
      }
      return success;
    } catch (e) {
      _setError('添加歌曲失败: $e');
      return false;
    }
  }

  /// 批量添加歌曲到歌单
  Future<int> addSongsToPlaylist(int playlistId, List<Song> songs) async {
    try {
      final count = await _repository.addSongsToPlaylist(playlistId, songs);
      if (count > 0) {
        // 重新加载歌单
        await _loadPlaylists();
        if (_selectedPlaylist?.id == playlistId) {
          await selectPlaylist(playlistId);
        }
      }
      return count;
    } catch (e) {
      _setError('添加歌曲失败: $e');
      return 0;
    }
  }

  /// 从歌单移除歌曲
  Future<bool> removeSongFromPlaylist(int playlistId, int songId) async {
    try {
      final success = await _repository.removeSongFromPlaylist(playlistId, songId);
      if (success) {
        // 更新本地状态
        final index = _playlists.indexWhere((p) => p.id == playlistId);
        if (index != -1) {
          final updatedSongs = _playlists[index].songs
              ?.where((s) => s.id != songId)
              .toList();
          _playlists[index] = _playlists[index].copyWith(
            songs: updatedSongs,
            updatedAt: DateTime.now(),
          );
        }
        if (_selectedPlaylist?.id == playlistId) {
          _selectedPlaylistSongs.removeWhere((s) => s.id == songId);
        }
        notifyListeners();
      }
      return success;
    } catch (e) {
      _setError('移除歌曲失败: $e');
      return false;
    }
  }

  /// 检查歌曲是否在歌单中
  Future<bool> isSongInPlaylist(int playlistId, int songId) async {
    return await _repository.isSongInPlaylist(playlistId, songId);
  }

  /// 移动歌曲位置
  Future<bool> moveSongPosition(
    int playlistId,
    int songId,
    int newPosition,
  ) async {
    try {
      final success = await _repository.moveSongPosition(
        playlistId,
        songId,
        newPosition,
      );
      if (success && _selectedPlaylist?.id == playlistId) {
        await selectPlaylist(playlistId);
      }
      return success;
    } catch (e) {
      _setError('移动歌曲失败: $e');
      return false;
    }
  }

  // ==================== 歌曲操作 ====================

  /// 保存歌曲
  Future<Song?> saveSong(Song song) async {
    try {
      final saved = await _repository.saveSong(song);
      // 检查是否是新歌曲
      if (!_allSongs.any((s) => s.id == saved.id)) {
        _allSongs.add(saved);
        notifyListeners();
      }
      return saved;
    } catch (e) {
      _setError('保存歌曲失败: $e');
      return null;
    }
  }

  /// 批量保存歌曲
  Future<List<Song>> saveSongs(List<Song> songs) async {
    try {
      final saved = await _repository.saveSongs(songs);
      await _loadAllSongs(); // 重新加载以获取正确顺序
      return saved;
    } catch (e) {
      _setError('保存歌曲失败: $e');
      return [];
    }
  }

  /// 删除歌曲
  /// [songId] 歌曲 ID
  /// [deleteFile] 是否同时删除文件系统中的原文件
  Future<bool> deleteSong(int songId, {bool deleteFile = false}) async {
    try {
      // 如果需要删除文件，先获取歌曲信息
      if (deleteFile) {
        final song = await _repository.getSongById(songId);
        if (song != null) {
          await FileUtils.deleteFile(song.filePath);
        }
      }

      final success = await _repository.deleteSong(songId);
      if (success) {
        _allSongs.removeWhere((s) => s.id == songId);
        _playHistory.removeWhere((s) => s.id == songId);
        // 从所有歌单中移除
        for (var i = 0; i < _playlists.length; i++) {
          if (_playlists[i].songs != null) {
            final updatedSongs = _playlists[i].songs!
                .where((s) => s.id != songId)
                .toList();
            _playlists[i] = _playlists[i].copyWith(songs: updatedSongs);
          }
        }
        if (_selectedPlaylistSongs.any((s) => s.id == songId)) {
          _selectedPlaylistSongs.removeWhere((s) => s.id == songId);
        }
        notifyListeners();
      }
      return success;
    } catch (e) {
      _setError('删除歌曲失败: $e');
      return false;
    }
  }

  /// 搜索歌曲
  Future<List<Song>> searchSongs(String query) async {
    if (query.isEmpty) return _allSongs;
    return await _repository.searchSongs(query);
  }

  /// 根据 ID 获取歌曲
  Future<Song?> getSongById(int id) async {
    return await _repository.getSongById(id);
  }

  // ==================== 播放历史操作 ====================

  /// 记录播放历史
  Future<void> recordPlayHistory(int songId, {int? playDuration}) async {
    await _repository.recordPlayHistory(songId, playDuration: playDuration);
    await _loadPlayHistory();
  }

  /// 清空播放历史
  Future<void> clearPlayHistory() async {
    await _repository.clearPlayHistory();
    _playHistory = [];
    notifyListeners();
  }

  // ==================== 辅助方法 ====================

  /// 设置加载状态
  void _setLoading(bool loading) {
    _isLoading = loading;
    if (loading) _error = null;
    notifyListeners();
  }

  /// 设置错误信息
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  /// 清除错误
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// 获取歌单统计信息
  Map<String, dynamic> getStatistics() {
    int totalSongs = _allSongs.length;
    int totalPlaylists = _playlists.length;
    int totalDuration = _allSongs.fold(0, (sum, song) => sum + (song.duration ?? 0));

    return {
      'totalSongs': totalSongs,
      'totalPlaylists': totalPlaylists,
      'totalDuration': totalDuration,
      'formattedTotalDuration': _formatTotalDuration(totalDuration),
    };
  }

  /// 格式化总时长
  String _formatTotalDuration(int milliseconds) {
    if (milliseconds == 0) return '00:00';

    final hours = milliseconds ~/ 3600000;
    final minutes = (milliseconds % 3600000) ~/ 60000;

    if (hours > 0) {
      return '$hours 小时 $minutes 分钟';
    }
    return '$minutes 分钟';
  }

  @override
  void dispose() {
    super.dispose();
  }
}
