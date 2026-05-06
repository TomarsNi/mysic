# Android 歌曲封面获取功能实现计划

## 概述

为 Android 平台添加扫描时同步获取专辑封面功能，解决系统文件管理器有封面但应用无封面的问题。

## 实现步骤

### 阶段 1：依赖准备

- [ ] 检查 `path_provider` 依赖是否已存在
- [ ] 如不存在，添加 `path_provider: ^2.1.0` 到 pubspec.yaml
- [ ] 运行 `flutter pub get`

### 阶段 2：封面获取逻辑实现

- [ ] 在 `MobileMusicScanner` 中添加 `_fetchAndSaveArtwork` 方法
  - 参数：数据库 songId, MediaStore mediaId
  - 调用 `_audioQuery.queryArtwork()` 获取封面字节
  - 使用 `path_provider` 获取应用文档目录
  - 创建 `album_art/` 子目录
  - 保存封面为 `<songId>.jpg`
  - 返回文件路径或 null

- [ ] 添加 `_ensureArtDirectory` 方法
  - 确保封面目录存在
  - 缓存目录路径避免重复创建

### 阶段 3：扫描流程集成

- [ ] 修改 `_saveMediaSongsToDatabase` 方法
  - 保存歌曲记录后记录 mediaId 映射
  - 事务完成后批量获取封面
  - 更新 album_art_path 字段

- [ ] 同步修改 `_saveSongsToDatabase` 方法（文件系统扫描路径）
  - 使用 `audiotags` 提取封面（已有实现）
  - 保存封面到同一目录

### 阶段 4：错误处理

- [ ] 封面获取失败时记录日志，不中断扫描
- [ ] 文件写入失败时回退，album_art_path 保持 null
- [ ] 添加调试日志便于问题排查

### 阶段 5：测试验证

- [ ] 编写单元测试
  - 封面获取成功场景
  - 封面获取失败场景
  - 文件保存场景

- [ ] 手动测试
  - Android 设备扫描歌曲
  - 验证封面正确显示
  - 验证无封面歌曲显示默认图标

## 文件变更清单

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `pubspec.yaml` | 可能修改 | 添加 path_provider 依赖 |
| `lib/shared/utils/mobile_music_scanner.dart` | 修改 | 添加封面获取逻辑 |

## 风险评估

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 扫描时间增加 | 用户体验 | 显示进度提示，封面获取异步化 |
| 存储空间增加 | 用户设备 | 封面存应用私有目录，卸载自动清理 |
| 封面获取失败 | 功能不完整 | 优雅降级，显示默认封面 |

## 回滚方案

如遇严重问题，可移除封面获取逻辑，恢复原有扫描流程。数据库无需回滚，album_art_path 为 null 时显示默认封面。
