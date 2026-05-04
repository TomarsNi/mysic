# 精确路径匹配修复设计

## 问题背景

### 现象
用户创建多个歌单并关联不同目录后，扫描音乐时歌曲被分配到错误的歌单中。

### 根本原因
`_isPathInDirectory` 函数使用简单的字符串包含检查，导致同一首歌可能匹配多个目录：

```dart
// 当前实现
bool _isPathInDirectory(String filePath, String directoryName) {
  final lowerPath = filePath.toLowerCase();
  final lowerDir = directoryName.toLowerCase();
  if (lowerPath.contains('/$lowerDir/')) return true;
  if (lowerPath.contains(bs + lowerDir + bs)) return true;
  ...
}
```

**问题场景**：
- 歌单 "Music" 关联目录 `music`
- 歌单 "成名曲" 关联目录 `成名曲`
- 文件路径：`G:\music\成名曲\歌曲.mp3`

结果：歌曲同时匹配两个目录，被添加到两个歌单。

## 解决方案

### 核心设计

**存储完整目录路径**，使用**精确路径前缀匹配**。

### 数据模型变更

#### ScanDirectoryConfig

```dart
class ScanDirectoryConfig {
  final String directory;      // 改为存储完整路径，如 "G:\music\成名曲"
  final int? playlistId;
  final String? playlistName;
  
  // 新增：目录别名（用于显示，如 "成名曲"）
  final String? displayName;
}
```

### 路径匹配逻辑

```dart
/// 检查文件是否属于指定目录（精确匹配）
bool _isPathInDirectory(String filePath, String directoryPath) {
  // 规范化路径（统一使用正斜杠）
  final normalizedFile = filePath.replaceAll('\\', '/').toLowerCase();
  final normalizedDir = directoryPath.replaceAll('\\', '/').toLowerCase();
  
  // 确保目录路径以分隔符结尾，避免部分匹配
  final dirWithSeparator = normalizedDir.endsWith('/') 
      ? normalizedDir 
      : '$normalizedDir/';
  
  return normalizedFile.startsWith(dirWithSeparator);
}
```

### 业务流程变更

#### 1. 创建歌单时选择目录

```
用户选择目录 "G:\music\成名曲"
    ↓
存储完整路径到 ScanDirectoryConfig:
  - directory: "G:\music\成名曲"
  - displayName: "成名曲"（用于 UI 显示）
  - playlistId: 新歌单 ID
    ↓
扫描该目录下的音乐文件
```

#### 2. 扫描设置页面的目录管理

```
显示目录列表时：
  - 显示 displayName 或 directory 的最后一级目录名
  - 完整路径在详情中显示
```

#### 3. 执行扫描后分配歌曲

```
遍历所有 ScanDirectoryConfig
    ↓
对每个配置，使用精确路径前缀匹配筛选歌曲
    ↓
将匹配的歌曲添加到关联歌单
```

### 向后兼容

#### 数据迁移

首次加载时检测旧格式数据（仅目录名，如 `music`）：

1. 尝试在所有驱动器中查找该目录
2. 如果找到，转换为完整路径
3. 如果找不到，保留原值（匹配时会失败，需用户重新选择）

```dart
Future<List<ScanDirectoryConfig>> migrateConfigs(
  List<ScanDirectoryConfig> oldConfigs,
) async {
  final drives = await _getAvailableDrives();
  final newConfigs = <ScanDirectoryConfig>[];
  
  for (final config in oldConfigs) {
    // 检查是否已经是完整路径
    if (await Directory(config.directory).exists()) {
      newConfigs.add(config);
      continue;
    }
    
    // 尝试查找完整路径
    String? fullPath;
    for (final drive in drives) {
      final path = '$drive${config.directory}';
      if (await Directory(path).exists()) {
        fullPath = path;
        break;
      }
    }
    
    if (fullPath != null) {
      newConfigs.add(config.copyWith(
        directory: fullPath,
        displayName: config.directory,
      ));
    } else {
      // 保留原值，用户需重新选择
      newConfigs.add(config);
    }
  }
  
  return newConfigs;
}
```

## 代码改动清单

### 1. 数据模型

**文件**: `lib/shared/utils/scan_directory_config.dart`

- 添加 `displayName` 字段
- 更新 `fromJson`、`toJson`、`copyWith` 方法

### 2. 目录提供者

**文件**: `lib/shared/utils/scan_directory_provider.dart`

- 添加数据迁移逻辑
- 更新添加目录方法，支持完整路径

### 3. 扫描设置页面

**文件**: `lib/features/settings/presentation/pages/scan_settings_page.dart`

- 重写 `_isPathInDirectory` 函数，使用精确路径匹配
- 更新 `_addSongsToLinkedPlaylists` 逻辑

### 4. 创建歌单对话框

**文件**: `lib/shared/widgets/bottom_sheet.dart`

- 创建歌单时，存储完整目录路径到 `ScanDirectoryProvider`

### 5. 扫描目录列表组件

**文件**: `lib/features/settings/presentation/widgets/scan_directory_list.dart`

- 更新显示逻辑，优先显示 `displayName`

### 6. Windows 音乐扫描器

**文件**: `lib/shared/utils/windows_music_scanner.dart`

- 更新 `_getScanRoots` 方法，支持完整路径

## 测试计划

### 单元测试

1. `_isPathInDirectory` 精确匹配测试
   - 完全匹配：`G:\music\歌曲.mp3` 属于 `G:\music`
   - 不匹配：`G:\music\歌曲.mp3` 不属于 `G:\music2`
   - 部分路径不匹配：`G:\music\成名曲\歌曲.mp3` 不属于 `G:\music\成名`（如果不存在）

2. 数据迁移测试
   - 旧格式（目录名）迁移到新格式（完整路径）
   - 新格式数据保持不变

### 集成测试

1. 创建歌单 → 选择目录 → 扫描 → 验证歌曲在正确歌单
2. 多个歌单关联不同目录 → 扫描 → 验证歌曲分配正确

## 不在范围内

- 一个目录关联多个歌单
- 歌单反向关联目录
- 删除目录时同时删除歌单

## 实现优先级

1. 数据模型扩展（添加 `displayName`）
2. 路径匹配函数重写
3. 创建歌单时存储完整路径
4. 数据迁移逻辑
5. UI 更新
6. 测试覆盖
