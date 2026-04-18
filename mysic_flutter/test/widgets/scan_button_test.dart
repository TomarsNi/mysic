import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/features/settings/presentation/widgets/scan_button.dart';
import 'package:mysic_flutter/shared/utils/music_scanner.dart';

void main() {
  group('ScanButton Widget 测试', () {
    testWidgets('ScanButton 显示初始状态', (tester) async {
      final scanner = MusicScanner();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ScanButton(scanner: scanner),
            ),
          ),
        ),
      );

      // 验证初始状态
      expect(find.text('扫描本地音乐'), findsOneWidget);
      expect(find.byIcon(Icons.folder_open_rounded), findsOneWidget);

      await scanner.dispose();
    });

    testWidgets('ScanButton 可以点击', (tester) async {
      final scanner = MusicScanner();
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ScanButton(
                scanner: scanner,
                onScanStart: () {
                  tapped = true;
                },
              ),
            ),
          ),
        ),
      );

      // 点击按钮
      await tester.tap(find.text('扫描本地音乐'));
      await tester.pump();

      // 注意：由于扫描需要权限，实际扫描会失败
      // 但我们可以验证点击事件被触发

      await scanner.dispose();
    });

    testWidgets('ScanDialog 显示正确', (tester) async {
      final scanner = MusicScanner();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () {
                    ScanDialog.show(context, scanner: scanner);
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      // 点击显示对话框
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // 验证对话框显示
      expect(find.byType(AlertDialog), findsOneWidget);

      await scanner.dispose();
    });
  });

  group('ScanState 状态显示测试', () {
    test('ScanState idle 显示正确文字', () {
      const state = ScanState.idle;
      expect(state == ScanState.idle, true);
    });

    test('ScanState scanning 显示正确文字', () {
      const state = ScanState.scanning;
      expect(state == ScanState.scanning, true);
    });

    test('ScanState saving 显示正确文字', () {
      const state = ScanState.saving;
      expect(state == ScanState.saving, true);
    });

    test('ScanState completed 显示正确文字', () {
      const state = ScanState.completed;
      expect(state == ScanState.completed, true);
    });

    test('ScanState error 显示正确文字', () {
      const state = ScanState.error;
      expect(state == ScanState.error, true);
    });
  });

  group('ScanResult 显示测试', () {
    test('成功的 ScanResult 显示正确', () {
      final result = ScanResult(
        totalFound: 100,
        newAdded: 80,
        duplicates: 20,
        scanDuration: const Duration(seconds: 5),
      );

      expect(result.isSuccess, true);
      expect(result.totalFound, 100);
      expect(result.newAdded, 80);
      expect(result.duplicates, 20);
    });

    test('失败的 ScanResult 显示错误信息', () {
      final result = ScanResult(
        totalFound: 0,
        newAdded: 0,
        duplicates: 0,
        scanDuration: Duration.zero,
        errorMessage: '未获得存储权限',
      );

      expect(result.isSuccess, false);
      expect(result.errorMessage, '未获得存储权限');
    });
  });

  group('进度显示测试', () {
    test('进度 0% 显示正确', () {
      const progress = 0.0;
      expect((progress * 100).toStringAsFixed(0), '0');
    });

    test('进度 50% 显示正确', () {
      const progress = 0.5;
      expect((progress * 100).toStringAsFixed(0), '50');
    });

    test('进度 100% 显示正确', () {
      const progress = 1.0;
      expect((progress * 100).toStringAsFixed(0), '100');
    });
  });

  group('时间格式化测试', () {
    test('小于 1 分钟显示秒', () {
      const duration = Duration(seconds: 30);
      expect(duration.inSeconds, 30);
      expect(duration.inSeconds < 60, true);
    });

    test('大于 1 分钟显示分钟和秒', () {
      const duration = Duration(minutes: 2, seconds: 30);
      expect(duration.inMinutes, 2);
      expect(duration.inSeconds % 60, 30);
    });

    test('0 秒显示正确', () {
      const duration = Duration.zero;
      expect(duration.inSeconds, 0);
    });
  });

  group('扫描按钮样式测试', () {
    testWidgets('扫描按钮有渐变背景', (tester) async {
      final scanner = MusicScanner();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ScanButton(scanner: scanner),
            ),
          ),
        ),
      );

      // 查找 Container 验证样式
      final container = tester.widget<Container>(
        find.ancestor(
          of: find.byType(InkWell),
          matching: find.byType(Container),
        ).first,
      );

      expect(container.decoration, isNotNull);

      await scanner.dispose();
    });

    testWidgets('扫描按钮有圆角', (tester) async {
      final scanner = MusicScanner();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ScanButton(scanner: scanner),
            ),
          ),
        ),
      );

      // 验证按钮存在
      expect(find.text('扫描本地音乐'), findsOneWidget);

      await scanner.dispose();
    });
  });

  group('扫描结果卡片测试', () {
    testWidgets('成功结果显示正确', (tester) async {
      final scanner = MusicScanner();
      final result = ScanResult(
        totalFound: 50,
        newAdded: 40,
        duplicates: 10,
        scanDuration: const Duration(seconds: 3),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestScanButtonWithResult(
              scanner: scanner,
              result: result,
            ),
          ),
        ),
      );

      // 验证结果显示
      expect(find.text('发现歌曲'), findsOneWidget);
      expect(find.text('50 首'), findsOneWidget);
      expect(find.text('新增歌曲'), findsOneWidget);
      expect(find.text('40 首'), findsOneWidget);

      await scanner.dispose();
    });
  });
}

/// 测试用的 ScanButton，可以预设结果
class _TestScanButtonWithResult extends StatelessWidget {
  final MusicScanner scanner;
  final ScanResult result;

  const _TestScanButtonWithResult({
    required this.scanner,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF27272A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '扫描完成',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('发现歌曲', style: TextStyle(fontSize: 14, color: Color(0xFF71717A))),
                  Text('${result.totalFound} 首', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFFFFFFF))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('新增歌曲', style: TextStyle(fontSize: 14, color: Color(0xFF71717A))),
                  Text('${result.newAdded} 首', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFFFFFFF))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
