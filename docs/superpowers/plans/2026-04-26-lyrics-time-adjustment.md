# 歌词时间调整功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为歌词页面添加时间调整功能，支持整体偏移和逐行微调，持久化保存到数据库。

**Architecture:** 在 LyricsPage 添加编辑模式状态和底部调整工具栏，通过 PlayerProvider 保存调整后的歌词到数据库。

**Tech Stack:** Flutter, Provider, SQLite (sqflite)

---

## 文件结构

| 文件 | 职责 |
|------|------|
| `lib/features/lyrics/presentation/pages/lyrics_page.dart` | 编辑模式状态、调整工具栏 UI |
| `lib/features/player/presentation/providers/player_provider.dart` | 保存歌词调整方法 |
| `lib/core/database/database_helper.dart` | 更新歌词内容数据库操作 |
| `test/features/lyrics/lyrics_time_adjustment_test.dart` | 单元测试 |

---

### Task 1: 数据库层 - 添加更新歌词内容方法

**Files:**
- Modify: `lib/core/database/database_helper.dart`
- Test: `test/core/database/database_helper_test.dart`

- [ ] **Step 1: 在 DatabaseHelper 添加 updateLyricsContent 方法**

在 `database_helper.dart` 文件末尾 `currentTimestamp()` 方法之前添加：

```dart
/// 更新或插入歌词内容
/// 如果歌词记录存在则更新，不存在则插入
Future<void> updateLyricsContent(int songId, String lrcContent) async {
  final db = await database;
  final now = DateTime.now().toIso8601String();

  // 检查是否已存在记录
  final existing = await db.query(
    tableLyrics,
    where: 'song_id = ?',
    whereArgs: [songId],
  );

  if (existing.isNotEmpty) {
    // 更新现有记录
    await db.update(
      tableLyrics,
      {
        'lrc_content': lrcContent,
        'is_synced': 1,
        'source': 'manual',
        'updated_at': now,
      },
      where: 'song_id = ?',
      whereArgs: [songId],
    );
  } else {
    // 插入新记录
    await db.insert(tableLyrics, {
      'song_id': songId,
      'lrc_content': lrcContent,
      'is_synced': 1,
      'source': 'manual',
      'created_at': now,
      'updated_at': now,
    });
  }
}
```

- [ ] **Step 2: 运行分析确保无语法错误**

Run: `cd mysic_flutter && flutter analyze lib/core/database/database_helper.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add mysic_flutter/lib/core/database/database_helper.dart
git commit -m "feat(database): 添加 updateLyricsContent 方法"
```

---

### Task 2: Provider 层 - 添加保存歌词调整方法

**Files:**
- Modify: `lib/features/player/presentation/providers/player_provider.dart`

- [ ] **Step 1: 在 PlayerProvider 添加 saveLyricsAdjustment 方法**

在 `player_provider.dart` 文件 `deleteCurrentSong()` 方法之后、`dispose()` 方法之前添加：

```dart
/// 保存歌词时间调整
/// [globalOffset] 整体偏移量
/// [lineOffsets] 逐行偏移量（行索引 → 偏移量）
Future<bool> saveLyricsAdjustment({
  required Duration globalOffset,
  required Map<int, Duration> lineOffsets,
}) async {
  if (_currentSong == null || _currentSong!.id == null) return false;
  if (!_currentLyrics.isValid) return false;

  // 计算调整后的歌词行
  final adjustedLines = <LyricLine>[];
  for (int i = 0; i < _currentLyrics.lines.length; i++) {
    final line = _currentLyrics.lines[i];
    final lineOffset = lineOffsets[i] ?? Duration.zero;
    final adjustedTimestamp = line.timestamp + globalOffset + lineOffset;

    // 确保时间戳不为负数
    if (adjustedTimestamp >= Duration.zero) {
      adjustedLines.add(LyricLine(
        timestamp: adjustedTimestamp,
        text: line.text,
      ));
    }
  }

  // 创建调整后的歌词结果
  final adjustedLyrics = LyricsResult(
    lines: adjustedLines,
    metadata: _currentLyrics.metadata,
    isValid: adjustedLines.isNotEmpty,
  );

  // 生成 LRC 内容
  final lrcContent = _lyricsParser.toLrc(adjustedLyrics);

  // 保存到数据库
  final db = DatabaseHelper();
  await db.updateLyricsContent(_currentSong!.id!, lrcContent);

  // 更新当前歌词
  _currentLyrics = adjustedLyrics;
  notifyListeners();

  return true;
}
```

