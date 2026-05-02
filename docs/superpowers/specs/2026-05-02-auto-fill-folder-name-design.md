# 创建歌单时自动填充文件夹名称

## 需求概述

在创建歌单对话框中，当用户选择扫描目录后，自动将该目录的文件夹名称填入歌单名称输入框，提升用户体验。

## 当前状态

`CreatePlaylistDialog`（位于 `lib/shared/widgets/bottom_sheet.dart`）已具备：
- 目录选择功能（`_selectDirectory` 方法，第 540-546 行）
- 歌单名称输入框（`_nameController`，第 513 行）
- 扫描进度显示和创建逻辑

**缺失**：选择目录后，歌单名称需手动输入，无自动填充。

## 设计方案

### 核心逻辑

1. **自动填充触发时机**：用户选择目录成功后立即填充
2. **文件夹名称提取**：从完整路径中提取最后一级目录名
3. **智能覆盖策略**：
   - 名称输入框为空 → 自动填充
   - 当前值等于上次自动填充值 → 更新为新目录名（用户未手动修改）
   - 当前值不等于上次自动填充值 → 保留用户输入（用户已手动修改）

### 状态管理

新增状态变量：
```dart
String? _lastAutoFilledName; // 追踪上次自动填充的名称
```

### 文件夹名称提取

Windows 路径示例：
- `C:\Users\nbb\Music\流行音乐` → 提取 `流行音乐`
- `D:\Music\My Playlist` → 提取 `My Playlist`

实现方式：使用 `path` 包的 `basename` 方法，或 Dart 内置路径操作。

### 交互流程

```
用户点击"选择"按钮
    ↓
调用 getDirectoryPath()
    ↓
用户选择目录（如 C:\Music\流行音乐）
    ↓
提取文件夹名称：流行音乐
    ↓
判断是否可填充：
    ├─ 名称框为空 → 填充 "流行音乐"，记录 _lastAutoFilledName = "流行音乐"
    ├─ 当前值 == _lastAutoFilledName → 更新为 "流行音乐"，更新 _lastAutoFilledName
    └─ 当前值 != _lastAutoFilledName → 不填充（保留用户输入）
    ↓
用户可继续手动修改名称或直接创建
```

## 实现细节

### 修改文件

`lib/shared/widgets/bottom_sheet.dart` - `_CreatePlaylistDialogState` 类

### 代码变更

1. **新增状态变量**（约第 516 行后）：
   ```dart
   String? _lastAutoFilledName;
   ```

2. **新增路径提取方法**：
   ```dart
   String _extractFolderName(String path) {
     // 使用 path.basename 或手动分割
     final parts = path.split(RegExp(r'[\\/]'));
     return parts.where((p) => p.isNotEmpty).last;
   }
   ```

3. **修改 `_selectDirectory` 方法**（第 540-546 行）：
   ```dart
   Future<void> _selectDirectory() async {
     final result = await getDirectoryPath();
     if (result != null && mounted) {
       final folderName = _extractFolderName(result);
       setState(() {
         _selectedDirectory = result;
         // 智能填充：空值或等于上次自动填充值时才更新
         if (_nameController.text.isEmpty ||
             _nameController.text == _lastAutoFilledName) {
           _nameController.text = folderName;
           _lastAutoFilledName = folderName;
           _updateCanCreate();
         }
       });
     }
   }
   ```

## 边界情况

| 场景 | 行为 |
|------|------|
| 选择目录后立即取消选择（点击 X） | 名称保留，不清空 |
| 选择目录 A，手动改为 "我的歌单"，再选目录 B | 名称保持 "我的歌单" |
| 选择目录 A，未修改，再选目录 B | 名称更新为目录 B 的名称 |
| 路径末尾有斜杠（如 `C:\Music\`） | 正确提取 `Music` |
| 路径包含特殊字符（如空格、中文） | 正常处理，无特殊转义 |

## 测试要点

1. **单元测试**：
   - `_extractFolderName` 对各种路径格式的提取正确性
   - 自动填充逻辑的触发条件判断

2. **Widget 测试**：
   - 选择目录后名称自动填充
   - 手动修改后切换目录名称不变
   - 清空名称后切换目录可重新填充

## 不涉及变更

- 不修改 `PlaylistProvider`
- 不修改数据库层
- 不影响现有扫描和创建逻辑