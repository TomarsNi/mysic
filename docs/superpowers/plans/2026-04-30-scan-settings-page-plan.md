# 扫描设置页面实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将扫描设置从底部弹框改为独立页面，并增加高级选项功能（文件格式过滤、最小文件大小、自动去重）。

**Architecture:** 创建 `ScanOptionsProvider` 管理扫描选项数据（使用 SharedPreferences），创建 `ScanSettingsPage` 独立页面展示扫描功能和高级选项，修改 `MusicScanner` 支持高级选项参数，修改平台扫描器应用过滤逻辑。

**Tech Stack:** Flutter, Provider, SharedPreferences

---

## 文件结构

| 文件 | 职责 |
|------|------|
| `lib/features/settings/data/scan_options_provider.dart` | 扫描选项数据管理（新建） |
| `lib/features/settings/presentation/pages/scan_settings_page.dart` | 扫描设置页面（新建） |
| `lib/main.dart` | 修改导航逻辑 |
| `lib/shared/utils/music_scanner.dart` | 添加高级选项参数 |
| `lib/shared/utils/platform_music_scanner.dart` | 添加高级选项参数到基类 |
| `lib/shared/utils/windows_music_scanner.dart` | 应用高级选项过滤 |
| `lib/shared/utils/mobile_music_scanner.dart` | 应用高级选项过滤 |

---

### Task 1: 创建 ScanOptionsProvider

**Files:**
- Create: `lib/features/settings/data/scan_options_provider.dart`
- Test: `test/scan_options_provider_test.dart`

- [ ] **Step 1: Write the failing test for ScanOptionsProvider**

```dart
// test/scan_options_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mysic/features/settings/data/scan_options_provider.dart';

void main() {
  group('ScanOptionsProvider', () {
    test('default values are correct', () {
      final provider = ScanOptionsProvider();

      expect(provider.audioFormats, containsAll(['mp3', 'flac', 'wav', 'm4a', 'ogg', 'aac', 'wma', 'ape']));
      expect(provider.minFileSizeKb, 100);
      expect(provider.autoDedupe, true);
    });

    test('toggleFormat removes format if present', () {
      final provider = ScanOptionsProvider();

      provider.toggleFormat('mp3');
      expect(provider.audioFormats, isNot(contains('mp3')));

      provider.toggleFormat('mp3');
      expect(provider.audioFormats, contains('mp3'));
    });

    test('setMinFileSizeKb updates value', () {
      final provider = ScanOptionsProvider();

      provider.setMinFileSizeKb(500);
      expect(provider.minFileSizeKb, 500);
    });

    test('setAutoDedupe updates value', () {
      final provider = ScanOptionsProvider();

      provider.setAutoDedupe(false);
      expect(provider.autoDedupe, false);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mysic_flutter && flutter test test/scan_options_provider_test.dart`
Expected: FAIL with "Error: Not found: 'package:mysic/features/settings/data/scan_options_provider.dart'"

- [ ] **Step 3: Write ScanOptionsProvider implementation**

