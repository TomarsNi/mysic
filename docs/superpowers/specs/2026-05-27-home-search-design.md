# 首页搜索功能设计

## 概述

在首页顶部栏 `+` 按钮左侧添加搜索入口，点击后顶部栏原地变为搜索输入框，首页内容区从歌单列表切换为搜索结果列表，退出搜索模式后恢复原始首页。

## 搜索范围

仅搜索歌曲，匹配歌曲名称和艺术家名称。使用已有的 `SongRepository.searchSongs(query)` 方法。

## 交互设计

### 顶部栏 - 正常模式

```
[菜单]  ...  正在播放 / 全部歌曲  ...  [魔法棒] [🔍] [+]
```

- 在 `+` 按钮左侧新增搜索图标 `Icons.search_rounded`
- 搜索图标使用与 `+` 按钮相同的 `_TopBarButton` 样式

### 顶部栏 - 搜索模式

```
[← 返回]  [🔍 搜索歌曲、艺术家...        ]  [✕ 清除]
```

- 点击搜索图标 → 进入搜索模式
- 顶部栏变为：返回箭头 + 搜索输入框 + 清除按钮
- 搜索框自动获取焦点，弹出软键盘
- 输入内容实时触发搜索（300ms 防抖）
- 点击返回箭头 → 退出搜索模式，清空搜索状态，恢复原始顶部栏
- 点击清除按钮 → 清空输入内容，保留搜索模式

### 搜索模式下的顶部栏样式

- 返回按钮：`Icons.arrow_back_rounded`，使用 `_TopBarButton` 样式
- 搜索框：`TextField`，背景 `AppColors.card`，圆角 `12`，提示文字 "搜索歌曲、艺术家..."
- 清除按钮：`Icons.close_rounded`，仅当输入非空时显示

### 内容区 - 搜索模式

**有搜索词 + 有结果**：
- 显示搜索结果列表
- 每项显示歌曲名 + 艺术家名
- 点击歌曲 → 开始播放
- 长按歌曲 → 弹出操作菜单（添加到歌单、编辑、删除），复用现有逻辑

**有搜索词 + 无结果**：
- 居中显示空状态图标 + "未找到相关歌曲"

**无搜索词**：
- 居中显示搜索图标 + "搜索歌曲或艺术家" 提示文字

### 退出搜索模式

- 清空 `_searchQuery`
- 清空 `_searchResults`
- 取消防抖定时器
- 恢复原始顶部栏

## 状态管理

### 新增状态（`_MyHomePageState`）

| 字段 | 类型 | 用途 |
|------|------|------|
| `_isSearchMode` | `bool` | 是否处于搜索模式 |
| `_searchQuery` | `String` | 当前搜索词 |
| `_searchResults` | `List<Song>` | 搜索结果列表 |
| `_debounceTimer` | `Timer?` | 300ms 防抖定时器 |
| `_searchController` | `TextEditingController` | 搜索输入控制器 |
| `_searchFocusNode` | `FocusNode` | 搜索框焦点控制 |

### 数据流

```
用户输入 → _searchController.onChanged → 防抖 300ms → SongRepository.searchSongs(query)
                                                        ↓
                                                 _searchResults 更新
                                                        ↓
                                                 setState() UI 重建
```

## 组件结构

### `_buildTopBar` 分支

```
_buildTopBar()
  ├─ 正常模式 → 现有布局 + 搜索图标
  └─ 搜索模式 → 返回箭头 + 搜索输入框 + 清除按钮
```

### `_buildBody` 分支

```
_buildBody()
  ├─ 正常模式 → 现有首页内容（专辑封面 + 歌曲信息 + 控制区）
  └─ 搜索模式 → _buildSearchContent()
                   ├─ 无搜索词 → 搜索提示页
                   ├─ 无结果 → 空状态页
                   └─ 有结果 → 歌曲列表
```

## 搜索方法

复用已有的 `PlaylistRepository.searchSongs(query)`，该方法通过 SQL LIKE 查询 `title`、`artist`、`album` 三个字段。

防抖实现：

```dart
void _onSearchChanged(String query) {
  _debounceTimer?.cancel();
  _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
    if (query.isEmpty) {
      setState(() {
        _searchQuery = '';
        _searchResults = [];
      });
      return;
    }
    final repository = PlaylistRepository();
    final results = await repository.searchSongs(query);
    if (mounted) {
      setState(() {
        _searchQuery = query;
        _searchResults = results;
      });
    }
  });
}
```

## 清理

- `dispose()` 中取消 `_debounceTimer`、释放 `_searchController` 和 `_searchFocusNode`
- 退出搜索模式时取消 `_debounceTimer`

## 现有代码变更

| 文件 | 变更 |
|------|------|
| `lib/main.dart` (`_MyHomePageState`) | 新增搜索状态字段，修改 `_buildTopBar` 和 `_buildBody` 支持搜索模式，新增 `_enterSearchMode`、`_exitSearchMode`、`_onSearchChanged`、`_buildSearchContent` 方法 |

无新增文件，无新增路由，无新增依赖。