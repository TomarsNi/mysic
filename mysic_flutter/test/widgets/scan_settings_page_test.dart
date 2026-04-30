import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/features/settings/data/scan_options_provider.dart';
import 'package:mysic_flutter/features/settings/presentation/widgets/scan_directory_list.dart';
import 'package:mysic_flutter/shared/utils/scan_directory_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake ScanDirectoryProvider for testing
class FakeScanDirectoryProvider implements ScanDirectoryProvider {
  List<String> _directories = ['Music', 'Downloads'];

  @override
  Future<List<String>> getDirectories() async {
    return List.unmodifiable(_directories);
  }

  @override
  Future<void> addDirectory(String directory) async {
    if (!_directories.contains(directory)) {
      _directories = [..._directories, directory];
    }
  }

  @override
  Future<void> removeDirectory(String directory) async {
    _directories = _directories.where((d) => d != directory).toList();
  }

  @override
  Future<void> resetToDefault() async {
    _directories = ['Music', 'Downloads', 'Audio'];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScanOptionsProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('default values are correct', () {
      final provider = ScanOptionsProvider();

      expect(
        provider.audioFormats,
        containsAll(['mp3', 'flac', 'wav', 'm4a', 'ogg', 'aac', 'wma', 'ape']),
      );
      expect(provider.minFileSizeKb, 100);
      expect(provider.autoDedupe, true);
    });

    test('toggleFormat removes format if present', () async {
      final provider = ScanOptionsProvider();

      await provider.toggleFormat('mp3');
      expect(provider.audioFormats, isNot(contains('mp3')));

      await provider.toggleFormat('mp3');
      expect(provider.audioFormats, contains('mp3'));
    });

    test('setMinFileSizeKb updates value', () async {
      final provider = ScanOptionsProvider();

      await provider.setMinFileSizeKb(500);
      expect(provider.minFileSizeKb, 500);
    });

    test('setAutoDedupe updates value', () async {
      final provider = ScanOptionsProvider();

      await provider.setAutoDedupe(false);
      expect(provider.autoDedupe, false);
    });

    test('load() sets isLoaded to true', () async {
      final provider = ScanOptionsProvider();

      expect(provider.isLoaded, false);

      await provider.load();

      expect(provider.isLoaded, true);
    });

    test('resetToDefaults restores default values', () async {
      final provider = ScanOptionsProvider();

      await provider.toggleFormat('mp3');
      await provider.setMinFileSizeKb(500);
      await provider.setAutoDedupe(false);

      await provider.resetToDefaults();

      expect(provider.audioFormats, contains('mp3'));
      expect(provider.minFileSizeKb, 100);
      expect(provider.autoDedupe, true);
    });
  });

  group('ScanDirectoryList with fake provider', () {
    testWidgets('shows directory list after loading', (tester) async {
      final fakeProvider = FakeScanDirectoryProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScanDirectoryList(provider: fakeProvider),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Should show the title
      expect(find.text('扫描目录管理'), findsOneWidget);
      // Should show default directories
      expect(find.text('Music'), findsOneWidget);
      expect(find.text('Downloads'), findsOneWidget);
    });

    testWidgets('shows add and reset buttons', (tester) async {
      final fakeProvider = FakeScanDirectoryProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScanDirectoryList(provider: fakeProvider),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Should show action buttons
      expect(find.text('添加目录'), findsOneWidget);
      expect(find.text('恢复默认'), findsOneWidget);
    });

    testWidgets('shows empty state when no directories', (tester) async {
      final fakeProvider = FakeScanDirectoryProvider();
      // Clear directories
      await fakeProvider.removeDirectory('Music');
      await fakeProvider.removeDirectory('Downloads');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScanDirectoryList(provider: fakeProvider),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Should show empty state message
      expect(find.text('暂无扫描目录，请添加'), findsOneWidget);
    });

    testWidgets('shows description text', (tester) async {
      final fakeProvider = FakeScanDirectoryProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScanDirectoryList(provider: fakeProvider),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Should show description
      expect(find.text('仅扫描以下目录中的音乐文件'), findsOneWidget);
    });

    testWidgets('shows loading indicator initially', (tester) async {
      final fakeProvider = FakeScanDirectoryProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScanDirectoryList(provider: fakeProvider),
          ),
        ),
      );

      // Before pump, should show loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('hides loading indicator after loading', (tester) async {
      final fakeProvider = FakeScanDirectoryProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScanDirectoryList(provider: fakeProvider),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // After loading, loading indicator should be gone
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows delete button for each directory', (tester) async {
      final fakeProvider = FakeScanDirectoryProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScanDirectoryList(provider: fakeProvider),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Should show delete icons for each directory
      expect(find.byIcon(Icons.delete_outline), findsWidgets);
    });
  });

  group('ScanOptionsProvider widget integration', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('provider notifies listeners on format toggle', (tester) async {
      final provider = ScanOptionsProvider();
      var notificationCount = 0;
      provider.addListener(() => notificationCount++);

      await provider.load();
      await provider.toggleFormat('mp3');

      expect(notificationCount, greaterThan(0));
    });

    testWidgets('provider notifies listeners on min file size change',
        (tester) async {
      final provider = ScanOptionsProvider();
      var notificationCount = 0;
      provider.addListener(() => notificationCount++);

      await provider.load();
      await provider.setMinFileSizeKb(500);

      expect(notificationCount, greaterThan(0));
    });

    testWidgets('provider notifies listeners on auto dedupe change',
        (tester) async {
      final provider = ScanOptionsProvider();
      var notificationCount = 0;
      provider.addListener(() => notificationCount++);

      await provider.load();
      await provider.setAutoDedupe(false);

      expect(notificationCount, greaterThan(0));
    });
  });
}
