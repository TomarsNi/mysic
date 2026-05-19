# 我喜欢听功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在主页歌曲名称右侧添加爱心按钮，实现"我喜欢听"收藏功能，并在设置抽屉中新增"我喜欢听"系统歌单入口。

**Architecture:** 复用现有 `playlists` 和 `playlist_songs` 表存储收藏数据，"我喜欢听"作为特殊的系统歌单。通过 `PlaylistRepository` 扩展方法操作数据，`PlaylistProvider` 管理收藏状态，UI 层通过 Provider 响应式更新。

**Tech Stack:** Flutter, Provider (状态管理), SQLite (sqflite), 现有项目架构

---

## Task 1: 扩展 PlaylistRepository - 收藏相关方法

**Files:**
- Modify: `lib/features/playlist/data/playlist_repository.dart`
- Test: `test/playlist_repository_test.dart`

- [ ] **Step 1: 添加收藏歌单常量和获取方法**

在 `PlaylistRepository` 类中添加以下方法（在 `getSystemPlaylist` 方法后）：

```dart
/// 收藏歌单名称常量
static const String favoritesPlaylistName = '我喜欢听';

/// 获取"我喜欢听"歌单
Future<Playlist?> getFavoritesPlaylist() async {
  final db = await _db;
  final List<Map<String, dynamic>> maps = await db.query(
    DatabaseHelper.tablePlaylists,
    where: 'name = ? AND is_system = ?',
    whereArgs: [favoritesPlaylistName, 1],
    limit: 1,
  );

  if (maps.isEmpty) return null;

  final playlist = Playlist.fromMap(maps.first);
  final songs = await getSongsInPlaylist(playlist.id!);
  return playlist.copyWith(songs: songs);
}
```

- [ ] **Step 2: 添加创建收藏歌单方法**

```dart
/// 创建"我喜欢听"系统歌单
Future<Playlist> createFavoritesPlaylist() async {
  final db = await _db;
  final now = DateTime.now();

  final id = await db.insert(
    DatabaseHelper.tablePlaylists,
    {
      'name': favoritesPlaylistName,
      'description': '我喜欢的歌曲',
      'is_system': 1,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    },
  );

  return Playlist(
    id: id,
    name: favoritesPlaylistName,
    description: '我喜欢的歌曲',
    isSystem: true,
    createdAt: now,
    updatedAt: now,
    songs: [],
  );
}
```

- [ ] **Step 3: 添加确保收藏歌单存在方法**

```dart
/// 确保收藏歌单存在（不存在则创建）
Future<Playlist> ensureFavoritesPlaylistExists() async {
  final existing = await getFavoritesPlaylist();
  if (existing != null) return existing;
  return await createFavoritesPlaylist();
}
```

- [ ] **Step 4: 添加检查歌曲是否已收藏方法**

```dart
/// 检查歌曲是否已收藏
Future<bool> isSongFavorite(int songId) async {
  final favorites = await getFavoritesPlaylist();
  if (favorites == null) return false;
  return await isSongInPlaylist(favorites.id!, songId);
}
```

- [ ] **Step 5: 添加收藏歌曲方法**

```dart
/// 添加歌曲到收藏
Future<bool> addToFavorites(Song song) async {
  final favorites = await ensureFavoritesPlaylistExists();
  return await addSongToPlaylist(favorites.id!, song);
}
```

- [ ] **Step 6: 添加从收藏移除歌曲方法**

```dart
/// 从收藏移除歌曲
Future<bool> removeFromFavorites(int songId) async {
  final favorites = await getFavoritesPlaylist();
  if (favorites == null) return false;
  return await removeSongFromPlaylist(favorites.id!, songId);
}
```

- [ ] **Step 7: 编写单元测试**

在 `test/playlist_repository_test.dart` 文件末尾添加：

