# 首页搜索功能 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在首页顶部栏添加搜索入口，点击展开搜索栏，首页内容区切换为搜索结果列表。

**Architecture:** 在 `_MyHomePageState` 中内嵌搜索模式状态，点击搜索图标时顶部栏原地变为搜索输入框，内容区替换为搜索结果。退出搜索模式时恢复原始首页。复用已有的 `PlaylistProvider.searchSongs()` 进行数据库查询。

**Tech Stack:** Flutter, Provider (ChangeNotifier), dart:async (Timer), sqflite (SQL LIKE search)

---

## File Structure

| File | Responsibility | Change Type |
|------|----------------|-------------|
| `lib/main.dart` | 首页搜索模式状态、顶部栏搜索/正常切换、内容区搜索/正常切换 | Modify |

No new files. All changes go into `_MyHomePageState` within `lib/main.dart`.

---

### Task 1: Add search state fields and lifecycle management

**Files:**
- Modify: `mysic_flutter/lib/main.dart:1-8` (add `dart:async` import)
- Modify: `mysic_flutter/lib/main.dart:107-228` (state fields, initState, dispose)

- [ ] **Step 1: Add `dart:async` import**

Add `import 'dart:async';` after the existing `import 'dart:io';` line (line 7):

```dart
import 'dart:io';
import 'dart:async';
```

- [ ] **Step 2: Add search state fields to `_MyHomePageState`**

After the existing fields at lines 108-111 (`_fabAnimationController`, `_isScanning`, `_currentScanner`, `_playerProvider`), add:

```dart
  // 搜索状态
  bool _isSearchMode = false;
  String _searchQuery = '';
  List<Song> _searchResults = [];
  Timer? _debounceTimer;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
```

- [ ] **Step 3: Add cleanup in `dispose()`**

In the existing `dispose()` method (lines 223-228), add before `_fabAnimationController.dispose()`:

```dart
  @override
  void dispose() {
    _playerProvider?.onSongCompleted = null;
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }
```

- [ ] **Step 4: Verify the app still builds**

Run: `cd mysic_flutter && flutter analyze`
Expected: No errors related to the new fields.

- [ ] **Step 5: Commit**

```bash
git add mysic_flutter/lib/main.dart
git commit -m "feat(search): 添加搜索状态字段和生命周期管理"
```

---

### Task 2: Add search mode enter/exit and debounce logic

**Files:**
- Modify: `mysic_flutter/lib/main.dart` (add methods after `dispose()`)

- [ ] **Step 1: Add `_enterSearchMode` method**

After `dispose()` (currently at line ~228), add:

```dart
  void _enterSearchMode() {
    setState(() {
      _isSearchMode = true;
      _searchQuery = '';
      _searchResults = [];
    });
    // 延迟请求焦点，确保搜索框已渲染
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }
```

- [ ] **Step 2: Add `_exitSearchMode` method**

```dart
  void _exitSearchMode() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() {
      _isSearchMode = false;
      _searchQuery = '';
      _searchResults = [];
    });
  }
```

- [ ] **Step 3: Add `_onSearchChanged` method with debounce**

```dart
  void _onSearchChanged(String query) {
    // 立即 setState 以更新清除按钮的可见性
    setState(() {});

    _debounceTimer?.cancel();
    if (query.isEmpty) {
      setState(() {
        _searchQuery = '';
        _searchResults = [];
      });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final playlistProvider = context.read<PlaylistProvider>();
      final results = await playlistProvider.searchSongs(query);
      if (mounted && _isSearchMode) {
        setState(() {
          _searchQuery = query;
          _searchResults = results;
        });
      }
    });
  }
```

Note: Using `PlaylistProvider.searchSongs()` instead of raw `PlaylistRepository()` so the search uses the provider's cached `_allSongs` for empty queries and delegates to repository for non-empty queries. The initial `setState(() {})` ensures the clear button visibility updates immediately on every keystroke.

- [ ] **Step 4: Verify the app still builds**

Run: `cd mysic_flutter && flutter analyze`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add mysic_flutter/lib/main.dart
git commit -m "feat(search): 添加搜索模式进入/退出和防抖搜索逻辑"
```

---

### Task 3: Modify `_buildTopBar` to support search mode

**Files:**
- Modify: `mysic_flutter/lib/main.dart:490-563` (`_buildTopBar` method)

- [ ] **Step 1: Replace `_buildTopBar` with search-mode branching**

Replace the entire `_buildTopBar` method (lines 490-563) with:

```dart
  Widget _buildTopBar(BuildContext context) {
    if (_isSearchMode) {
      return _buildSearchTopBar(context);
    }
    return _buildNormalTopBar(context);
  }
