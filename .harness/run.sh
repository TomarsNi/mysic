#!/bin/bash

# Mysic 项目 - 自动执行脚本
# 使用 dangerously-skip-permissions 模式运行 Claude Code

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARNESS_DIR="$PROJECT_ROOT/.harness"
TASK_FILE="$HARNESS_DIR/task.json"
PROGRESS_FILE="$HARNESS_DIR/进度记录.md"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Mysic 项目 - 自动执行脚本${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检查 task.json 是否存在
if [ ! -f "$TASK_FILE" ]; then
    echo -e "${RED}错误: task.json 不存在${NC}"
    echo "请先运行需求收集和技术选型阶段"
    exit 1
fi

# 检查是否有待处理的任务
PENDING_TASKS=$(grep -c '"status": "pending"' "$TASK_FILE" || echo "0")
if [ "$PENDING_TASKS" -eq 0 ]; then
    echo -e "${GREEN}所有任务已完成！${NC}"
    exit 0
fi

echo -e "${YELLOW}待处理任务数: $PENDING_TASKS${NC}"
echo ""

# 确认执行
read -p "是否开始自动执行？(y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "已取消执行"
    exit 0
fi

echo ""
echo -e "${GREEN}开始自动执行...${NC}"
echo ""

# 循环执行任务
while true; do
    # 检查是否还有待处理任务
    PENDING=$(grep -c '"status": "pending"' "$TASK_FILE" || echo "0")
    if [ "$PENDING" -eq 0 ]; then
        echo -e "${GREEN}所有任务已完成！${NC}"
        break
    fi

    echo -e "${BLUE}----------------------------------------${NC}"
    echo -e "${BLUE}执行下一个任务...${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"

    # 调用 Claude Code 执行任务
    # 使用 --dangerously-skip-permissions 跳过权限确认
    claude --dangerously-skip-permissions \
        --allowedTools "Bash,Read,Write,Edit,Glob,Grep" \
        --system-prompt "你是一个自动化开发代理。请阅读 .harness/task.json，找到第一个 status 为 pending 的任务，执行该任务的所有步骤，完成后更新任务状态为 completed，并更新 .harness/进度记录.md。继续执行直到所有任务完成。" \
        "请继续执行 task.json 中的下一个待处理任务。完成后更新任务状态和进度记录。"

    # 检查执行结果
    if [ $? -ne 0 ]; then
        echo -e "${RED}任务执行失败，请检查日志${NC}"
        exit 1
    fi

    echo ""
    echo -e "${GREEN}任务执行完成${NC}"
    echo ""
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  项目构建完成！${NC}"
echo -e "${GREEN}========================================${NC}"
