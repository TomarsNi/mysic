@echo off
chcp 65001 >nul
echo ========================================
echo   Mysic 集成测试运行器
echo ========================================
echo.

cd /d "%~dp0.."

echo [1/3] 检查 Flutter 环境...
flutter --version >nul 2>&1
if errorlevel 1 (
    echo ✗ Flutter 未安装或未添加到 PATH
    pause
    exit /b 1
)
echo ✓ Flutter 环境正常

echo.
echo [2/3] 获取依赖...
flutter pub get
if errorlevel 1 (
    echo ✗ 获取依赖失败
    pause
    exit /b 1
)
echo ✓ 依赖获取成功

echo.
echo [3/3] 运行集成测试...
echo.
echo 选择测试模式:
echo   1. 运行单元测试 (快速)
echo   2. 运行集成测试 (需要设备)
echo   3. 运行所有测试
echo   4. 启动测试应用 (交互式)
echo.

set /p choice="请输入选项 (1-4): "

if "%choice%"=="1" goto unit_test
if "%choice%"=="2" goto integration_test
if "%choice%"=="3" goto all_test
if "%choice%"=="4" goto interactive_test
echo 无效选项
pause
exit /b 1

:unit_test
echo.
echo 运行单元测试...
flutter test --reporter expanded
goto end

:integration_test
echo.
echo 运行集成测试...
flutter test integration_test/app_test.dart -d windows
goto end

:all_test
echo.
echo 运行所有测试...
flutter test --reporter expanded
flutter test integration_test/app_test.dart -d windows
goto end

:interactive_test
echo.
echo 启动测试应用...
flutter run -d windows
goto end

:end
echo.
echo ========================================
echo   测试完成
echo ========================================
pause
