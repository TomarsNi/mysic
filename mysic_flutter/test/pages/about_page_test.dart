import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/core/theme/app_colors.dart';
import 'package:mysic_flutter/features/settings/presentation/pages/about_page.dart';

void main() {
  group('AboutPage', () {
    testWidgets('should render app header with correct app name',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AboutPage(),
        ),
      );

      // 验证应用名称显示
      expect(find.text('Mysic'), findsOneWidget);

      // 验证应用标语显示
      expect(find.text('本地音乐播放器'), findsOneWidget);

      // 验证应用图标存在
      expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    });

    testWidgets('should display version information',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AboutPage(
            appVersion: '2.0.0',
            buildNumber: '100',
          ),
        ),
      );

      // 验证版本信息显示
      expect(find.text('v2.0.0 (100)'), findsOneWidget);
    });

    testWidgets('should display custom developer information',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AboutPage(
            developerName: 'TestDeveloper',
            developerWebsite: 'https://example.com',
            developerEmail: 'test@example.com',
          ),
        ),
      );

      // 验证开发者名称显示
      expect(find.text('TestDeveloper'), findsOneWidget);

      // 验证网站显示
      expect(find.text('https://example.com'), findsOneWidget);

      // 验证邮箱显示
      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('should display app description',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AboutPage(),
        ),
      );

      // 验证应用描述显示
      expect(
        find.textContaining('Mysic 是一款简洁优雅的本地音乐播放器'),
        findsOneWidget,
      );
    });

    testWidgets('should display support section',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AboutPage(),
        ),
      );

      // 验证支持作者标题
      expect(find.text('支持作者'), findsOneWidget);

      // 验证支持按钮存在
      expect(find.text('给个 Star'), findsOneWidget);
      expect(find.text('请喝咖啡'), findsOneWidget);
    });

    testWidgets('should display legal links when provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AboutPage(
            licenseUrl: 'https://example.com/license',
            privacyPolicyUrl: 'https://example.com/privacy',
            termsOfServiceUrl: 'https://example.com/terms',
          ),
        ),
      );

      // 验证法律信息标题
      expect(find.text('法律信息'), findsOneWidget);

      // 验证链接项存在
      expect(find.text('开源许可证'), findsOneWidget);
      expect(find.text('隐私政策'), findsOneWidget);
      expect(find.text('服务条款'), findsOneWidget);
    });

    testWidgets('should not display legal links when not provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AboutPage(),
        ),
      );

      // 法律信息区域不应显示
      expect(find.text('法律信息'), findsNothing);
    });

    testWidgets('should display copyright with current year',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AboutPage(
            developerName: 'TestDev',
          ),
        ),
      );

      final year = DateTime.now().year;

      // 验证版权信息
      expect(find.textContaining('Made with'), findsOneWidget);
      expect(find.textContaining('© $year'), findsOneWidget);
    });

    testWidgets('should have back button in app bar',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AboutPage(),
        ),
      );

      // 验证返回按钮存在
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('should have correct app bar title',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AboutPage(),
        ),
      );

      // 验证标题
      expect(find.text('关于'), findsOneWidget);
    });

    testWidgets('should show snackbar when version is tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AboutPage(
            appVersion: '1.0.0',
            buildNumber: '1',
          ),
        ),
      );

      // 找到版本行并点击
      final versionRow = find.ancestor(
        of: find.text('v1.0.0 (1)'),
        matching: find.byType(InkWell),
      );

      await tester.tap(versionRow);
      await tester.pumpAndSettle();

      // 验证 SnackBar 显示
      expect(find.text('版本信息已复制'), findsOneWidget);
    });

    testWidgets('should show star dialog when star button is tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AboutPage(),
        ),
      );

      // 滚动到底部找到支持区域
      await tester.dragUntilVisible(
        find.text('给个 Star'),
        find.byType(SingleChildScrollView),
        const Offset(0, -50),
      );

      // 找到并点击 Star 按钮
      await tester.tap(find.text('给个 Star'));
      await tester.pumpAndSettle();

      // 验证对话框显示
      expect(find.text('感谢支持'), findsOneWidget);
      expect(find.text('前往 GitHub'), findsOneWidget);

      // 关闭对话框
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
    });

    testWidgets('should show donate dialog when coffee button is tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AboutPage(),
        ),
      );

      // 滚动到底部找到支持区域
      await tester.dragUntilVisible(
        find.text('请喝咖啡'),
        find.byType(SingleChildScrollView),
        const Offset(0, -50),
      );

      // 找到并点击请喝咖啡按钮
      await tester.tap(find.text('请喝咖啡'));
      await tester.pumpAndSettle();

      // 验证对话框显示
      expect(find.text('请喝咖啡'), findsWidgets);
      expect(find.text('感谢您的支持！'), findsOneWidget);

      // 关闭对话框
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
    });

    testWidgets('should use correct theme colors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AboutPage(),
        ),
      );

      // 验证背景色
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.surface);

      // 验证应用图标容器使用渐变
      final container = tester.widget<Container>(
        find.ancestor(
          of: find.byIcon(Icons.music_note_rounded),
          matching: find.byType(Container).first,
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.gradient, AppColors.accentGradient);
    });

    testWidgets('should display technology stack info',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AboutPage(),
        ),
      );

      // 验证技术栈信息
      expect(find.text('技术栈'), findsOneWidget);
      expect(find.text('Flutter'), findsOneWidget);

      // 验证平台信息
      expect(find.text('支持平台'), findsOneWidget);
      expect(find.text('Android / iOS / Windows'), findsOneWidget);
    });

    testWidgets('should be scrollable',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AboutPage(),
        ),
      );

      // 验证页面可滚动
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });

  group('InfoRow widget', () {
    testWidgets('should display developer info correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AboutPage(
            developerName: 'UniqueTestDev',
            developerWebsite: 'https://uniquetest.com',
          ),
        ),
      );

      // 验证开发者名称显示
      expect(find.text('UniqueTestDev'), findsOneWidget);

      // 验证网站显示
      expect(find.text('https://uniquetest.com'), findsOneWidget);
    });
  });

  group('LinkTile widget', () {
    testWidgets('should display link tiles when URLs are provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AboutPage(
            licenseUrl: 'https://example.com/license',
            privacyPolicyUrl: 'https://example.com/privacy',
          ),
        ),
      );

      // 验证链接项显示
      expect(find.text('开源许可证'), findsOneWidget);
      expect(find.text('隐私政策'), findsOneWidget);

      // 验证右箭头图标存在
      expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);
    });
  });

  group('SupportButton widget', () {
    testWidgets('should display support buttons',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AboutPage(),
        ),
      );

      // 验证支持按钮显示
      expect(find.text('给个 Star'), findsOneWidget);
      expect(find.text('请喝咖啡'), findsOneWidget);

      // 验证图标存在
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.byIcon(Icons.coffee_rounded), findsOneWidget);
    });
  });
}