```dart
// lib/features/settings/data/scan_options_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 扫描选项配置管理
class ScanOptionsProvider extends ChangeNotifier {
  /// 支持的音频格式列表
  static const List<String> kDefaultFormats = [
    'mp3', 'flac', 'wav', 'm4a', 'ogg', 'aac', 'wma', 'ape'
  ];

  /// 默认最小文件大小 (KB)
  static const int kDefaultMinFileSizeKb = 100;

  /// 默认自动去重
  static const bool kDefaultAutoDedupe = true;

  List<String> _audioFormats = List.from(kDefaultFormats);
  int _minFileSizeKb = kDefaultMinFileSizeKb;
  bool _autoDedupe = kDefaultAutoDedupe;
  bool _isLoaded = false;

  /// 要扫描的音频格式
  List<String> get audioFormats => List.unmodifiable(_audioFormats);

  /// 最小文件大小 (KB)
  int get minFileSizeKb => _minFileSizeKb;

  /// 是否自动去重
  bool get autoDedupe => _autoDedupe;

  /// 是否已加载
  bool get isLoaded => _isLoaded;

  /// 从 SharedPreferences 加载配置
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    _audioFormats = prefs.getStringList('scan_audio_formats') ?? List.from(kDefaultFormats);
    _minFileSizeKb = prefs.getInt('scan_min_file_size_kb') ?? kDefaultMinFileSizeKb;
    _autoDedupe = prefs.getBool('scan_auto_dedupe') ?? kDefaultAutoDedupe;
    _isLoaded = true;

    notifyListeners();
  }

  /// 切换音频格式
  void toggleFormat(String format) {
    if (_audioFormats.contains(format)) {
      _audioFormats.remove(format);
    } else {
      _audioFormats.add(format);
    }
    _saveFormats();
    notifyListeners();
  }

  /// 设置最小文件大小
  Future<void> setMinFileSizeKb(int value) async {
    _minFileSizeKb = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('scan_min_file_size_kb', value);
    notifyListeners();
  }

  /// 设置自动去重
  Future<void> setAutoDedupe(bool value) async {
    _autoDedupe = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('scan_auto_dedupe', value);
    notifyListeners();
  }

  /// 重置为默认值
  Future<void> resetToDefaults() async {
    _audioFormats = List.from(kDefaultFormats);
    _minFileSizeKb = kDefaultMinFileSizeKb;
    _autoDedupe = kDefaultAutoDedupe;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('scan_audio_formats', _audioFormats);
    await prefs.setInt('scan_min_file_size_kb', _minFileSizeKb);
    await prefs.setBool('scan_auto_dedupe', _autoDedupe);

    notifyListeners();
  }

  /// 保存格式列表
  Future<void> _saveFormats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('scan_audio_formats', _audioFormats);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mysic_flutter && flutter test test/scan_options_provider_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/data/scan_options_provider.dart test/scan_options_provider_test.dart
git commit -m "feat(settings): 添加 ScanOptionsProvider 管理扫描选项"
```

---

### Task 2: 创建 ScanSettingsPage 页面

**Files:**
- Create: `lib/features/settings/presentation/pages/scan_settings_page.dart`

- [ ] **Step 1: 创建 ScanSettingsPage 基础结构**

