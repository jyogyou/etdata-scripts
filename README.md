# etdata-scripts | 易通数据 · 私有脚本库 (加密版)

基于 **方案B：两段式加密包** 架构设计的运维脚本管理系统。

*   **安全增强**: 仓库中只存储加密后的 `.enc` 文件，即使文件被公开下载，无 Token 也无法查看源码。
*   **统一入口**: 客户端通过 `run.sh` 自动完成下载、解密、执行。

## 目录结构

```text
etdata-scripts/
├── bin/
│   ├── run.sh          # 客户端入口：负责下载 .enc -> 解密 -> 执行
│   └── encrypt.sh      # 管理员工具：负责将 .sh -> 加密为 .enc
├── scripts/
│   ├── ssh-motd-v5.sh      # (本地开发用源码，不一定要上传)
│   └── ssh-motd-v5.sh.enc  # (实际上传的加密文件)
├── auth/
│   └── tokens.txt      # 有效 Token 列表 (Token 即解密密码)
└── README.md
```

## 客户端使用 (统一入口)

客户只需一条命令。`ETDATA_TOKEN` 既是鉴权凭证，也是解密密码。

```bash
# 格式
curl -fsSL https://raw.githubusercontent.com/<你的GitHub用户名>/etdata-scripts/main/bin/run.sh \
  | ETDATA_TOKEN="<你的Token>" ETDATA_SCRIPT="<脚本文件名>" bash

# 示例
curl -fsSL https://raw.githubusercontent.com/username/etdata-scripts/main/bin/run.sh \
  | ETDATA_TOKEN="MySecret2025" ETDATA_SCRIPT="ssh-motd-v5.sh" bash
```

## 管理员指南

### 1. 发布新脚本 (加密流程)

在本地开发完成后，使用 `bin/encrypt.sh` 生成加密包。

**步骤：**

1.  编写/更新脚本，例如 `scripts/my-tool.sh`。
2.  运行加密工具 (假设你在 Git Bash 或 Linux 下)：
    ```bash
    # 用法: ./bin/encrypt.sh <文件名> <Token密码>
    ./bin/encrypt.sh my-tool.sh MySecret2025
    ```
3.  这将生成 `scripts/my-tool.sh.enc`。
4.  **只提交** `.enc` 文件到 GitHub (源码 `.sh` 可以根据需要选择是否提交，建议 .gitignore 忽略以保密)。
    ```bash
    git add scripts/*.enc
    git commit -m "Add encrypted script"
    git push
    ```

### 2. 管理 Token

*   编辑 `auth/tokens.txt`。
*   确保你用于加密的 Token 在这个列表中。
*   **注意**: 这是一个对称加密方案。所有客户如果都要能运行同一个 `.enc` 文件，他们必须持有相同的 Token (密码)。
*   如果你更换了 Token，必须用新 Token **重新加密** 所有 `.sh` 脚本并重新上传 `.enc` 文件。

### 3. 常见问题

*   **Q: 为什么提示解密失败？**
    *   A: 检查 `ETDATA_TOKEN` 是否与加密时使用的密码完全一致。
*   **Q: 如何支持多个不同 Token？**
    *   A: 本架构为“单密码”模式。如果要支持多 Token，需要通过后端 API (方案C) 或为不同客户上传不同文件 (如 `tool-clientA.sh.enc`)。
