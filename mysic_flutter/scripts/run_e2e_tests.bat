@echo off
REM 端到端测试运行脚本 (Windows)
REM 用于自动化执行 Flutter 集成测试

echo ==========================================
echo   Mysic 端到端测试
echo ==========================================
echo.

REM 进入 Flutter 项目目录
cd mysic_flutter

REM 检查 Flutter 环境
echo ^>^>^> 检查 Flutter 环境...
flutter --version
echo.

REM 获取依赖
echo ^>^>^> 获取依赖...
flutter pub get
echo.

REM 分析代码
echo ^>^>^> 分析代码...
flutter analyze
echo.

REM 运行单元测试
echo ^>^>^> 运行单元测试...
flutter test --reporter=compact
echo.

REM 运行集成测试
echo ^>^>^> 运行集成测试...
flutter test integration_test/app_test.dart -d windows
echo.

REM 运行端到端测试
echo ^>^>^> 运行端到端测试...
flutter test integration_test/e2e_test.dart -d windows
echo.

echo ==========================================
echo   测试完成!
echo ==========================================
pause