```dart
// lib/features/settings/presentation/pages/scan_settings_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/scan_options_provider.dart';
import '../widgets/scan_directory_list.dart';
import '../../../../shared/utils/music_scanner.dart';
import '../../../../features/player/presentation/providers/player_provider.dart';

/// 扫描设置页面
class ScanSettingsPage extends StatefulWidget {
  const ScanSettingsPage({super.key});

  @override
  State<ScanSettingsPage> createState() => _ScanSettingsPageState();
}

class _ScanSettingsPageState extends State<ScanSettingsPage> {
  bool _isScanning = false;
  double _scanProgress = 0.0;
  MusicScanner? _currentScanner;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScanOptionsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _buildAppBar(),
      body: Consumer<ScanOptionsProvider>(
        builder: (context, optionsProvider, child) {
          if (!optionsProvider.isLoaded) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }
          return _buildBody(optionsProvider);
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Column(
        children: [
          Text(
            '设置',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          Text(
            '扫描设置',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      centerTitle: true,
    );
  }

  Widget _buildBody(ScanOptionsProvider optionsProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 扫描操作区
          _buildScanButton(optionsProvider),
          const SizedBox(height: 24),

          // 扫描目录管理
          const ScanDirectoryList(),
          const SizedBox(height: 24),

          // 高级选项
          _buildAdvancedOptions(optionsProvider),
        ],
      ),
    );
  }

  Widget _buildScanButton(ScanOptionsProvider optionsProvider) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: _isScanning ? null : AppColors.accentGradient,
        color: _isScanning ? AppColors.card : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _isScanning
            ? null
            : [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isScanning ? null : () => _startScan(optionsProvider),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _isScanning
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          value: _scanProgress,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                          backgroundColor: AppColors.muted.withValues(alpha: 0.3),
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, color: AppColors.white, size: 24),
                const SizedBox(width: 12),
                Text(
                  _isScanning ? '扫描中 ${(_scanProgress * 100).toInt()}%' : '开始扫描',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedOptions(ScanOptionsProvider optionsProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '高级选项',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        const SizedBox(height: 16),

        // 文件格式过滤
        _buildFormatFilter(optionsProvider),
        const SizedBox(height: 16),

        // 最小文件大小
        _buildMinFileSizeOption(optionsProvider),
        const SizedBox(height: 16),

        // 自动去重
        _buildAutoDedupeOption(optionsProvider),
      ],
    );
  }

  Widget _buildFormatFilter(ScanOptionsProvider optionsProvider) {
    final formats = ['mp3', 'flac', 'wav', 'm4a', 'ogg', 'aac', 'wma', 'ape'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '文件格式过滤',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.white),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: formats.map((format) {
              final isSelected = optionsProvider.audioFormats.contains(format);
              return _buildFormatChip(format, isSelected, () {
                optionsProvider.toggleFormat(format);
              });
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withValues(alpha: 0.2) : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.muted.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              size: 16,
              color: isSelected ? AppColors.accent : AppColors.muted,
            ),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? AppColors.accent : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinFileSizeOption(ScanOptionsProvider optionsProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '最小文件大小',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.white),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.white),
                  decoration: InputDecoration(
                    hintText: '100',
                    hintStyle: const TextStyle(color: AppColors.muted),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  controller: TextEditingController(text: optionsProvider.minFileSizeKb.toString()),
                  onSubmitted: (value) {
                    final kb = int.tryParse(value);
                    if (kb != null && kb > 0) {
                      optionsProvider.setMinFileSizeKb(kb);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              const Text('KB', style: TextStyle(color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '过滤掉过小的音频文件',
            style: TextStyle(fontSize: 12, color: AppColors.muted.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoDedupeOption(ScanOptionsProvider optionsProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '自动去重',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  '扫描时自动跳过已存在的歌曲',
                  style: TextStyle(fontSize: 12, color: AppColors.muted.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          _buildToggle(
            optionsProvider.autoDedupe,
            (value) => optionsProvider.setAutoDedupe(value),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: 48,
        height: 28,
        decoration: BoxDecoration(
          color: value ? AppColors.accent : AppColors.muted.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedAlign(
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: value ? AppColors.white : AppColors.muted,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startScan(ScanOptionsProvider optionsProvider) async {
    final playerProvider = context.read<PlayerProvider>();
    playerProvider.startScan();

    setState(() {
      _isScanning = true;
      _scanProgress = 0.0;
    });

    try {
      final scanner = MusicScanner(
        audioFormats: optionsProvider.audioFormats,
        minFileSizeKb: optionsProvider.minFileSizeKb,
        autoDedupe: optionsProvider.autoDedupe,
      );
      _currentScanner = scanner;

      scanner.progressStream.listen((progress) {
        if (mounted) {
          setState(() {
            _scanProgress = progress.progress;
          });
          playerProvider.updateScanProgress(progress.progress);
        }
      });

      final result = await scanner.scanMusic();

      if (mounted && result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('扫描完成: 发现 ${result.totalFound} 首，新增 ${result.newAdded} 首'),
            backgroundColor: AppColors.accent,
          ),
        );
      }
    } finally {
      if (mounted) {
        playerProvider.finishScan();
        setState(() {
          _isScanning = false;
          _currentScanner = null;
        });
      }
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/settings/presentation/pages/scan_settings_page.dart
git commit -m "feat(settings): 创建 ScanSettingsPage 页面"
```

---

### Task 3: 修改 MusicScanner 支持高级选项

**Files:**
- Modify: `lib/shared/utils/music_scanner.dart`
- Modify: `lib/shared/utils/platform_music_scanner.dart`

