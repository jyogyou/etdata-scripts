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
SCRIPT_BASE_URL="${BASE_RAW_URL}/scripts"

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

# 检查 /tmp 是否可写
if [[ ! -w /tmp ]]; then
    echo "错误：/tmp 目录不可写，无法创建临时文件。"
    exit 1
fi

TMP_ENC="$(mktemp /tmp/etdata-enc-XXXXXX.enc)"
TMP_SCRIPT="$(mktemp /tmp/etdata-script-XXXXXX.sh)"

# 捕获清理信号
if [[ "${DEBUG:-}" != "true" ]]; then
  trap 'rm -f "$TMP_ENC" "$TMP_SCRIPT"' EXIT
else
  echo "Debug 模式开启：临时文件将保留在 $TMP_ENC 和 $TMP_SCRIPT"
  echo "Debug: 检查 /tmp 空间:"
  df -h /tmp 2>/dev/null || echo "无法检查磁盘空间"
fi

echo "正在下载脚本：$ETDATA_SCRIPT ..."
DOWNLOAD_SUCCESS=false

# 优先尝试 curl
if command -v curl &> /dev/null; then
    # -q 禁用 .curlrc (必须是第一个参数)
    # 临时文件可能存在权限问题，尝试先删除由 mktemp 创建的空文件（curl 会重新创建或覆盖）
    # 但为了安全，保留文件让 curl 覆盖
    if curl -q -fsSL "$ENC_FILE_URL" -o "$TMP_ENC"; then
        DOWNLOAD_SUCCESS=true
    else
        CURL_EXIT_CODE=$?
        echo "Debug: curl 下载失败，错误码: $CURL_EXIT_CODE"
    fi
fi

# 如果 curl 失败，尝试 wget
if [[ "$DOWNLOAD_SUCCESS" == "false" ]]; then
    if command -v wget &> /dev/null; then
        echo "尝试使用 wget 下载..."
        if wget -q -O "$TMP_ENC" "$ENC_FILE_URL"; then
            DOWNLOAD_SUCCESS=true
        else
            echo "Debug: wget 下载失败，错误码: $?"
        fi
    else
        echo "Debug: 未找到 wget 命令"
    fi
fi

if [[ "$DOWNLOAD_SUCCESS" == "false" ]]; then
  echo "错误：无法下载脚本文件 (HTTP 404 或 网络/写入错误)"
  echo "尝试的 URL: $ENC_FILE_URL"
  echo "请检查："
  echo "1. 脚本名是否正确"
  echo "2. 磁盘空间是否充足 (df -h /tmp)"
  echo "3. 目录权限是否可写"
  exit 1
fi

# ===== 3. 解密脚本 =====
# 检查 openssl 是否存在
if ! command -v openssl &> /dev/null; then
  echo "错误: 未找到 openssl 命令"
  exit 1
fi
# 打印版本以便调试
echo "Debug: OpenSSL version: $(openssl version)"

# 尝试使用 Token 解密
set +e # 暂时允许失败以便捕获错误
# 为了兼容 CentOS 7 (OpenSSL 1.0.2)，移除 -pbkdf2 和 -iter，并显式指定 -md sha256
openssl enc -d -aes-256-cbc -md sha256 -salt -in "$TMP_ENC" -out "$TMP_SCRIPT" -k "$ETDATA_TOKEN"
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