```dart
  group('PlaylistRepository 收藏功能测试', () {
    late PlaylistRepository repository;
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();
      repository = PlaylistRepository(dbHelper: dbHelper);
    });

    tearDown(() async {
      await dbHelper.close();
    });

    test('创建收藏歌单', () async {
      final favorites = await repository.createFavoritesPlaylist();

      expect(favorites.id, isNotNull);
      expect(favorites.name, equals('我喜欢听'));
      expect(favorites.isSystem, isTrue);
    });

    test('获取收藏歌单 - 不存在时返回 null', () async {
      final favorites = await repository.getFavoritesPlaylist();
      expect(favorites, isNull);
    });

    test('获取收藏歌单 - 存在时返回歌单', () async {
      await repository.createFavoritesPlaylist();
      final favorites = await repository.getFavoritesPlaylist();

      expect(favorites, isNotNull);
      expect(favorites!.name, equals('我喜欢听'));
    });

    test('确保收藏歌单存在 - 不存在时创建', () async {
      final favorites = await repository.ensureFavoritesPlaylistExists();

      expect(favorites.id, isNotNull);
      expect(favorites.name, equals('我喜欢听'));
    });

    test('确保收藏歌单存在 - 已存在时返回现有歌单', () async {
      final created = await repository.createFavoritesPlaylist();
      final found = await repository.ensureFavoritesPlaylistExists();

      expect(found.id, equals(created.id));
    });

    test('添加歌曲到收藏', () async {
      // 先创建歌曲
      final song = await repository.saveSong(Song(
        title: '测试歌曲',
        filePath: '/test/song.mp3',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final success = await repository.addToFavorites(song);
      expect(success, isTrue);

      final isFavorite = await repository.isSongFavorite(song.id!);
      expect(isFavorite, isTrue);
    });

    test('从收藏移除歌曲', () async {
      final song = await repository.saveSong(Song(
        title: '测试歌曲',
        filePath: '/test/song.mp3',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await repository.addToFavorites(song);
      final success = await repository.removeFromFavorites(song.id!);

      expect(success, isTrue);
      expect(await repository.isSongFavorite(song.id!), isFalse);
    });

    test('检查未收藏歌曲返回 false', () async {
      final song = await repository.saveSong(Song(
        title: '测试歌曲',
        filePath: '/test/song.mp3',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      expect(await repository.isSongFavorite(song.id!), isFalse);
    });
  });
```

- [ ] **Step 8: 运行测试验证**

Run: `cd mysic_flutter && flutter test test/playlist_repository_test.dart`

Expected: 所有测试通过

- [ ] **Step 9: Commit**

```bash
git add lib/features/playlist/data/playlist_repository.dart test/playlist_repository_test.dart
git commit -m "feat(playlist): 添加收藏歌单相关方法到 PlaylistRepository"
```

---

## Task 2: 扩展 PlaylistProvider - 收藏状态管理

**Files:**
- Modify: `lib/features/playlist/presentation/providers/playlist_provider.dart`
- Test: `test/playlist_provider_test.dart`

- [ ] **Step 1: 添加收藏相关状态变量**

在 `PlaylistProvider` 类的状态变量区域（约第 18 行后）添加：

```dart
  Playlist? _favoritesPlaylist; // 收藏歌单
  Set<int> _favoriteSongIds = {}; // 已收藏歌曲 ID 缓存
```

- [ ] **Step 2: 添加收藏相关 Getters**

在现有 Getters 区域（约第 40 行后）添加：

```dart
  Playlist? get favoritesPlaylist => _favoritesPlaylist;
  Set<int> get favoriteSongIds => Set.unmodifiable(_favoriteSongIds);
```

- [ ] **Step 3: 添加确保收藏歌单存在方法**

在 `_ensureSystemPlaylistExists` 方法后添加：

```dart
  /// 确保收藏歌单存在
  Future<void> ensureFavoritesPlaylistExists() async {
    debugPrint('========== ensureFavoritesPlaylistExists 开始 ==========');
    _favoritesPlaylist = await _repository.getFavoritesPlaylist();

    if (_favoritesPlaylist == null) {
      _favoritesPlaylist = await _repository.createFavoritesPlaylist();
      debugPrint('创建新的收藏歌单，ID: ${_favoritesPlaylist?.id}');
    } else {
      debugPrint('已存在收藏歌单，ID: ${_favoritesPlaylist?.id}');
    }

    // 加载收藏歌曲 ID
    await _loadFavoriteSongIds();
    debugPrint('========== ensureFavoritesPlaylistExists 结束 ==========');
  }

  /// 加载收藏歌曲 ID 列表
  Future<void> _loadFavoriteSongIds() async {
    if (_favoritesPlaylist == null) {
      _favoriteSongIds = {};
      return;
    }
    _favoriteSongIds = _favoritesPlaylist!.songs?.map((s) => s.id!).toSet() ?? {};
    debugPrint('加载收藏歌曲 ID，数量: ${_favoriteSongIds.length}');
  }
```

- [ ] **Step 4: 添加刷新收藏数据方法**

```dart
  /// 刷新收藏数据
  Future<void> refreshFavorites() async {
    _favoritesPlaylist = await _repository.getFavoritesPlaylist();
    await _loadFavoriteSongIds();
    notifyListeners();
  }
```