- [ ] **Step 1: 修改 PlatformMusicScanner 基类添加选项参数**

在 `lib/shared/utils/platform_music_scanner.dart` 中添加 `ScanOptions` 类和修改基类：

```dart
// 在文件顶部添加 ScanOptions 类

/// 扫描选项配置
class ScanOptions {
  final List<String> audioFormats;
  final int minFileSizeKb;
  final bool autoDedupe;

  const ScanOptions({
    this.audioFormats = const ['mp3', 'flac', 'wav', 'm4a', 'ogg', 'aac', 'wma', 'ape'],
    this.minFileSizeKb = 100,
    this.autoDedupe = true,
  });

  /// 最小文件大小（字节）
  int get minFileSizeBytes => minFileSizeKb * 1024;

  /// 音频格式扩展名集合
  Set<String> get audioExtensions => audioFormats.map((f) => '.$f').toSet();
}

// 在 PlatformMusicScanner 类中添加 options 属性

abstract class PlatformMusicScanner {
  // ... 现有代码 ...

  /// 扫描选项
  ScanOptions _options = const ScanOptions();
  ScanOptions get options => _options;

  /// 设置扫描选项
  void setOptions(ScanOptions options) {
    _options = options;
  }

  // ... 其余代码保持不变 ...
}
```

- [ ] **Step 2: 修改 MusicScanner 构造函数**

在 `lib/shared/utils/music_scanner.dart` 中修改构造函数：

```dart
/// 音乐扫描服务
class MusicScanner {
  late final PlatformMusicScanner _platformScanner;

  MusicScanner({
    List<String>? audioFormats,
    int? minFileSizeKb,
    bool? autoDedupe,
  }) {
    if (Platform.isWindows || Platform.isLinux) {
      _platformScanner = WindowsMusicScanner();
    } else {
      _platformScanner = MobileMusicScanner();
    }

    // 设置扫描选项
    if (audioFormats != null || minFileSizeKb != null || autoDedupe != null) {
      _platformScanner.setOptions(ScanOptions(
        audioFormats: audioFormats ?? ScanOptions().audioFormats,
        minFileSizeKb: minFileSizeKb ?? ScanOptions().minFileSizeKb,
        autoDedupe: autoDedupe ?? ScanOptions().autoDedupe,
      ));
    }
  }

  // ... 其余代码保持不变 ...
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/shared/utils/music_scanner.dart lib/shared/utils/platform_music_scanner.dart
git commit -m "feat(scanner): 添加扫描选项参数支持"
```

---

### Task 4: 修改 WindowsMusicScanner 应用高级选项

**Files:**
- Modify: `lib/shared/utils/windows_music_scanner.dart`

- [ ] **Step 1: 修改 WindowsMusicScanner 使用 options**

在 `lib/shared/utils/windows_music_scanner.dart` 中：

1. 删除硬编码的 `_audioExtensions` 和 `_minFileSizeBytes` 常量
2. 在 `_scanDirectory` 方法中使用 `options.audioExtensions` 和 `options.minFileSizeBytes`
3. 在 `_saveSongsToDatabase` 方法中根据 `options.autoDedupe` 决定是否跳过重复检查

修改 `_scanDirectory` 方法：

```dart
// 将原来的:
// if (fileSize >= _minFileSizeBytes)
// 改为:
// if (fileSize >= options.minFileSizeBytes)

// 将原来的:
// for (final ext in _audioExtensions)
// 改为:
// for (final ext in options.audioExtensions)
```

修改 `_saveSongsToDatabase` 方法：

```dart
// 在检查重复时:
if (options.autoDedupe) {
  if (existingPaths.contains(filePath)) {
    duplicates++;
    continue;
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/shared/utils/windows_music_scanner.dart
git commit -m "feat(scanner): WindowsMusicScanner 应用高级选项过滤"
```

---

### Task 5: 修改 MobileMusicScanner 应用高级选项

**Files:**
- Modify: `lib/shared/utils/mobile_music_scanner.dart`

