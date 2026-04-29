# 限制音乐扫描目录范围 - 设计文档

**日期**: 2026-04-29
**状态**: 待实现

## 需求概述

限制音乐扫描的目录范围，仅扫描用户配置的目录（如 Music、音乐、Downloads、下载等），而非全盘扫描。

## 设计决策

| 决策项 | 选择 | 理由 |
|--------|------|------|
| 配置方式 | 用户可配置目录列表 | 灵活性高，用户可自定义 |
| 移动端处理 | 同样应用目录限制 | 统一行为，避免平台差异 |
| 存储位置 | SQLite 数据库 | 与现有数据层一致 |
| 实现方案 | 最小改动方案 | 风险低，改动范围可控 |

## 数据库设计

新增 `settings` 表：

```sql
CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
```

存储格式：
- `scan_directories` 键存储 JSON 数组：`["Music", "音乐", "Downloads", ...]`
- 每个目录名存储为字符串，扫描时在各驱动器/存储根目录下查找匹配目录

## 默认目录列表

```dart
const List<String> kDefaultScanDirectories = [
  'Music',
  '音乐',
  'Downloads',
  '下载',
  'Download',
  'Audio',
  '音频',
  'Songs',
  '歌曲',
];
```

## 扫描逻辑改动

### WindowsMusicScanner

**改动前**：从每个驱动器根目录开始递归扫描

**改动后**：
1. 读取配置的目录名列表
2. 在每个驱动器下查找匹配的目录（如 `C:\Music`、`D:\音乐`）
3. 仅扫描这些匹配的目录

```dart
Future<List<String>> _getScanRoots() async {
  final directories = await _loadScanDirectories();
  final drives = await _getAvailableDrives();

  final roots = <String>[];
  for (final drive in drives) {
    for (final dirName in directories) {
      final path = '$drive$dirName';
      if (await Directory(path).exists()) {
        roots.add(path);
      }
    }
  }
  return roots;
}
```

### MobileMusicScanner

**改动前**：使用 `on_audio_query` 查询系统媒体库

**改动后**：
1. 获取外部存储根目录（Android: `/storage/emulated/0/`）
2. 在根目录下查找配置的目录名
3. 递归扫描这些目录中的音频文件

**权限要求**：Android 11+ 需要 `MANAGE_EXTERNAL_STORAGE` 权限才能遍历任意目录。

## 设置页面 UI

在设置页面新增「扫描目录管理」区块：

**功能**：
- 显示当前配置的目录列表
- 支持添加自定义目录名
- 支持删除目录名
- 提供「恢复默认」按钮

**UI 布局**：
```
扫描目录管理
┌─────────────────────────────┐
│ ☑ Music          [删除]     │
│ ☑ 音乐           [删除]     │
│ ☑ Downloads      [删除]     │
│ ☑ 下载           [删除]     │
│ ☐ Audio          [删除]     │
│ ...                         │
├─────────────────────────────┤
│ [添加目录]  [恢复默认]       │
└─────────────────────────────┘
```

## 文件变更清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `lib/core/database/database_helper.dart` | 修改 | 添加 `settings` 表 |
| `lib/shared/utils/scan_directory_provider.dart` | 新增 | 目录配置管理类 |
| `lib/shared/utils/windows_music_scanner.dart` | 修改 | 应用目录过滤逻辑 |
| `lib/shared/utils/mobile_music_scanner.dart` | 重写 | 改为文件系统扫描 |
| `lib/features/settings/presentation/pages/settings_page.dart` | 修改 | 添加目录管理入口 |
| `lib/features/settings/presentation/widgets/scan_directory_list.dart` | 新增 | 目录列表组件 |

## 注意事项

1. **Android 权限**：Android 11+ 需要请求 `MANAGE_EXTERNAL_STORAGE` 权限才能访问任意目录
2. **失去媒体库优势**：移动端放弃 `on_audio_query` 后，失去系统自动识别新歌的能力，需用户手动触发扫描
3. **首次启动**：首次启动时将默认目录列表写入数据库
4. **向后兼容**：现有用户升级后，自动使用默认目录配置

## 测试要点

1. 验证 Windows 端仅扫描配置目录
2. 验证 Android 端文件系统扫描正常工作
3. 验证设置页面目录增删功能
4. 验证恢复默认功能
5. 验证首次启动初始化默认配置