- [ ] **Step 5: 添加切换收藏状态方法**

```dart
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
          final updatedSongs = _favoritesPlaylist!.songs?.where((s) => s.id != songId).toList() ?? [];
          _favoritesPlaylist = _favoritesPlaylist!.copyWith(songs: updatedSongs);
        }
      }
    } else {
      success = await _repository.addToFavorites(song);
      if (success) {
        _favoriteSongIds.add(songId);
        // 更新歌单状态
        if (_favoritesPlaylist != null) {
          final updatedSongs = [..._favoritesPlaylist!.songs ?? [], song];
          _favoritesPlaylist = _favoritesPlaylist!.copyWith(songs: updatedSongs);
        }
      }
    }

    if (success) {
      notifyListeners();
    }
    return success;
  }
```

- [ ] **Step 6: 添加检查歌曲是否已收藏方法**

```dart
  /// 检查歌曲是否已收藏（同步方法，使用缓存）
  bool isSongFavorite(int songId) {
    return _favoriteSongIds.contains(songId);
  }
```

- [ ] **Step 7: 修改 _loadData 方法**

修改 `_loadData` 方法，在 `_ensureSystemPlaylistExists()` 后添加收藏歌单初始化：

```dart
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
```

- [ ] **Step 8: 编写单元测试**

在 `test/playlist_provider_test.dart` 文件末尾添加：

```dart
  group('PlaylistProvider 收藏功能测试', () {
    late PlaylistProvider provider;
    late PlaylistRepository repository;
    late DatabaseHelper dbHelper;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();
      repository = PlaylistRepository(dbHelper: dbHelper);
      provider = PlaylistProvider(repository: repository);
    });

    tearDown(() async {
      await dbHelper.close();
    });

    test('初始化时创建收藏歌单', () async {
      // 等待初始化完成
      await Future.delayed(const Duration(milliseconds: 500));

      expect(provider.favoritesPlaylist, isNotNull);
      expect(provider.favoritesPlaylist!.name, equals('我喜欢听'));
    });

    test('添加歌曲到收藏', () async {
      await Future.delayed(const Duration(milliseconds: 500));

      final song = await repository.saveSong(Song(
        title: '测试歌曲',
        filePath: '/test/song.mp3',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final success = await provider.toggleFavorite(song);
      expect(success, isTrue);
      expect(provider.isSongFavorite(song.id!), isTrue);
    });

    test('从收藏移除歌曲', () async {
      await Future.delayed(const Duration(milliseconds: 500));

      final song = await repository.saveSong(Song(
        title: '测试歌曲',
        filePath: '/test/song.mp3',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await provider.toggleFavorite(song);
      final success = await provider.toggleFavorite(song);

      expect(success, isTrue);
      expect(provider.isSongFavorite(song.id!), isFalse);
    });

    test('favoriteSongIds 正确更新', () async {
      await Future.delayed(const Duration(milliseconds: 500));

      final song1 = await repository.saveSong(Song(
        title: '歌曲1',
        filePath: '/test/song1.mp3',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      final song2 = await repository.saveSong(Song(
        title: '歌曲2',
        filePath: '/test/song2.mp3',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await provider.toggleFavorite(song1);
      await provider.toggleFavorite(song2);

      expect(provider.favoriteSongIds.length, equals(2));
      expect(provider.favoriteSongIds.contains(song1.id!), isTrue);
      expect(provider.favoriteSongIds.contains(song2.id!), isTrue);
    });
  });
```

- [ ] **Step 9: 运行测试验证**

Run: `cd mysic_flutter && flutter test test/playlist_provider_test.dart`

Expected: 所有测试通过

- [ ] **Step 10: Commit**

```bash
git add lib/features/playlist/presentation/providers/playlist_provider.dart test/playlist_provider_test.dart
git commit -m "feat(playlist): 添加收藏状态管理到 PlaylistProvider"
```

---

## Task 3: 添加爱心按钮组件到主页

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: 添加红色颜色常量**

在 `main.dart` 顶部常量区域（约第 40 行后）添加：

```dart
/// 收藏按钮红色
const Color _favoriteRed = Color(0xFFEF4444);
```

- [ ] **Step 2: 修改 _buildSongInfo 方法**

找到 `_buildSongInfo` 方法（约第 510 行），修改为包含爱心按钮的 Row 布局：