- [ ] **Step 1: 与 Task 4 相同的修改**

在 `lib/shared/utils/mobile_music_scanner.dart` 中应用与 WindowsMusicScanner 相同的修改：

1. 删除硬编码的 `_audioExtensions` 和 `_minFileSizeBytes` 常量
2. 在 `_scanDirectory` 方法中使用 `options.audioExtensions` 和 `options.minFileSizeBytes`
3. 在 `_saveSongsToDatabase` 方法中根据 `options.autoDedupe` 决定是否跳过重复检查

- [ ] **Step 2: Commit**

```bash
git add lib/shared/utils/mobile_music_scanner.dart
git commit -m "feat(scanner): MobileMusicScanner 应用高级选项过滤"
```

---

### Task 6: 修改 main.dart 导航逻辑

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: 添加 ScanOptionsProvider 到 MultiProvider**

在 `lib/main.dart` 中：

```dart
// 添加 import
import 'features/settings/data/scan_options_provider.dart';
import 'features/settings/presentation/pages/scan_settings_page.dart';

// 修改 MultiProvider
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => PlayerProvider()),
    ChangeNotifierProvider(create: (_) => PlaylistProvider()),
    ChangeNotifierProvider(create: (_) => ApiConfigProvider()..load()),
    ChangeNotifierProvider(create: (_) => AiSkillsProvider()),
    ChangeNotifierProvider(create: (_) => ScanOptionsProvider()..load()), // 添加
  ],
  // ...
)
```

- [ ] **Step 2: 修改 _showScanSettings 方法**

```dart
void _showScanSettings(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => const ScanSettingsPage(),
    ),
  );
}
```

- [ ] **Step 3: 删除 _ScanSettingsSheet 类**

删除 `main.dart` 中不再需要的 `_ScanSettingsSheet` 类。

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: 修改扫描设置导航为独立页面"
```

---

### Task 7: 编写集成测试

**Files:**
- Create: `test/widgets/scan_settings_page_test.dart`

- [ ] **Step 1: 编写测试**

```dart
// test/widgets/scan_settings_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mysic/features/settings/presentation/pages/scan_settings_page.dart';
import 'package:mysic/features/settings/data/scan_options_provider.dart';

void main() {
  group('ScanSettingsPage', () {
    testWidgets('shows scan button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => ScanOptionsProvider()..load(),
            child: const ScanSettingsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('开始扫描'), findsOneWidget);
    });

    testWidgets('shows format filter options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => ScanOptionsProvider()..load(),
            child: const ScanSettingsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('文件格式过滤'), findsOneWidget);
      expect(find.text('MP3'), findsOneWidget);
    });

    testWidgets('shows min file size option', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => ScanOptionsProvider()..load(),
            child: const ScanSettingsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('最小文件大小'), findsOneWidget);
    });

    testWidgets('shows auto dedupe option', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => ScanOptionsProvider()..load(),
            child: const ScanSettingsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('自动去重'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: 运行测试**

Run: `cd mysic_flutter && flutter test test/widgets/scan_settings_page_test.dart`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add test/widgets/scan_settings_page_test.dart
git commit -m "test: 添加 ScanSettingsPage 测试"
```

---

### Task 8: 运行完整测试并验证

- [ ] **Step 1: 运行所有测试**

Run: `cd mysic_flutter && flutter test`
Expected: All tests pass

- [ ] **Step 2: 运行静态分析**

Run: `cd mysic_flutter && flutter analyze`
Expected: No issues found

- [ ] **Step 3: 手动测试**

Run: `cd mysic_flutter && flutter run -d windows`

验证：
1. 点击抽屉菜单中的"扫描设置"按钮
2. 确认跳转到独立页面
3. 确认页面显示扫描按钮、目录管理、高级选项
4. 确认高级选项可以修改并保存

- [ ] **Step 4: 最终提交**

```bash
git add -A
git commit -m "feat: 完成扫描设置独立页面功能"
```