- [ ] **Step 2: 运行分析确保无语法错误**

Run: `cd mysic_flutter && flutter analyze lib/features/player/presentation/providers/player_provider.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add mysic_flutter/lib/features/player/presentation/providers/player_provider.dart
git commit -m "feat(player): 添加 saveLyricsAdjustment 方法"
```

---

### Task 3: UI 层 - 添加编辑模式状态和入口按钮

**Files:**
- Modify: `lib/features/lyrics/presentation/pages/lyrics_page.dart`

- [ ] **Step 1: 在 _LyricsPageState 添加编辑模式状态变量**

在 `_currentLineIndex` 变量之后添加：

```dart
// 编辑模式状态
bool _isEditMode = false;
bool _isLineEditMode = false;
Duration _globalOffset = Duration.zero;
Map<int, Duration> _lineOffsets = {};
```

- [ ] **Step 2: 修改顶部栏添加编辑按钮**

将 `_buildTopBar` 方法中 `const SizedBox(width: 44)` 替换为编辑按钮：

```dart
// 右侧编辑按钮
Container(
  width: 44,
  height: 44,
  decoration: BoxDecoration(
    color: _isEditMode ? AppColors.accent : AppColors.card,
    borderRadius: BorderRadius.circular(12),
  ),
  child: IconButton(
    icon: Icon(
      _isEditMode ? Icons.close_rounded : Icons.edit_rounded,
    ),
    iconSize: 20,
    color: _isEditMode ? AppColors.white : AppColors.white,
    padding: EdgeInsets.zero,
    onPressed: () {
      setState(() {
        _isEditMode = !_isEditMode;
        if (!_isEditMode) {
          // 退出编辑模式时重置状态
          _isLineEditMode = false;
          _globalOffset = Duration.zero;
          _lineOffsets = {};
        }
      });
    },
  ),
),
```

- [ ] **Step 3: 运行分析确保无语法错误**

Run: `cd mysic_flutter && flutter analyze lib/features/lyrics/presentation/pages/lyrics_page.dart`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add mysic_flutter/lib/features/lyrics/presentation/pages/lyrics_page.dart
git commit -m "feat(lyrics): 添加编辑模式状态和入口按钮"
```

---

### Task 4: UI 层 - 添加底部调整工具栏组件

**Files:**
- Modify: `lib/features/lyrics/presentation/pages/lyrics_page.dart`

- [ ] **Step 1: 添加 _buildAdjustmentToolbar 方法**

在 `_buildMiniPlayer` 方法之前添加：

```dart
/// 时间调整工具栏
Widget _buildAdjustmentToolbar(BuildContext context, PlayerProvider provider) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      border: Border(
        top: BorderSide(
          color: AppColors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 标题
        Row(
          children: [
            const Icon(
              Icons.music_note_rounded,
              size: 20,
              color: AppColors.accent,
            ),
            const SizedBox(width: 8),
            const Text(
              '时间调整',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 整体偏移
        _buildGlobalOffsetControl(),
        const SizedBox(height: 16),

        // 按钮行
        Row(
          children: [
            // 逐行调整按钮
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLineEditMode = !_isLineEditMode;
                  });
                },
                icon: Icon(
                  _isLineEditMode ? Icons.list_rounded : Icons.tune_rounded,
                  size: 18,
                ),
                label: Text(_isLineEditMode ? '完成调整' : '逐行调整'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.white,
                  side: BorderSide(color: AppColors.white.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 保存按钮
            ElevatedButton(
              onPressed: _hasChanges()
                  ? () => _saveAdjustment(provider)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('保存'),
            ),
          ],
        ),
      ],
    ),
  );
}

