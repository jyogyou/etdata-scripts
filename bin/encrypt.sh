#!/usr/bin/env bash
set -e

############################################
# 易通数据 · 脚本加密工具
# 用途：将 scripts/ 下的 .sh 文件加密为 .enc
# 使用：./bin/encrypt.sh <脚本文件名> <加密密码/Token>
############################################

SCRIPT_NAME="$1"
TOKEN="$2"
SCRIPTS_DIR="scripts"

if [[ -z "$SCRIPT_NAME" || -z "$TOKEN" ]]; then
  echo "用法: $0 <脚本文件名.sh> <密码Token>"
  echo "示例: $0 ssh-motd-v5.sh MySecureToken2025"
  exit 1
fi

INPUT_FILE="${SCRIPTS_DIR}/${SCRIPT_NAME}"
OUTPUT_FILE="${SCRIPTS_DIR}/${SCRIPT_NAME}.enc"

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "错误：找不到文件 $INPUT_FILE"
  exit 1
fi

# 使用 OpenSSL AES-256-CBC 加密
# 注意：为了最大化兼容性（如兼容旧版 CentOS 7），这里不强制指定 pbkdf2，
# 但在较新系统上可能会有警告，忽略即可。
openssl enc -aes-256-cbc -salt -in "$INPUT_FILE" -out "$OUTPUT_FILE" -k "$TOKEN"

echo "✅ 加密成功！"
echo "源文件: $INPUT_FILE"
echo "加密后: $OUTPUT_FILE"
echo ""
echo "现在你可以提交 $OUTPUT_FILE 到仓库了。"
echo "请记得更新 auth/tokens.txt 中的 Token 为: $TOKEN"