```dart
  Widget _buildSongInfo(Song? song) {
    return Consumer<PlaylistProvider>(
      builder: (context, playlistProvider, _) {
        final isFavorite = song?.id != null && playlistProvider.isSongFavorite(song!.id!);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 歌曲名称区域
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song?.title ?? '未选择歌曲',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    song != null
                        ? '${song.displayArtist} · ${song.displayAlbum}'
                        : '扫描本地音乐开始播放',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // 爱心按钮
            if (song != null)
              _FavoriteButton(
                isFavorite: isFavorite,
                onTap: () => _toggleFavorite(context, song),
              ),
          ],
        );
      },
    );
  }
```

- [ ] **Step 3: 添加 _toggleFavorite 方法**

在 `_buildSongInfo` 方法后添加：

```dart
  /// 切换收藏状态
  Future<void> _toggleFavorite(BuildContext context, Song song) async {
    final playlistProvider = context.read<PlaylistProvider>();
    final wasFavorite = playlistProvider.isSongFavorite(song.id!);

    final success = await playlistProvider.toggleFavorite(song);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasFavorite ? '已从我喜欢移除' : '已添加到我喜欢',
          ),
          backgroundColor: wasFavorite ? AppColors.muted : const Color(0xFFEF4444),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }
```

- [ ] **Step 4: 添加 _FavoriteButton 组件**

在文件末尾（`_AddButtonState` 类之后）添加：

```dart
/// 收藏按钮组件
/// 白色线框（未收藏）→ 红色实心（已收藏）
class _FavoriteButton extends StatefulWidget {
  final bool isFavorite;
  final VoidCallback onTap;

  const _FavoriteButton({
    required this.isFavorite,
    required this.onTap,
  });

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton> {
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 100),
          scale: _isPressed ? 0.9 : (_isHovering ? 1.1 : 1.0),
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Icon(
              widget.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: widget.isFavorite
                  ? _favoriteRed
                  : (_isHovering ? AppColors.accent : AppColors.white),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: 验证编译通过**

Run: `cd mysic_flutter && flutter analyze lib/main.dart`

Expected: 无错误

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart
git commit -m "feat(player): 添加爱心按钮到歌曲名称右侧"
```

---

## Task 4: 在设置抽屉添加"我喜欢听"入口

**Files:**
- Modify: `lib/shared/widgets/app_drawer.dart`

- [ ] **Step 1: 添加 favoritesPlaylist 参数**

在 `AppDrawer` 类的参数区域（约第 11 行后）添加：

```dart
  /// 收藏歌单
  final Playlist? favoritesPlaylist;

  /// 收藏歌单点击回调
  final Future<void> Function(Playlist)? onFavoritesTap;
```

- [ ] **Step 2: 更新构造函数**

更新构造函数（约第 35 行）：

```dart
  const AppDrawer({
    super.key,
    this.selectedPlaylistId,
    this.playlists = const [],
    this.favoritesPlaylist,
    this.onPlaylistTap,
    this.onFavoritesTap,
    this.onScanSettingsTap,
    this.onSettingsTap,
    this.onAboutTap,
    this.onApiSettingsTap,
    this.onCreatePlaylistTap,
  });
```

- [ ] **Step 3: 添加 _buildFavoritesSection 方法**

在 `_buildPlayModeSection` 方法后添加：

```dart
  Widget _buildFavoritesSection(BuildContext context) {
    final favoritesPlaylist = this.favoritesPlaylist;
    final songCount = favoritesPlaylist?.songs?.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '我喜欢听',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),

        // 收藏歌单入口
        if (favoritesPlaylist != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _FavoritesListTile(
              playlist: favoritesPlaylist,
              isSelected: selectedPlaylistId == favoritesPlaylist.id,
              onTap: () async {
                await onFavoritesTap?.call(favoritesPlaylist);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
      ],
    );
  }
```

- [ ] **Step 4: 添加 _FavoritesListTile 组件**

在 `_PlaylistListTileState` 类之后添加：