/// 整体偏移控件
Widget _buildGlobalOffsetControl() {
  final offsetSeconds = _globalOffset.inMilliseconds / 1000.0;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '整体偏移',
        style: TextStyle(
          fontSize: 14,
          color: AppColors.muted,
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          // 减少按钮
          _buildOffsetButton(
            icon: Icons.remove_rounded,
            onPressed: () {
              setState(() {
                _globalOffset = Duration(
                  milliseconds: (_globalOffset.inMilliseconds - 100).clamp(-5000, 5000),
                );
              });
            },
          ),
          // 滑块
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.accent,
                inactiveTrackColor: AppColors.white.withValues(alpha: 0.1),
                thumbColor: AppColors.accent,
                overlayColor: AppColors.accent.withValues(alpha: 0.2),
                trackHeight: 4,
              ),
              child: Slider(
                value: offsetSeconds.clamp(-5.0, 5.0),
                min: -5.0,
                max: 5.0,
                divisions: 100,
                onChanged: (value) {
                  setState(() {
                    _globalOffset = Duration(milliseconds: (value * 1000).round());
                  });
                },
              ),
            ),
          ),
          // 增加按钮
          _buildOffsetButton(
            icon: Icons.add_rounded,
            onPressed: () {
              setState(() {
                _globalOffset = Duration(
                  milliseconds: (_globalOffset.inMilliseconds + 100).clamp(-5000, 5000),
                );
              });
            },
          ),
        ],
      ),
      // 当前值和重置按钮
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '当前: ${offsetSeconds >= 0 ? '+' : ''}${offsetSeconds.toStringAsFixed(1)}s',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.white,
            ),
          ),
          TextButton(
            onPressed: _globalOffset != Duration.zero
                ? () {
                    setState(() {
                      _globalOffset = Duration.zero;
                    });
                  }
                : null,
            child: const Text('重置'),
          ),
        ],
      ),
    ],
  );
}

/// 偏移按钮
Widget _buildOffsetButton({
  required IconData icon,
  required VoidCallback onPressed,
}) {
  return Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: AppColors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: IconButton(
      icon: Icon(icon, size: 20),
      color: AppColors.white,
      padding: EdgeInsets.zero,
      onPressed: onPressed,
    ),
  );
}

/// 检查是否有更改
bool _hasChanges() {
  return _globalOffset != Duration.zero || _lineOffsets.isNotEmpty;
}

