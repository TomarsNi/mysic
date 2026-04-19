#!/bin/bash
# 端到端测试运行脚本
# 用于自动化执行 Flutter 集成测试

set -e

echo "=========================================="
echo "  Mysic 端到端测试"
echo "=========================================="
echo ""

# 进入 Flutter 项目目录
cd mysic_flutter

# 检查 Flutter 环境
echo ">>> 检查 Flutter 环境..."
flutter --version
echo ""

# 获取依赖
echo ">>> 获取依赖..."
flutter pub get
echo ""

# 分析代码
echo ">>> 分析代码..."
flutter analyze
echo ""

# 运行单元测试
echo ">>> 运行单元测试..."
flutter test --reporter=compact
echo ""

# 运行集成测试 (Windows)
echo ">>> 运行集成测试..."
flutter test integration_test/app_test.dart -d windows
echo ""

# 运行端到端测试
echo ">>> 运行端到端测试..."
flutter test integration_test/e2e_test.dart -d windows
echo ""

echo "=========================================="
echo "  测试完成!"
echo "=========================================="
