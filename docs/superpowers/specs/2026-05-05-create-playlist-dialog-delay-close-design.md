# 创建歌单弹窗延迟关闭设计

## 问题描述

创建歌单时，如果用户选择了目录进行扫描，弹窗在扫描完成后立即关闭，但数据库插入操作（创建歌单、添加歌曲、关联目录）仍在进行中。用户看不到这些操作的进度反馈，体验不佳。

## 当前流程

```
用户点击"创建" → 扫描目录 → 扫描完成 → 立即关闭弹窗 → 数据库插入（无反馈）
```

## 目标流程

```
用户点击"创建" → 扫描目录 → 扫描完成 → 显示"创建中..." → 数据库插入完成 → 关闭弹窗
```

## 解决方案

### 核心变更

修改弹窗关闭时机：等待所有数据库操作完成后再关闭弹窗。

### UI 状态设计

| 阶段 | 按钮状态 | 底部提示 |
|------|----------|----------|
| 扫描中 | 禁用，显示加载动画 | "正在扫描... X%" |
| 扫描完成 → 创建中 | 禁用，显示"创建中..." | "正在创建歌单，请稍候..." |
| 创建完成 | 弹窗关闭 | 显示成功 SnackBar |

### 技术实现

#### 1. 修改 `CreatePlaylistDialog` 状态

新增状态变量：

```dart
bool _isCreating = false;  // 标记数据库插入阶段
```

#### 2. 修改 `_scanAndCreate()` 方法

- 扫描完成后，设置 `_isCreating = true`
- 调用 `widget.onCreate` 并等待其完成
- 回调完成后再关闭弹窗

```dart
Future<void> _scanAndCreate() async {
  // ... 扫描逻辑 ...

  setState(() {
    _isScanning = false;
    _isCreating = true;  // 新增：进入创建阶段
  });

  // 等待数据库操作完成
  await widget.onCreate?.call(name, description, scannedSongs, _selectedDirectory);

  // 完成后关闭弹窗
  if (mounted) {
    Navigator.of(context).pop();
  }
}
```

#### 3. 修改 UI 组件

**按钮状态**：

```dart
ElevatedButton(
  onPressed: (_canCreate && !_isScanning && !_isCreating) ? _handleCreate : null,
  child: _isScanning || _isCreating
    ? Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, ...),
          ),
          SizedBox(width: 8),
          Text(_isScanning ? '扫描中...' : '创建中...'),
        ],
      )
    : const Text('创建'),
)
```

**底部提示**：

```dart
Widget _buildScanProgress() {
  if (_isCreating) {
    return Column(
      children: [
        SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.hourglass_empty_rounded, size: 16, color: AppColors.muted),
            SizedBox(width: 8),
            Text('正在创建歌单，请稍候...', style: TextStyle(fontSize: 13, color: AppColors.muted)),
          ],
        ),
      ],
    );
  }
  // ... 原有扫描进度逻辑 ...
}
```

#### 4. 回调签名确认

`onCreate` 回调已经是 `Future<void>` 类型（`main.dart` 中使用 `async`），无需修改签名。

### 文件变更

| 文件 | 变更内容 |
|------|----------|
| `lib/shared/widgets/bottom_sheet.dart` | 新增 `_isCreating` 状态，修改 `_scanAndCreate()` 和 UI 组件 |

### 测试要点

1. 不选择目录创建歌单 → 弹窗应正常关闭
2. 选择目录扫描 → 扫描完成后显示"创建中..."
3. 数据库插入完成 → 弹窗关闭，显示成功提示
4. 扫描/创建过程中点击取消 → 应能正常取消