```dart
/// 收藏歌单列表项
/// 使用红色渐变图标
class _FavoritesListTile extends StatefulWidget {
  final Playlist playlist;
  final bool isSelected;
  final VoidCallback? onTap;

  const _FavoritesListTile({
    required this.playlist,
    this.isSelected = false,
    this.onTap,
  });

  @override
  State<_FavoritesListTile> createState() => _FavoritesListTileState();
}

class _FavoritesListTileState extends State<_FavoritesListTile> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Material(
        color: widget.isSelected
            ? AppColors.accent.withValues(alpha: 0.15)
            : _isHovering
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // 红色渐变图标
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppColors.roseGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: AppColors.white,
                    size: 20,
                  ),
                ),

                const SizedBox(width: 12),

                // 歌单信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.playlist.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: widget.isSelected ? AppColors.accent : AppColors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.playlist.songs?.length ?? 0} 首歌曲',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),

                // 选中指示器
                if (widget.isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: 修改 build 方法**

修改 `build` 方法，在 `_buildPlayModeSection` 和 `_buildPlaylistSection` 之间添加 `_buildFavoritesSection`：

```dart
  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.card,
      child: SafeArea(
        child: Column(
          children: [
            // 头部
            _buildHeader(context),

            // 播放模式选择区
            _buildPlayModeSection(context),

            // 收藏歌单入口
            _buildFavoritesSection(context),

            // 歌单列表（可滚动）
            Expanded(
              child: _buildPlaylistSection(context),
            ),

            // 底部区域
            _buildFooter(context),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 6: 验证编译通过**

Run: `cd mysic_flutter && flutter analyze lib/shared/widgets/app_drawer.dart`

Expected: 无错误

- [ ] **Step 7: Commit**

```bash
git add lib/shared/widgets/app_drawer.dart
git commit -m "feat(ui): 在设置抽屉添加我喜欢听入口"
```

---

## Task 5: 连接主页和抽屉的收藏功能

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: 更新 AppDrawer 调用**

找到 `build` 方法中的 `AppDrawer` 组件（约第 189 行），添加 `favoritesPlaylist` 和 `onFavoritesTap` 参数：

```dart
          drawer: AppDrawer(
            playlists: playlistProvider.playlists,
            selectedPlaylistId: playlistProvider.selectedPlaylist?.id,
            favoritesPlaylist: playlistProvider.favoritesPlaylist,
            onPlaylistTap: (playlist) async {
              // ... 现有代码保持不变
            },
            onFavoritesTap: (playlist) async {
              final playlistId = playlist.id;
              if (playlistId == null) return;

              // 记录最后播放的歌单
              final repository = PlaylistRepository();
              await repository.setAppState('last_playlist_id', playlistId.toString());

              // 选择歌单
              await playlistProvider.selectPlaylist(playlistId);

              // 获取歌曲列表
              final songs = playlistProvider.selectedPlaylistSongs;

              if (songs.isNotEmpty) {
                await playerProvider.setPlaylist(songs, autoPlay: true);
              }
            },
            onScanSettingsTap: () => _showScanSettings(context),
            onSettingsTap: () => _showSettings(context),
            onAboutTap: () => _showAbout(context),
            onApiSettingsTap: () => _showApiSettings(context),
            onCreatePlaylistTap: () => _createPlaylist(context),
          ),
```

- [ ] **Step 2: 验证编译通过**

Run: `cd mysic_flutter && flutter analyze lib/main.dart`

Expected: 无错误

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: 连接主页和抽屉的收藏功能"
```

---

## Task 6: 运行完整测试和手动验证

**Files:**
- 无文件修改

- [ ] **Step 1: 运行所有单元测试**

Run: `cd mysic_flutter && flutter test`

Expected: 所有测试通过

- [ ] **Step 2: 运行应用进行手动测试**

Run: `cd mysic_flutter && flutter run -d windows`

手动测试清单：
- [ ] 首次启动时自动创建"我喜欢听"歌单
- [ ] 点击爱心添加收藏，爱心变红，Toast 显示"已添加到我喜欢"
- [ ] 点击红色爱心移除收藏，爱心变白，Toast 显示"已从我喜欢移除"
- [ ] 收藏的歌曲在"我喜欢听"歌单中显示
- [ ] 从"我喜欢听"歌单中删除歌曲，主页爱心状态同步更新
- [ ] 应用重启后收藏状态正确恢复

- [ ] **Step 3: 最终 Commit**

```bash
git add -A
git commit -m "feat: 完成我喜欢听功能"
```

---

## 实现总结

本计划实现了以下功能：

1. **数据层**：扩展 `PlaylistRepository`，新增收藏歌单的 CRUD 方法
2. **Provider 层**：扩展 `PlaylistProvider`，管理收藏状态和歌曲 ID 缓存
3. **UI 层 - 主页**：在歌曲名称右侧添加爱心按钮，支持切换收藏状态
4. **UI 层 - 抽屉**：新增"我喜欢听"入口，使用红色渐变图标

所有代码都遵循现有项目架构和设计规范。
