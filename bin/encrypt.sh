#!/usr/bin/env bash
set -e

############################################
# 易通数�?· 脚本加密工具
# 用途：�?scripts/ 下的 .sh 文件加密�?.enc
# 使用�?/bin/encrypt.sh <脚本文件�? <加密密码/Token>
############################################

SCRIPT_NAME="$1"
TOKEN="$2"
SCRIPTS_DIR="scripts"

if [[ -z "$SCRIPT_NAME" || -z "$TOKEN" ]]; then
  echo "用法: $0 <脚本文件�?sh> <密码Token>"
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
# 注意：为了最大化兼容性（如兼容旧�?CentOS 7），这里不使�?-pbkdf2�?
# 并且显式指定 -md sha256 以防止不同版本的默认摘要算法(md5/sha256)不一致�?
openssl enc -aes-256-cbc -md sha256 -salt -in "$INPUT_FILE" -out "$OUTPUT_FILE" -k "$TOKEN"

echo "�?加密成功�?
echo "源文�? $INPUT_FILE"
echo "加密�? $OUTPUT_FILE"
echo ""
echo "现在你可以提�?$OUTPUT_FILE 到仓库了�?
echo "请记得更�?auth/tokens.txt 中的 Token �? $TOKEN"