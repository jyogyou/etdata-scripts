#!/usr/bin/env bash
set -e

############################################
# 易通数据 · 脚本加密工具 (兼容版)
# 用途：将 .sh/.ps1 或任意脚本文件加密为 .enc
# 用法：./bin/encrypt.sh <脚本路径或文件名> <密码Token>
############################################

SCRIPT_INPUT="$1"
TOKEN="$2"

if [[ -z "$SCRIPT_INPUT" || -z "$TOKEN" ]]; then
  echo "用法: $0 <脚本路径或文件名> <密码Token>"
  echo "示例: $0 setup_windows_ai_cli.ps1 MySecureToken2025"
  echo "示例: $0 scripts/setup_linux_ai_cli.sh MySecureToken2025"
  exit 1
fi

if ! command -v openssl &> /dev/null; then
  echo "错误: 未找到 openssl 命令"
  exit 1
fi

# 兼容两种路径:
# 1) 直接给完整/相对路径
# 2) 只给文件名时，从 scripts/ 下找
if [[ -f "$SCRIPT_INPUT" ]]; then
  INPUT_FILE="$SCRIPT_INPUT"
elif [[ -f "scripts/$SCRIPT_INPUT" ]]; then
  INPUT_FILE="scripts/$SCRIPT_INPUT"
else
  echo "错误：找不到文件 $SCRIPT_INPUT"
  exit 1
fi

OUTPUT_FILE="${INPUT_FILE}.enc"

# 使用旧兼容加密参数，保持你现有调用方式不变
openssl enc -aes-256-cbc -md sha256 -salt -in "$INPUT_FILE" -out "$OUTPUT_FILE" -k "$TOKEN"

echo "✅ 加密成功！"
echo "源文件: $INPUT_FILE"
echo "加密后: $OUTPUT_FILE"
echo ""
echo "现在你可以把 $OUTPUT_FILE 放到 scripts/ 目录后上传 GitHub。"
