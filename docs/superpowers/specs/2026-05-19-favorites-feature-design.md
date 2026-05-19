# 我喜欢听功能设计

## 功能概述

在主页歌曲名称右侧添加爱心按钮，实现"我喜欢听"收藏功能：
- 默认状态：白色线框爱心
- 已收藏状态：红色实心爱心
- 设置页面新增系统歌单"我喜欢听"，位于"我的歌单"上方

## 架构设计

### 数据层

**存储方案**：复用现有 `playlists` 和 `playlist_songs` 表

"我喜欢听"作为特殊的系统歌单存储：
- `playlists.is_system = 1` 标识为系统歌单
- 歌单名称：`我喜欢听`
- 通过 `playlist_songs` 关联歌曲

**PlaylistRepository 扩展方法**：

```dart
/// 获取"我喜欢听"歌单
Future<Playlist?> getFavoritesPlaylist()

/// 创建"我喜欢听"系统歌单
Future<Playlist> createFavoritesPlaylist()

/// 确保收藏歌单存在（不存在则创建）
Future<Playlist> ensureFavoritesPlaylistExists()

/// 检查歌曲是否已收藏
Future<bool> isSongFavorite(int songId)

/// 添加歌曲到收藏
Future<bool> addToFavorites(Song song)

/// 从收藏移除歌曲
Future<bool> removeFromFavorites(int songId)
```

### Provider 层

**PlaylistProvider 扩展**：

```dart
/// 收藏歌单对象
Playlist? _favoritesPlaylist;
Playlist? get favoritesPlaylist;

/// 已收藏歌曲 ID 集合（用于快速判断，避免频繁数据库查询）
Set<int> _favoriteSongIds = {};
Set<int> get favoriteSongIds;

/// 切换收藏状态
Future<void> toggleFavorite(Song song)

/// 刷新收藏数据
Future<void> refreshFavorites()

/// 确保收藏歌单存在
Future<void> ensureFavoritesPlaylistExists()
```

### UI 层

#### 主页歌曲信息区域

修改 `_buildSongInfo` 方法，将歌曲名称和爱心按钮放在同一行：

```
[歌曲名称                    ❤]
[艺术家 · 专辑                  ]
```

**`_FavoriteButton` 组件**：
- 尺寸：24px
- 未收藏：`Icons.favorite_border_rounded`，白色
- 已收藏：`Icons.favorite_rounded`，红色 (`#EF4444`)
- Hover 效果：scale 1.1
- 点击后显示 Toast 提示

#### 设置抽屉

在"我的歌单"标题上方新增"我喜欢听"入口：

```
[播放模式区域]

[我喜欢听]  ← 红色渐变图标，显示收藏数量
  [全部歌曲]
  [其他歌单...]

[我的歌单]
  [歌单列表...]
```

### 启动初始化

在 `_HomePageState.initState` 中调用：
```dart
await playlistProvider.ensureFavoritesPlaylistExists();
await playlistProvider.refreshFavorites();
```

## 数据流

```
用户点击爱心
    ↓
PlaylistProvider.toggleFavorite(song)
    ↓
检查 favoriteSongIds.contains(song.id)
    ↓
┌─────────────────┬─────────────────┐
│ 未收藏          │ 已收藏          │
├─────────────────┼─────────────────┤
│ addToFavorites  │ removeFromFavorites
│ 更新 favoriteSongIds │ 更新 favoriteSongIds
│ Toast: "已添加到我喜欢" │ Toast: "已从我喜欢移除"
└─────────────────┴─────────────────┘
    ↓
notifyListeners() → UI 刷新
```

## 视觉规范

### 爱心按钮

| 状态 | 图标 | 颜色 | 尺寸 |
|------|------|------|------|
| 未收藏 | `favorite_border_rounded` | `#FFFFFF` (白色) | 24px |
| 已收藏 | `favorite_rounded` | `#EF4444` (红色) | 24px |
| Hover (未收藏) | `favorite_border_rounded` | `#10B981` (accent) | 26.4px (scale 1.1) |
| Hover (已收藏) | `favorite_rounded` | `#EF4444` (红色) | 26.4px (scale 1.1) |

### "我喜欢听"歌单图标

- 尺寸：40px 圆角矩形 (8px radius)
- 背景：渐变 `LinearGradient(colors: [Color(0xFFF43F5E), Color(0xFFEC4899)])`
- 图标：`Icons.favorite_rounded`，白色，20px

## 文件变更清单

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `lib/features/playlist/data/playlist_repository.dart` | 扩展 | 新增收藏相关方法 |
| `lib/features/playlist/presentation/providers/playlist_provider.dart` | 扩展 | 新增收藏状态管理 |
| `lib/main.dart` | 修改 | 修改 `_buildSongInfo`，新增 `_FavoriteButton` 组件 |
| `lib/shared/widgets/app_drawer.dart` | 修改 | 新增"我喜欢听"入口 |

## 实现顺序

1. **数据层** - 扩展 `PlaylistRepository`
2. **Provider 层** - 扩展 `PlaylistProvider`
3. **UI 层 - 主页** - 修改 `_buildSongInfo`，新增 `_FavoriteButton`
4. **UI 层 - 抽屉** - 新增"我喜欢听"入口
5. **初始化** - 在应用启动时确保收藏歌单存在

## 测试要点

- [ ] 首次启动时自动创建"我喜欢听"歌单
- [ ] 点击爱心添加收藏，爱心变红，Toast 显示"已添加到我喜欢"
- [ ] 点击红色爱心移除收藏，爱心变白，Toast 显示"已从我喜欢移除"
- [ ] 收藏的歌曲在"我喜欢听"歌单中显示
- [ ] 从"我喜欢听"歌单中删除歌曲，主页爱心状态同步更新
- [ ] 应用重启后收藏状态正确恢复
