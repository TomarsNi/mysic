# 扫描目录与歌单绑定功能设计

## 问题背景

当前系统中，扫描目录和歌单是两个独立的概念：
- 扫描目录仅用于过滤扫描范围
- 扫描完成后，歌曲只会添加到固定的"本地音乐"歌单

用户期望：扫描指定目录后，歌曲自动添加到对应的歌单中。

## 解决方案

### 核心设计

**目录与歌单绑定**：每个扫描目录关联一个歌单，扫描该目录的歌曲自动添加到关联歌单。

### 数据模型

#### 扫描目录配置（扩展）

```dart
// 原结构
List<String> directories = ["Music", "Downloads"]

// 新结构
class ScanDirectoryConfig {
  final String directory;      // 目录名称/路径
  final int? playlistId;       // 关联的歌单 ID（null 表示未关联）
  final String? playlistName;  // 关联的歌单名称（冗余存储，便于显示）
}

List<ScanDirectoryConfig> directories = [
  ScanDirectoryConfig(directory: "Music", playlistId: 1, playlistName: "Music"),
  ScanDirectoryConfig(directory: "Downloads", playlistId: 2, playlistName: "下载"),
]
```

#### 数据库存储

继续使用 `app_state` 表，key 为 `scan_directories`，value 为 JSON 序列化：

```json
[
  {"directory": "Music", "playlistId": 1, "playlistName": "Music"},
  {"directory": "Downloads", "playlistId": 2, "playlistName": "下载"}
]
```

### 业务流程

#### 1. 添加扫描目录

```
用户输入目录名 "Music"
    ↓
检查是否已存在同名目录
    ↓
创建同名歌单 "Music"
    ↓
存储目录配置: {directory: "Music", playlistId: 新歌单ID, playlistName: "Music"}
    ↓
刷新 UI
```

#### 2. 执行扫描

```
用户点击"开始扫描"
    ↓
遍历所有扫描目录，逐个扫描
    ↓
对于每个目录：
  - 扫描该目录下的音乐文件
  - 获取该目录关联的歌单 ID
  - 将扫描到的歌曲添加到关联歌单
    ↓
同时更新"本地音乐"歌单（作为总览）
    ↓
显示扫描结果
```

#### 3. 移除扫描目录

```
用户点击删除目录
    ↓
弹出确认对话框
    ↓
确认后：
  - 删除目录配置
  - 可选：是否同时删除关联歌单？（暂不实现，保持简单）
    ↓
刷新 UI
```

### UI 变更

#### 扫描目录列表

```
扫描目录管理
仅扫描以下目录中的音乐文件

┌─────────────────────────────────────┐
│ Music                    → 本地音乐 │  ← 显示关联歌单名称
│ Downloads                → 下载     │
│ 新增目录                  → 未关联   │  ← 灰色显示
└─────────────────────────────────────┘

[添加目录]  [恢复默认]
```

#### 添加目录对话框

```
┌─────────────────────────────────────┐
│ 添加扫描目录                        │
│                                     │
│ 目录名称: [________________]        │
│                                     │
│ ☑ 自动创建同名歌单并关联            │  ← 默认勾选
│                                     │
│        [取消]    [添加]             │
└─────────────────────────────────────┘
```

### 代码改动清单

#### 1. 新增数据模型

**文件**: `lib/shared/utils/scan_directory_config.dart`

```dart
class ScanDirectoryConfig {
  final String directory;
  final int? playlistId;
  final String? playlistName;

  const ScanDirectoryConfig({
    required this.directory,
    this.playlistId,
    this.playlistName,
  });

  factory ScanDirectoryConfig.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
  ScanDirectoryConfig copyWith({...});
}
```

#### 2. 扩展 ScanDirectoryProvider

**文件**: `lib/shared/utils/scan_directory_provider.dart`

新增方法：
- `Future<List<ScanDirectoryConfig>> getConfigs()` - 获取目录配置列表
- `Future<void> addDirectoryWithPlaylist(String directory, {int? playlistId, String? playlistName})` - 添加目录并关联歌单
- `Future<void> updateDirectoryPlaylist(String directory, int playlistId, String playlistName)` - 更新目录的歌单关联
- `Future<ScanDirectoryConfig?> getConfigByDirectory(String directory)` - 根据目录名获取配置

#### 3. 修改扫描逻辑

**文件**: `lib/features/settings/presentation/pages/scan_settings_page.dart`

修改 `_startScan` 方法：
- 遍历扫描目录配置
- 对每个目录，扫描后将歌曲添加到关联歌单
- 保留"本地音乐"歌单作为总览

#### 4. 修改目录列表 UI

**文件**: `lib/features/settings/presentation/widgets/scan_directory_list.dart`

- 显示每个目录关联的歌单名称
- 添加目录时自动创建同名歌单

#### 5. 数据迁移

**文件**: `lib/shared/utils/scan_directory_provider.dart`

首次加载时，检测旧格式数据（纯字符串列表），自动迁移为新格式：
- 为每个目录创建同名歌单
- 更新存储格式

### 边界情况处理

1. **目录已存在**：提示用户，不重复添加
2. **关联歌单被删除**：显示"未关联"，下次扫描时提示重新关联
3. **扫描目录为空**：跳过，不创建空歌单
4. **默认目录迁移**：首次升级时，为默认目录自动创建歌单

### 测试计划

1. **单元测试**
   - `ScanDirectoryConfig` 序列化/反序列化
   - `ScanDirectoryProvider` CRUD 操作
   - 旧数据迁移逻辑

2. **Widget 测试**
   - 目录列表显示关联状态
   - 添加目录对话框交互

3. **集成测试**
   - 添加目录 → 自动创建歌单 → 扫描 → 歌曲添加到正确歌单
   - 删除目录 → 歌单保留 → 重新关联

### 不在范围内

- 删除目录时同时删除歌单（保持简单，避免误删）
- 一个目录关联多个歌单（增加复杂度，暂不需要）
- 歌单反向关联目录（单向绑定足够）

## 实现优先级

1. 数据模型和 Provider 扩展（基础）
2. 数据迁移逻辑（兼容性）
3. 扫描逻辑调整（核心功能）
4. UI 更新（用户体验）
5. 测试覆盖（质量保证）
