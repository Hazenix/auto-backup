<# 
  start_clash_proxy.ps1

  作用：
    - 可选：启动 Clash 核心/Clash for Windows
    - 通过 Clash 外部控制 API 切换模式（如：Rule / Global / Direct）

  使用前请先确认：
    1. Clash 配置中开启了 external-controller，例如：
         external-controller: 127.0.0.1:9090
    2. 如果配置了 secret，请将下方的 $ClashSecret 填上
#>

param ()

### ==========================
### 可配置参数（按需修改）
### ==========================

# Clash 外部控制 API 地址（根据你的 config.yml 调整）
$ClashApiBaseUrl = "http://127.0.0.1:9090"

# 如果 config.yml 里配置了 secret，这里填入；否则保持空字符串
$ClashSecret = ""

# 希望切换到的模式：Rule / Global / Direct
$TargetMode = "Rule"

# 如果你需要在脚本中顺便启动 Clash 核心，在这里配置路径（可选）
# 例如：C:\Tools\Clash\clash-windows-amd64.exe
$ClashCoreExe = ""

# Clash 核心工作目录（config.yaml 所在目录，可选）
$ClashCoreWorkDir = ""

# 启动 Clash 核心后，等待的秒数（仅在配置了 $ClashCoreExe 时生效）
$ClashStartWaitSeconds = 3


### ==========================
### 启动 Clash 核心（可选）
### ==========================

if ($ClashCoreExe -and (Test-Path $ClashCoreExe)) {
    Write-Host "正在启动 Clash 核心：$ClashCoreExe"
    $startInfo = @{
        FilePath     = $ClashCoreExe
        WorkingDirectory = (if ($ClashCoreWorkDir) { $ClashCoreWorkDir } else { Split-Path $ClashCoreExe })
    }
    Start-Process @startInfo | Out-Null

    if ($ClashStartWaitSeconds -gt 0) {
        Write-Host "等待 Clash 启动 $ClashStartWaitSeconds 秒..."
        Start-Sleep -Seconds $ClashStartWaitSeconds
    }
}
else {
    if ($ClashCoreExe) {
        Write-Host "提示：配置了 ClashCoreExe 但未找到文件：$ClashCoreExe"
    }
    else {
        Write-Host "未配置 ClashCoreExe，假定 Clash（或 Clash for Windows）已在运行。"
    }
}


### ==========================
### 通过 API 切换模式
### ==========================

if (-not $ClashApiBaseUrl.EndsWith("/")) {
    $ClashApiBaseUrl = $ClashApiBaseUrl.TrimEnd("/")
}

$configsUrl = "$ClashApiBaseUrl/configs"

# 构建请求头
$headers = @{}
if ($ClashSecret) {
    $headers["Authorization"] = "Bearer $ClashSecret"
}

# 构建 Payload（切换模式）
$payload = @{ mode = $TargetMode } | ConvertTo-Json

Write-Host "准备切换 Clash 模式为：$TargetMode"

try {
    # 部分 Clash 版本使用 PATCH /configs
    Invoke-RestMethod -Uri $configsUrl -Method Patch -Body $payload -ContentType "application/json" -Headers $headers
    Write-Host "Clash 模式已成功切换为：$TargetMode (PATCH)"
}
catch {
    Write-Host "PATCH /configs 失败，尝试使用 PUT /configs ..."
    try {
        Invoke-RestMethod -Uri $configsUrl -Method Put -Body $payload -ContentType "application/json" -Headers $headers
        Write-Host "Clash 模式已成功切换为：$TargetMode (PUT)"
    }
    catch {
        Write-Host "切换 Clash 模式失败：$_"
        exit 1
    }
}

exit 0


