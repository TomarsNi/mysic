# 自动播放上次歌单功能设计

## 概述

打开应用时自动播放上次播放的歌单中的歌曲。如果无记录，默认播放"本地音乐"歌单。

## 需求

- 记录用户最后播放的歌单
- 应用启动时自动恢复播放
- 无记录时默认播放"本地音乐"歌单
- 播放逻辑与用户点击歌单一致（随机/顺序由已有逻辑控制）
- 歌曲从头开始播放，不记住播放进度

## 数据层

### 新建 `app_state` 表

```sql
CREATE TABLE app_state (
  key TEXT PRIMARY KEY,
  value TEXT
);
```

存储键值对：
- `last_playlist_id`: 最后播放的歌单 ID（字符串形式）

### 数据库版本

从版本 2 升级到版本 3。

## 业务逻辑

### 记录时机

用户点击歌单播放时，保存 `last_playlist_id` 到 `app_state` 表。

### 恢复流程

应用启动时执行：

1. 查询 `app_state` 获取 `last_playlist_id`
2. 如果存在 → 加载该歌单
3. 如果不存在 → 查找名称为"本地音乐"的歌单
4. 如果歌单存在且有歌曲 → 调用现有播放逻辑，开始播放
5. 如果歌单不存在或为空 → 不播放，静默处理

### 错误处理

- 歌单已被删除 → 回退到"本地音乐"歌单
- "本地音乐"歌单不存在或为空 → 不播放

## 文件变更

| 文件 | 变更内容 |
|------|----------|
| `lib/core/database/database_helper.dart` | 新增 `app_state` 表，版本升级到 3 |
| `lib/features/playlist/data/playlist_repository.dart` | 新增 `getAppState(key)`、`setAppState(key, value)` 方法 |
| `lib/main.dart` | 播放歌单时记录状态；启动时调用恢复播放逻辑 |

## 实现细节

### PlaylistRepository 新增方法

```dart
Future<String?> getAppState(String key);
Future<void> setAppState(String key, String value);
```

### main.dart 变更

1. `_HomePageState.initState` 中添加启动恢复逻辑
2. `onPlaylistTap` 回调中添加保存 `last_playlist_id` 逻辑
3. 新增 `_restoreLastPlaylist()` 方法处理恢复播放

## 不在范围内

- 记住播放进度
- 记住歌曲索引
- 在 `app_state` 中存储随机模式
