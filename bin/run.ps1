#!/usr/bin/env pwsh
[CmdletBinding()]
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ScriptArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Fail {
  param([string]$Message)
  Write-Error "❌ 错误: $Message"
  exit 1
}

function Info {
  param([string]$Message)
  Write-Host "▶ $Message"
}

function Resolve-OpenSSLPath {
  if ($env:ETDATA_OPENSSL -and (Test-Path -LiteralPath $env:ETDATA_OPENSSL)) {
    return $env:ETDATA_OPENSSL
  }

  $cmd = Get-Command openssl -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) {
    return $cmd.Source
  }

  $candidates = @(
    (Join-Path $env:ProgramFiles "Git\\mingw64\\bin\\openssl.exe"),
    (Join-Path $env:ProgramFiles "Git\\usr\\bin\\openssl.exe"),
    (Join-Path $env:LOCALAPPDATA "Programs\\Git\\mingw64\\bin\\openssl.exe"),
    (Join-Path $env:LOCALAPPDATA "Programs\\Git\\usr\\bin\\openssl.exe"),
    (Join-Path $env:USERPROFILE "scoop\\apps\\git\\current\\mingw64\\bin\\openssl.exe")
  )

  foreach ($candidate in $candidates) {
    if ($candidate -and (Test-Path -LiteralPath $candidate)) {
      return $candidate
    }
  }

  return $null
}

$repoOwner = if ($env:ETDATA_REPO_OWNER) { $env:ETDATA_REPO_OWNER } else { "jyogyou" }
$repoName = if ($env:ETDATA_REPO_NAME) { $env:ETDATA_REPO_NAME } else { "etdata-scripts" }
$repoRef = if ($env:ETDATA_REF) { $env:ETDATA_REF } else { "main" }
$rawBase = if ($env:ETDATA_RAW_BASE) { $env:ETDATA_RAW_BASE.TrimEnd("/") } else { "https://raw.githubusercontent.com/$repoOwner/$repoName/$repoRef" }
$scriptBase = "$rawBase/scripts"

$token = $env:ETDATA_TOKEN
$scriptName = $env:ETDATA_SCRIPT
$localScriptsDir = $env:ETDATA_LOCAL_SCRIPTS_DIR

if ([string]::IsNullOrWhiteSpace($token)) {
  Fail "未提供 ETDATA_TOKEN。"
}

if ([string]::IsNullOrWhiteSpace($scriptName)) {
  Fail "未提供 ETDATA_SCRIPT (脚本名)。"
}

if ($scriptName -notmatch '^[A-Za-z0-9._-]+\.(sh|ps1)$') {
  Fail "非法脚本名：$scriptName (仅支持 .sh / .ps1)"
}

$openSSL = Resolve-OpenSSLPath
if (-not $openSSL) {
  Fail "未找到 openssl。请先安装 OpenSSL，或设置 ETDATA_OPENSSL=openssl.exe完整路径。"
}

$ext = [IO.Path]::GetExtension($scriptName).ToLowerInvariant()
$tmpDir = [IO.Path]::GetTempPath()
$id = [Guid]::NewGuid().ToString("N")
$tmpEnc = Join-Path $tmpDir ("etdata-enc-$id.enc")
$tmpScript = Join-Path $tmpDir ("etdata-script-$id$ext")

try {
  if (-not [string]::IsNullOrWhiteSpace($localScriptsDir)) {
    $localEnc = Join-Path $localScriptsDir "$scriptName.enc"
    if (-not (Test-Path -LiteralPath $localEnc)) {
      Fail "本地调试模式下找不到文件：$localEnc"
    }
    Info "使用本地密文：$localEnc"
    Copy-Item -LiteralPath $localEnc -Destination $tmpEnc -Force
  }
  else {
    $encUrl = "$scriptBase/$scriptName.enc"
    Info "正在下载脚本：$scriptName ..."
    try {
      Invoke-WebRequest -Uri $encUrl -OutFile $tmpEnc -UseBasicParsing
    }
    catch {
      Fail "下载失败：$encUrl"
    }
  }

  & $openSSL enc -d -aes-256-cbc -md sha256 -salt -in $tmpEnc -out $tmpScript -k $token *> $null
  if ($LASTEXITCODE -ne 0) {
    Fail "解密失败。可能是 Token 错误或脚本已损坏。"
  }

  if (-not (Test-Path -LiteralPath $tmpScript)) {
    Fail "解密输出文件不存在。"
  }
  if ((Get-Item -LiteralPath $tmpScript).Length -le 0) {
    Fail "解密输出为空，可能 Token 不匹配。"
  }

  Info "脚本验证通过，正在执行：$scriptName"

  switch ($ext) {
    ".ps1" {
      $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
      if ($pwsh) {
        & $pwsh.Source -NoProfile -ExecutionPolicy Bypass -File $tmpScript @ScriptArgs
        exit $LASTEXITCODE
      }
      & powershell -NoProfile -ExecutionPolicy Bypass -File $tmpScript @ScriptArgs
      exit $LASTEXITCODE
    }
    ".sh" {
      $bash = Get-Command bash -ErrorAction SilentlyContinue
      if (-not $bash) {
        Fail "当前环境未安装 bash，无法执行 .sh 脚本。请改用 .ps1 脚本或安装 Git Bash/WSL。"
      }
      & $bash.Source $tmpScript @ScriptArgs
      exit $LASTEXITCODE
    }
    default {
      Fail "不支持的脚本后缀：$ext"
    }
  }
}
finally {
  Remove-Item -LiteralPath $tmpEnc -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $tmpScript -Force -ErrorAction SilentlyContinue
}
