# 播放模式持久化设计

## 概述

将播放模式（顺序/随机/循环）持久化保存，应用重启后恢复上次的设置。同时简化循环模式交互，移除单曲循环。

## 需求

1. 播放模式设置后保存到本地存储
2. 应用启动时恢复上次的播放模式
3. 简化循环模式：移除单曲循环，只保留列表循环
4. 点击当前选中的模式按钮无效果，点击其他模式才切换

## 播放模式定义

| 模式 | isShuffleMode | loopMode | 说明 |
|------|---------------|----------|------|
| 顺序 | false | off | 按顺序播放，播完停止 |
| 随机 | true | off | 随机选择下一首，播完停止 |
| 循环 | false | all | 按顺序播放，播完后从头循环 |

## 交互逻辑

| 当前模式 | 点击顺序 | 点击随机 | 点击循环 |
|----------|----------|----------|----------|
| 顺序 | 无效果 | → 随机 | → 循环 |
| 随机 | → 顺序 | 无效果 | → 循环 |
| 循环 | → 顺序 | → 随机 | 无效果 |

## 技术方案

### 存储层

新建 `lib/features/settings/data/play_mode_preference.dart`：

```dart
class PlayModePreference {
  static const _keyShuffleMode = 'play_mode_shuffle';
  static const _keyLoopMode = 'play_mode_loop';

  // 保存播放模式
  static Future<void> save({required bool shuffle, required String loopMode});

  // 加载播放模式
  static Future<({bool shuffle, String loopMode})> load();
}
```

**存储键：**
- `play_mode_shuffle`: bool，是否随机模式
- `play_mode_loop`: string，循环模式（`'off'` 或 `'all'`）

### 数据层修改

**AudioPlayerService：**
- 移除 `MysicLoopMode.one` 枚举值
- `toggleLoopMode()` 改为 `off` ↔ `all` 切换

**PlayerProvider：**
- `_init()` 中加载持久化的播放模式
- 模式变更时调用 `PlayModePreference.save()`

### UI 层修改

**AppDrawer._buildPlayModeSection：**
- 循环按钮选中条件改为 `loopMode == MysicLoopMode.all`
- `_setPlayMode()` 方法：如果目标模式与当前相同，直接返回

**PlayControls.ExtendedControls：**
- 移除单曲循环的 "1" 角标显示
- 循环图标始终使用 `Icons.repeat_rounded`

## 实现步骤

1. 创建 `PlayModePreference` 类
2. 修改 `MysicLoopMode` 枚举，移除 `one`
3. 更新 `AudioPlayerService` 的循环逻辑
4. 更新 `PlayerProvider`，添加持久化加载和保存
5. 更新 `AppDrawer` 的交互逻辑
6. 更新 `PlayControls` 的显示逻辑
7. 更新相关测试

## 文件变更

| 文件 | 变更类型 |
|------|----------|
| `lib/features/settings/data/play_mode_preference.dart` | 新增 |
| `lib/features/player/data/services/audio_player_service.dart` | 修改 |
| `lib/features/player/presentation/providers/player_provider.dart` | 修改 |
| `lib/shared/widgets/app_drawer.dart` | 修改 |
| `lib/features/player/presentation/widgets/play_controls.dart` | 修改 |
| `test/features/settings/data/play_mode_preference_test.dart` | 新增 |
| `test/audio_player_service_test.dart` | 修改 |
| `test/player_provider_test.dart` | 修改 |
