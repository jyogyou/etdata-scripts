#!/usr/bin/env bash
set -euo pipefail

############################################
# 易通数据 · 私有脚本库统一执行入口 (加密版)
# 文件：bin/run.sh
############################################

# ===== 基础配置 =====
REPO_OWNER="jyogyou"
REPO_NAME="etdata-scripts"
REPO_BRANCH="main"

BASE_RAW_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_BRANCH}"

# ===== 必须的环境变量 =====
: "${ETDATA_TOKEN:?未提供 ETDATA_TOKEN，已终止}"
: "${ETDATA_SCRIPT:?未提供 ETDATA_SCRIPT（脚本名），已终止}"

# ===== 基础校验：脚本名安全 =====
if [[ ! "$ETDATA_SCRIPT" =~ ^[a-zA-Z0-9._-]+\.sh$ ]]; then
  echo "非法脚本名：$ETDATA_SCRIPT"
  exit 1
fi

# ===== 1. 下载加密脚本 =====
ENC_FILE_URL="${SCRIPT_BASE_URL}/${ETDATA_SCRIPT}.enc"
TMP_ENC="$(mktemp /tmp/etdata-enc-XXXXXX.enc)"
TMP_SCRIPT="$(mktemp /tmp/etdata-script-XXXXXX.sh)"

# 捕获清理信号
trap 'rm -f "$TMP_ENC" "$TMP_SCRIPT"' EXIT

if ! curl -fsSL "$ENC_FILE_URL" -o "$TMP_ENC"; then
  echo "错误：无法下载脚本文件 (HTTP 404)"
  echo "请检查：1. 脚本名是否正确 2. 仓库中是否已存在 .enc 加密文件"
  exit 1
fi

# ===== 2. 解密脚本 =====
# 尝试使用 Token 解密
set +e # 暂时允许失败以便捕获错误
openssl enc -d -aes-256-cbc -salt -in "$TMP_ENC" -out "$TMP_SCRIPT" -k "$ETDATA_TOKEN" 2>/dev/null
DECRYPT_STATUS=$?
set -e

if [[ $DECRYPT_STATUS -ne 0 ]]; then
  echo "解密失败！可能原因："
  echo "1. Token 错误（无法解密该文件）"
  echo "2. 脚本文件已损坏"
  exit 1
fi

# 简单校验解密内容是否像个脚本
if ! head -n 1 "$TMP_SCRIPT" | grep -q "^#"; then
  echo "错误：解密后的文件格式异常，可能是 Token 不匹配。"
  exit 1
fi

chmod +x "$TMP_SCRIPT"

# ===== 4. 执行脚本 =====
echo ">> 易通数据脚本验证通过，正在执行：${ETDATA_SCRIPT}"
bash "$TMP_SCRIPT"

exit 0
