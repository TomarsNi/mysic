#!/bin/bash

# Mysic 项目 - 自动执行脚本
# 使用 dangerously-skip-permissions 模式运行 Claude Code

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
COMPLETED_TASKS=$(grep -c '"status": "completed"' "$TASK_FILE" || echo "0")
if [ "$PENDING_TASKS" -eq 0 ]; then
    echo -e "${GREEN}所有任务已完成！${NC}"
    exit 0
fi

echo -e "${CYAN}已完成: $COMPLETED_TASKS 个任务${NC}"
echo -e "${YELLOW}待处理: $PENDING_TASKS 个任务${NC}"
echo ""

echo -e "${GREEN}开始自动执行...${NC}"
echo ""

# 任务计数器
TASK_COUNT=0

# 循环执行任务
while true; do
    # 检查是否还有待处理任务
    PENDING=$(grep -c '"status": "pending"' "$TASK_FILE" || echo "0")
    COMPLETED=$(grep -c '"status": "completed"' "$TASK_FILE" || echo "0")

    if [ "$PENDING" -eq 0 ]; then
        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}  所有任务已完成！${NC}"
        echo -e "${GREEN}  共完成 $COMPLETED 个任务${NC}"
        echo -e "${GREEN}========================================${NC}"
        break
    fi

    # 增加任务计数
    TASK_COUNT=$((TASK_COUNT + 1))

    # 获取下一个待处理任务的 ID 和名称
    TASK_INFO=$(grep -B 5 '"status": "pending"' "$TASK_FILE" | grep -E '"id"|"name"' | head -2)
    TASK_ID=$(echo "$TASK_INFO" | grep '"id"' | sed 's/.*"id": "\([^"]*\)".*/\1/')
    TASK_NAME=$(echo "$TASK_INFO" | grep '"name"' | sed 's/.*"name": "\([^"]*\)".*/\1/')

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  任务 #$TASK_COUNT${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${CYAN}ID: $TASK_ID${NC}"
    echo -e "${GREEN}名称: $TASK_NAME${NC}"
    echo -e "${YELLOW}进度: $COMPLETED/$((COMPLETED + PENDING))${NC}"
    echo ""
    echo -e "${BLUE}>>> 开始执行...${NC}"
    echo ""

    # 调用 Claude Code 执行任务
    # 使用 --dangerously-skip-permissions 跳过权限确认
    claude --dangerously-skip-permissions \
        --allowedTools "Bash,Read,Write,Edit,Glob,Grep" \
        --system-prompt "你是一个自动化开发代理。请阅读 .harness/task.json，找到第一个 status 为 pending 的任务，执行该任务的所有步骤，完成后更新任务状态为 completed，并更新 .harness/进度记录.md，然后提交 git commit。继续执行直到所有任务完成。" \
        "请执行 task.json 中的任务: $TASK_ID - $TASK_NAME。完成后：1. 更新 task.json 中该任务状态为 completed；2. 更新 .harness/进度记录.md；3. 提交 git commit。" < /dev/null

    # 检查执行结果
    if [ $? -ne 0 ]; then
        echo ""
        echo -e "${RED}========================================${NC}"
        echo -e "${RED}  任务执行失败！${NC}"
        echo -e "${RED}  任务: $TASK_ID - $TASK_NAME${NC}"
        echo -e "${RED}========================================${NC}"
        exit 1
    fi

    echo ""
    echo -e "${GREEN}>>> 任务完成: $TASK_NAME${NC}"
    echo ""
done
