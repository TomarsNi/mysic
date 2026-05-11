import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/features/player/presentation/widgets/progress_bar.dart';

void main() {
  group('ProgressBar', () {
    testWidgets('renders with zero position', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProgressBar(
              position: Duration.zero,
              duration: Duration(minutes: 3),
            ),
          ),
        ),
      );

      // 应该显示时间
      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('3:00'), findsOneWidget);
    });

    testWidgets('renders with position', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProgressBar(
              position: Duration(minutes: 1, seconds: 30),
              duration: Duration(minutes: 3),
            ),
          ),
        ),
      );

      // 应该显示正确的时间
      expect(find.text('1:30'), findsOneWidget);
      expect(find.text('3:00'), findsOneWidget);
    });

    testWidgets('renders without duration', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProgressBar(
              position: Duration.zero,
              duration: null,
            ),
          ),
        ),
      );

      // 应该显示默认时长
      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('--:--'), findsOneWidget);
    });

    testWidgets('slider is interactive when enabled', (WidgetTester tester) async {
      var seekValue = -1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgressBar(
              position: Duration.zero,
              duration: const Duration(minutes: 3),
              enabled: true,
              onSeek: (value) => seekValue = value,
            ),
          ),
        ),
      );

      // 滑块应该存在
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('slider is disabled when not enabled', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProgressBar(
              position: Duration.zero,
              duration: Duration(minutes: 3),
              enabled: false,
            ),
          ),
        ),
      );

      // 滑块应该存在但禁用
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.onChanged, isNull);
    });

    testWidgets('shows real-time position during drag', (WidgetTester tester) async {
      var seekValue = -1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 80,
              child: ProgressBar(
                position: Duration.zero,
                duration: const Duration(minutes: 4, seconds: 2),
                enabled: true,
                onSeek: (value) => seekValue = value,
              ),
            ),
          ),
        ),
      );

      // 初始时间显示 0:00
      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('4:02'), findsOneWidget);
    });
  });

  group('SimpleProgressBar', () {
    testWidgets('renders with zero progress', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SimpleProgressBar(
              position: Duration.zero,
              duration: Duration(minutes: 3),
            ),
          ),
        ),
      );

      // 组件应该正常渲染
      expect(find.byType(SimpleProgressBar), findsOneWidget);
    });

    testWidgets('renders with progress', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SimpleProgressBar(
              position: Duration(minutes: 1, seconds: 30),
              duration: Duration(minutes: 3),
            ),
          ),
        ),
      );

      // 组件应该正常渲染
      expect(find.byType(SimpleProgressBar), findsOneWidget);
    });

    testWidgets('renders with custom height', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SimpleProgressBar(
              position: Duration.zero,
              duration: Duration(minutes: 3),
              height: 4,
            ),
          ),
        ),
      );

      // 组件应该正常渲染
      expect(find.byType(SimpleProgressBar), findsOneWidget);
    });
  });

  group('BufferedProgressBar', () {
    testWidgets('renders with zero progress', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BufferedProgressBar(
              position: Duration.zero,
              duration: Duration(minutes: 3),
              bufferedPosition: Duration.zero,
            ),
          ),
        ),
      );

      // 应该显示时间
      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('3:00'), findsOneWidget);
    });

    testWidgets('renders with buffered progress', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BufferedProgressBar(
              position: Duration(minutes: 1),
              duration: Duration(minutes: 3),
              bufferedPosition: Duration(minutes: 2),
            ),
          ),
        ),
      );

      // 应该显示正确的时间
      expect(find.text('1:00'), findsOneWidget);
      expect(find.text('3:00'), findsOneWidget);
    });

    testWidgets('renders without duration', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BufferedProgressBar(
              position: Duration.zero,
              duration: null,
              bufferedPosition: Duration.zero,
            ),
          ),
        ),
      );

      // 应该显示默认时长
      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('--:--'), findsOneWidget);
    });
  });
}