```

- [ ] **Step 2: Add `_buildNormalTopBar` method**

Extract the existing top bar content into `_buildNormalTopBar`, adding the search icon button:

```dart
  Widget _buildNormalTopBar(BuildContext context) {
    return Consumer2<PlayerProvider, ApiConfigProvider>(
      builder: (context, playerProvider, apiConfigProvider, child) {
        final currentSong = playerProvider.currentSong;
        final playlistName = playerProvider.playlistName;
        final hasEnabledApi = apiConfigProvider.enabledConfig != null;
        return Padding(
          padding: const EdgeInsets.only(left: 0, right: 0, top: 16, bottom: 16),
          child: Stack(
            children: [
              // 文字层 - 绝对居中于屏幕
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '正在播放',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF71717A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      playlistName.isNotEmpty ? playlistName : '全部歌曲',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // 按钮层 - 左右分布
              Row(
                children: [
                  // 抽屉按钮
                  _TopBarButton(
                    icon: Icons.menu_rounded,
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),

                  const Spacer(),

                  // 搜索按钮
                  _TopBarButton(
                    icon: Icons.search_rounded,
                    onPressed: _enterSearchMode,
                  ),

                  // 魔法棒按钮
                  if (hasEnabledApi) ...[
                    const SizedBox(width: 0),
                    MagicWandButton(
                      visible: currentSong != null,
                      onTap: () => _showSkillSelection(context, currentSong!),
                    ),
                  ],

                  // 加号按钮
                  _AddButton(
                    currentSong: currentSong,
                    onAddToPlaylist: () => _showAddToPlaylist(context, currentSong!),
                    onEdit: () => _showEditSongDialog(context, currentSong!),
                    onDelete: () => _showDeleteConfirmSheet(context, currentSong!),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
```

Note: The search icon is placed right before the magic wand button (or `+` button when no API is enabled), matching the design spec: `[菜单] ... [魔法棒] [🔍] [+]`.

- [ ] **Step 3: Add `_buildSearchTopBar` method**

```dart
  Widget _buildSearchTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 0, right: 0, top: 16, bottom: 16),
      child: Row(
        children: [
          // 返回按钮
          _TopBarButton(
            icon: Icons.arrow_back_rounded,
            onPressed: _exitSearchMode,
          ),

          // 搜索输入框
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: '搜索歌曲、艺术家...',
                  hintStyle: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.muted,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ),

          // 清除按钮（仅当有输入内容时显示）
          if (_searchController.text.isNotEmpty)
            _TopBarButton(
              icon: Icons.close_rounded,
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
        ],
      ),
    );
  }
```

- [ ] **Step 4: Verify the app still builds**

Run: `cd mysic_flutter && flutter analyze`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add mysic_flutter/lib/main.dart
git commit -m "feat(search): 顶部栏支持搜索模式切换"
```

---

### Task 4: Modify `_buildBody` to support search content

**Files:**
- Modify: `mysic_flutter/lib/main.dart:296-488` (`_buildBody` method)

- [ ] **Step 1: Add search-mode branching in `_buildBody`**

After the top bar line (`_buildTopBar(context)`) in `_buildBody`, add a conditional for the content area. The current `_buildBody` structure is:

```
SafeArea → Column → [_buildTopBar, Expanded(Column[...])]
```

Replace the `Expanded` content section (from line ~303 onward) with a conditional:

Find the line `_buildTopBar(context),` (around line 301) and after that, replace the `Expanded` block that starts right after. The key change: wrap the main content `Expanded` widget to conditionally show search content:

```dart
  Widget _buildBody(BuildContext context, PlayerProvider playerProvider) {
    return SafeArea(
      child: Column(
        children: [
          // 顶部栏
          _buildTopBar(context),

          // 主内容区
          Expanded(
            child: _isSearchMode
                ? _buildSearchContent(context, playerProvider)
                : Column(
                    children: [
                      // 有边距的内容区域
                      Expanded(
                        child: Column(
                          // ... existing normal content unchanged ...
```

The rest of the existing normal content remains exactly the same. Only the top-level `Expanded` inside `Column` now has the `_isSearchMode` conditional.

- [ ] **Step 2: Add `_buildSearchContent` method**

```dart
  Widget _buildSearchContent(BuildContext context, PlayerProvider playerProvider) {
    // 无搜索词 - 提示页
    if (_searchQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_rounded,
              size: 64,
              color: AppColors.muted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '搜索歌曲或艺术家',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      );
    }

    // 无搜索结果 - 空状态
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_off_rounded,
              size: 64,
              color: AppColors.muted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '未找到相关歌曲',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      );
    }

    // 搜索结果列表
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final song = _searchResults[index];
        return _SearchResultTile(
          song: song,
          onTap: () async {
            // 播放搜索到的歌曲
            final playlistProvider = context.read<PlaylistProvider>();
            await playerProvider.setPlaylist(
              _searchResults,
              startIndex: index,
              autoPlay: true,
              playlistName: '搜索: $_searchQuery',
            );
            // 退出搜索模式
            _exitSearchMode();
          },
          onLongPress: () {
            // 弹出操作菜单（添加到歌单、编辑、删除）
            _showSongActionMenu(context, song);
          },
        );
      },
    );
  }
```

- [ ] **Step 3: Add `_showSongActionMenu` helper**

This delegates to existing methods for add/edit/delete:

```dart
  void _showSongActionMenu(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.muted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // 歌曲信息
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.music_note_rounded, color: AppColors.accent, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          song.displayArtist,
                          style: TextStyle(color: AppColors.muted, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.playlist_add_rounded, color: AppColors.accent),
              title: Text('添加到歌单', style: TextStyle(color: AppColors.white)),
              onTap: () {
                Navigator.pop(context);
                _showAddToPlaylist(context, song);
              },
            ),
            ListTile(
              leading: Icon(Icons.edit_rounded, color: AppColors.white),
              title: Text('编辑', style: TextStyle(color: AppColors.white)),
              onTap: () {
                Navigator.pop(context);
                _showEditSongDialog(context, song);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_rounded, color: const Color(0xFFEF4444)),
              title: Text('删除', style: TextStyle(color: const Color(0xFFEF4444))),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmSheet(context, song);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 4: Add `_SearchResultTile` widget**

Add this private widget class after `_TopBarButton` (near end of file):

```dart
/// 搜索结果歌曲项
class _SearchResultTile extends StatefulWidget {
  final Song song;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SearchResultTile({
    required this.song,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends State<_SearchResultTile> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _isHovering ? AppColors.cardHover : AppColors.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.music_note_rounded,
                color: AppColors.accent,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.song.title,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      widget.song.displayArtist,
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Verify the app builds and runs**

Run: `cd mysic_flutter && flutter analyze`
Expected: No errors.

Run: `cd mysic_flutter && flutter run -d windows`
Expected: App launches, search icon visible in top bar, clicking it switches top bar to search input, typing triggers search, clicking back arrow exits search mode.

- [ ] **Step 6: Commit**

```bash
git add mysic_flutter/lib/main.dart
git commit -m "feat(search): 内容区搜索结果展示和歌曲操作菜单"
```

---

### Task 5: Run tests and verify

**Files:**
- Test: `mysic_flutter/test/` (existing tests)

- [ ] **Step 1: Run all existing tests**

Run: `cd mysic_flutter && flutter test`
Expected: All existing tests pass. New search functionality does not break existing behavior.

- [ ] **Step 2: Run flutter analyze**

Run: `cd mysic_flutter && flutter analyze`
Expected: No warnings or errors.

- [ ] **Step 3: Manual verification checklist**

Verify on Windows desktop:
- [ ] Search icon visible in top bar (between magic wand and + button)
- [ ] Clicking search icon: top bar switches to search mode with input field
- [ ] Input field auto-focuses (keyboard appears)
- [ ] Typing text: results appear after ~300ms
- [ ] Empty search query: shows "搜索歌曲或艺术家" hint
- [ ] No results: shows "未找到相关歌曲" empty state
- [ ] Clicking a result: song plays, exits search mode
- [ ] Long pressing a result: shows action menu (add to playlist, edit, delete)
- [ ] Clear button: clears input, stays in search mode
- [ ] Back arrow: exits search mode, restores original top bar
- [ ] Exiting search: normal home page content restored