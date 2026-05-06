# 删除歌曲时同时删除原文件功能设计

## 概述

在删除歌曲的确认弹窗中新增「同时删除原文件」选项。用户勾选后，该状态会被持久化存储，后续删除操作默认保持勾选状态，直到用户手动取消。

## 需求

1. 删除歌曲确认弹窗中新增勾选框：「同时删除原文件」
2. 用户勾选状态会被记住（持久化存储）
3. 下次打开删除确认弹窗时，默认显示上次的选择状态
4. 勾选时删除歌曲会同时删除文件系统中的原音乐文件

## 技术设计

### 1. 状态存储

使用 `SharedPreferences` 存储用户的勾选偏好：

- **Key**: `delete_song_with_file`
- **Type**: `bool`
- **Default**: `false`

存储位置：`lib/features/settings/data/delete_preference.dart`（新建）

```dart
class DeletePreference {
  static const _keyDeleteWithFile = 'delete_song_with_file';

  static Future<bool> getDeleteWithFile() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDeleteWithFile) ?? false;
  }

  static Future<void> setDeleteWithFile(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDeleteWithFile, value);
  }
}
```

### 2. UI 变更

修改 `_DeleteConfirmSheet` 组件（`lib/main.dart`）：

- 添加 `StatefulWidget` 状态管理
- 新增 `_deleteWithFile` 布尔状态
- 初始化时从 `SharedPreferences` 读取上次状态
- 勾选变更时保存到 `SharedPreferences`
- 在警告提示上方添加 `CheckboxListTile`

**UI 结构**：

```
[拖拽指示条]
[警告图标]
[标题: 确认删除歌曲？]
[歌曲名称]
[勾选框: 同时删除原文件]  <-- 新增
[警告提示]
[操作按钮: 算了吧 | 删了吧]
```

**勾选框样式**：

- 标题：「同时删除原文件」
- 副标题：「文件删除后无法恢复」
- 选中时 checkbox 颜色为红色（`Color(0xFFEF4444)`）

### 3. 删除逻辑变更

#### 3.1 PlaylistProvider

修改 `deleteSong` 方法签名：

```dart
Future<bool> deleteSong(int songId, {bool deleteFile = false}) async {
  if (deleteFile) {
    // 先获取歌曲信息以获取文件路径
    final song = await _repository.getSongById(songId);
    if (song != null) {
      await _deleteFile(song.filePath);
    }
  }
  // 原有删除逻辑
  return await _repository.deleteSong(songId);
}
```

#### 3.2 文件删除工具

新建 `lib/core/utils/file_utils.dart`：

```dart
import 'dart:io';

class FileUtils {
  /// 删除文件，静默处理错误
  static Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      // 文件删除失败不阻塞流程，仅记录日志
      print('删除文件失败: $e');
      return false;
    }
  }
}
```

### 4. 回调签名变更

`_DeleteConfirmSheet` 的 `onConfirm` 回调需要传递勾选状态：

```dart
// 之前
final VoidCallback onConfirm;

// 之后
final void Function(bool deleteWithFile) onConfirm;
```

调用处修改：

```dart
_showDeleteConfirmSheet(context, song) {
  showModalBottomSheet(
    ...
    builder: (context) => _DeleteConfirmSheet(
      song: song,
      onConfirm: (deleteWithFile) async {
        final playerProvider = context.read<PlayerProvider>();
        final playlistProvider = context.read<PlaylistProvider>();

        await playlistProvider.deleteSong(song.id!, deleteFile: deleteWithFile);
        // ... 其他逻辑
      },
    ),
  );
}
```

## 涉及文件

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `lib/main.dart` | 修改 | 修改 `_DeleteConfirmSheet` 组件 |
| `lib/features/playlist/presentation/providers/playlist_provider.dart` | 修改 | 扩展 `deleteSong` 方法 |
| `lib/features/settings/data/delete_preference.dart` | 新建 | 删除偏好存储 |
| `lib/core/utils/file_utils.dart` | 新建 | 文件删除工具 |

## 测试要点

1. **UI 测试**
   - 勾选框默认状态应为上次选择的状态
   - 勾选后关闭弹窗再打开，状态应保持

2. **功能测试**
   - 仅删除数据库记录（不勾选）：文件仍存在
   - 同时删除文件（勾选）：文件被删除

3. **边界测试**
   - 文件不存在时删除不应报错
   - 文件被占用时删除失败不应阻塞流程

## 风险评估

- **低风险**：文件删除失败时静默处理，不影响数据库记录删除
- **不可逆操作**：文件删除后无法恢复，UI 需明确提示用户