/// 保存调整
Future<void> _saveAdjustment(PlayerProvider provider) async {
  final success = await provider.saveLyricsAdjustment(
    globalOffset: _globalOffset,
    lineOffsets: _lineOffsets,
  );

  if (success && mounted) {
    setState(() {
      _isEditMode = false;
      _isLineEditMode = false;
      _globalOffset = Duration.zero;
      _lineOffsets = {};
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('歌词时间已保存'),
        backgroundColor: AppColors.accent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
```

- [ ] **Step 2: 修改 build 方法，在编辑模式下显示工具栏**

在 `build` 方法的 `Column` children 中，在 `_buildLyricsList` 和 `_buildMiniPlayer` 之间添加：

```dart
// 时间调整工具栏（编辑模式下显示）
if (_isEditMode) _buildAdjustmentToolbar(context, playerProvider),
```

- [ ] **Step 3: 运行分析确保无语法错误**

Run: `cd mysic_flutter && flutter analyze lib/features/lyrics/presentation/pages/lyrics_page.dart`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add mysic_flutter/lib/features/lyrics/presentation/pages/lyrics_page.dart
git commit -m "feat(lyrics): 添加底部时间调整工具栏"
```

---

### Task 5: UI 层 - 添加逐行调整功能

**Files:**
- Modify: `lib/features/lyrics/presentation/pages/lyrics_page.dart`

- [ ] **Step 1: 修改 _LyricLineWidget 添加逐行调整按钮**

将 `_LyricLineWidget` 类替换为：

```dart
/// 歌词行组件
class _LyricLineWidget extends StatelessWidget {
  final LyricLine line;
  final bool isActive;
  final bool isPast;
  final VoidCallback? onTap;
  final bool isEditMode;
  final Duration? lineOffset;
  final ValueChanged<Duration>? onOffsetChanged;

  const _LyricLineWidget({
    required this.line,
    this.isActive = false,
    this.isPast = false,
    this.onTap,
    this.isEditMode = false,
    this.lineOffset,
    this.onOffsetChanged,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOffset = lineOffset ?? Duration.zero;
    final offsetSeconds = effectiveOffset.inMilliseconds / 1000.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            // 逐行调整按钮（编辑模式下显示）
            if (isEditMode) ...[
              _buildLineAdjustButton(
                icon: Icons.remove_rounded,
                onPressed: () {
                  final newOffset = Duration(
                    milliseconds: (effectiveOffset.inMilliseconds - 100).clamp(-5000, 5000),
                  );
                  onOffsetChanged?.call(newOffset);
                },
              ),
              const SizedBox(width: 8),
            ],

            // 歌词文本
            Expanded(
              child: Text(
                line.text,
                style: TextStyle(
                  fontSize: isActive ? 18 : 14,
                  fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                  color: isActive
                      ? AppColors.white
                      : isPast
                          ? AppColors.muted.withValues(alpha: 0.5)
                          : AppColors.muted,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // 逐行调整按钮（编辑模式下显示）
            if (isEditMode) ...[
              const SizedBox(width: 8),
              _buildLineAdjustButton(
                icon: Icons.add_rounded,
                onPressed: () {
                  final newOffset = Duration(
                    milliseconds: (effectiveOffset.inMilliseconds + 100).clamp(-5000, 5000),
                  );
                  onOffsetChanged?.call(newOffset);
                },
              ),
              // 显示当前偏移值
              if (effectiveOffset != Duration.zero)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '${offsetSeconds >= 0 ? '+' : ''}${offsetSeconds.toStringAsFixed(1)}s',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.accent,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLineAdjustButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: IconButton(
        icon: Icon(icon, size: 16),
        color: AppColors.white,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
      ),
    );
  }
}
```

- [ ] **Step 2: 修改 _buildLyricsList 方法传递编辑模式参数**

将 `_buildLyricsList` 方法中的 `_LyricLineWidget` 调用替换为：

```dart
return _LyricLineWidget(
  line: line,
  isActive: isCurrentLine,
  isPast: isPastLine,
  isEditMode: _isLineEditMode,
  lineOffset: _lineOffsets[index],
  onOffsetChanged: (offset) {
    setState(() {
      if (offset == Duration.zero) {
        _lineOffsets.remove(index);
      } else {
        _lineOffsets[index] = offset;
      }
    });
  },
  onTap: () {
    // 点击歌词行跳转到对应时间
    final playerProvider =
        Provider.of<PlayerProvider>(context, listen: false);
    // 计算调整后的时间
    final adjustedTime = line.timestamp + _globalOffset + (_lineOffsets[index] ?? Duration.zero);
    playerProvider.seek(adjustedTime);
  },
);
```

- [ ] **Step 3: 运行分析确保无语法错误**

Run: `cd mysic_flutter && flutter analyze lib/features/lyrics/presentation/pages/lyrics_page.dart`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add mysic_flutter/lib/features/lyrics/presentation/pages/lyrics_page.dart
git commit -m "feat(lyrics): 添加逐行时间调整功能"
```

---

### Task 6: 集成测试和最终验证

**Files:**
- Test: `mysic_flutter/test/`

- [ ] **Step 1: 运行完整分析**

Run: `cd mysic_flutter && flutter analyze`
Expected: No issues found

- [ ] **Step 2: 运行所有测试**

Run: `cd mysic_flutter && flutter test`
Expected: All tests pass

- [ ] **Step 3: 手动测试应用**

Run: `cd mysic_flutter && flutter run -d windows`

测试步骤：
1. 播放一首有歌词的歌曲
2. 进入歌词页面
3. 点击右上角编辑按钮进入编辑模式
4. 调整整体偏移滑块，观察歌词高亮变化
5. 点击"逐行调整"按钮，调整单行时间
6. 点击"保存"按钮
7. 退出并重新进入歌词页面，验证调整已保存

- [ ] **Step 4: Final Commit**

```bash
git add -A
git commit -m "feat(lyrics): 完成歌词时间调整功能"
```

---

## 实现顺序

1. Task 1 → Task 2 (数据层)
2. Task 3 → Task 4 → Task 5 (UI 层)
3. Task 6 (测试验证)

每个 Task 完成后立即 commit，确保原子性变更。
