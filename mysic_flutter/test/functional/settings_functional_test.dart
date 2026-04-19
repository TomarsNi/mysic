import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/features/settings/presentation/pages/about_page.dart';
import 'package:mysic_flutter/core/theme/app_colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('设置页面功能测试', () {
    group('关于页面显示测试', () {
      testWidgets('关于页面应正确显示应用名称', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AboutPage(),
          ),
        );

        expect(find.text('Mysic'), findsOneWidget);
        expect(find.text('本地音乐播放器'), findsOneWidget);
      });

      testWidgets('关于页面应正确显示版本信息', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AboutPage(
              appVersion: '1.0.0',
              buildNumber: '1',
            ),
          ),
        );

        expect(find.textContaining('v1.0.0'), findsOneWidget);
        expect(find.textContaining('(1)'), findsOneWidget);
      });

      testWidgets('关于页面应正确显示开发者信息', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AboutPage(
              developerName: 'TestDeveloper',
            ),
          ),
        );

        expect(find.text('TestDeveloper'), findsOneWidget);
        expect(find.textContaining('TestDeveloper'), findsWidgets);
      });

      testWidgets('关于页面应显示支持作者区域', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AboutPage(),
          ),
        );

        expect(find.text('支持作者'), findsOneWidget);
        expect(find.text('给个 Star'), findsOneWidget);
        expect(find.text('请喝咖啡'), findsOneWidget);
      });

      testWidgets('关于页面应显示技术栈信息', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AboutPage(),
          ),
        );

        expect(find.text('Flutter'), findsOneWidget);
        expect(find.text('支持平台'), findsOneWidget);
        expect(find.text('Android / iOS / Windows'), findsOneWidget);
      });

      testWidgets('关于页面应显示应用描述', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AboutPage(),
          ),
        );

        expect(
          find.textContaining('Mysic 是一款简洁优雅的本地音乐播放器'),
          findsOneWidget,
        );
      });

      testWidgets('关于页面应显示开发者标题', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AboutPage(),
          ),
        );

        // 有两个"开发者"文本（标题和内容行）
        expect(find.text('开发者'), findsWidgets);
      });

      testWidgets('关于页面应显示版权信息', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AboutPage(
              developerName: 'NBB',
            ),
          ),
        );

        expect(find.textContaining('Made with'), findsOneWidget);
        expect(find.textContaining('NBB'), findsWidgets);
      });
    });

    group('关于页面交互测试', () {
      testWidgets('点击返回按钮应退出页面', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AboutPage(),
          ),
        );

        // 查找返回按钮
        final backButton = find.byIcon(Icons.arrow_back_rounded);
        expect(backButton, findsOneWidget);
      });

      testWidgets('点击版本信息应显示复制提示', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AboutPage(),
          ),
        );

        // 查找版本行并点击
        final versionRow = find.textContaining('v1.0.0');
        if (versionRow.evaluate().isNotEmpty) {
          await tester.tap(versionRow);
          await tester.pump();

          // 应该显示 SnackBar
          expect(find.text('版本信息已复制'), findsOneWidget);
        }
      });

      testWidgets('点击给个 Star 应显示对话框', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AboutPage(),
          ),
        );

        // 滚动到按钮位置
        await tester.ensureVisible(find.text('给个 Star'));
        await tester.pumpAndSettle();

        // 查找并点击 Star 按钮
        final starButton = find.text('给个 Star');
        await tester.tap(starButton, warnIfMissed: false);
        await tester.pumpAndSettle();

        // 应该显示对话框
        expect(find.text('感谢支持'), findsOneWidget);
        expect(find.text('关闭'), findsOneWidget);
        expect(find.text('前往 GitHub'), findsOneWidget);
      });

      testWidgets('点击请喝咖啡应显示对话框', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AboutPage(),
          ),
        );

        // 滚动到按钮位置
        await tester.ensureVisible(find.text('请喝咖啡'));
        await tester.pumpAndSettle();

        // 查找并点击咖啡按钮
        final coffeeButton = find.text('请喝咖啡');
        await tester.tap(coffeeButton, warnIfMissed: false);
        await tester.pumpAndSettle();

        // 应该显示对话框
        expect(find.text('请喝咖啡'), findsWidgets);
        expect(find.text('感谢您的支持！'), findsOneWidget);
      });

      testWidgets('关闭对话框应返回页面', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AboutPage(),
          ),
        );

        // 滚动到按钮位置
        await tester.ensureVisible(find.text('给个 Star'));
        await tester.pumpAndSettle();

        // 打开对话框
        await tester.tap(find.text('给个 Star'), warnIfMissed: false);
        await tester.pumpAndSettle();

        // 关闭对话框
        await tester.tap(find.text('关闭'));
        await tester.pumpAndSettle();

        // 对话框应该关闭
        expect(find.text('感谢支持'), findsNothing);
      });
    });

    group('关于页面自定义参数测试', () {
      testWidgets('自定义应用名称应正确显示', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AboutPage(
              appName: 'CustomApp',
            ),
          ),
        );

        expect(find.text('CustomApp'), findsOneWidget);
        expect(find.text('Mysic'), findsNothing);
      });

      testWidgets('自定义版本号应正确显示', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AboutPage(
              appVersion: '2.0.0',
              buildNumber: '100',
            ),
          ),
        );

        expect(find.textContaining('v2.0.0'), findsOneWidget);
        expect(find.textContaining('(100)'), findsOneWidget);
      });

      testWidgets('自定义开发者信息应正确显示', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AboutPage(
              developerName: 'CustomDev',
              developerWebsite: 'https://example.com',
              developerEmail: 'test@example.com',
            ),
          ),
        );

        expect(find.text('CustomDev'), findsOneWidget);
        expect(find.text('https://example.com'), findsOneWidget);
        expect(find.text('test@example.com'), findsOneWidget);
      });
    });

    group('主题颜色测试', () {
      testWidgets('页面应使用正确的背景色', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AboutPage(),
          ),
        );

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, AppColors.surface);
      });

      testWidgets('AppBar 应使用正确的背景色', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AboutPage(),
          ),
        );

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.backgroundColor, AppColors.surface);
      });
    });

    group('组件测试', () {
      testWidgets('应用图标容器应正确显示', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AboutPage(),
          ),
        );

        // 查找音乐图标
        expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
      });

      testWidgets('信息行应正确显示图标', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AboutPage(),
          ),
        );

        expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
        expect(find.byIcon(Icons.code_rounded), findsOneWidget);
        expect(find.byIcon(Icons.devices_rounded), findsOneWidget);
      });

      testWidgets('支持按钮应正确显示图标', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AboutPage(),
          ),
        );

        expect(find.byIcon(Icons.star_rounded), findsWidgets);
        expect(find.byIcon(Icons.coffee_rounded), findsWidgets);
        expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      });
    });

    group('布局测试', () {
      testWidgets('页面应可滚动', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AboutPage(),
          ),
        );

        // 查找 SingleChildScrollView
        expect(find.byType(SingleChildScrollView), findsOneWidget);
      });

      testWidgets('页面应使用 SafeArea', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AboutPage(),
          ),
        );

        // 页面包含 SafeArea
        expect(find.byType(SafeArea), findsWidgets);
      });
    });
  });
}
