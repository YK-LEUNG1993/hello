# OpenAI Codex App Windows 网络排查脚本
# 本脚本只读取系统状态，不删除、不移动、不修改任何用户文件。

# 使用严格模式帮助发现脚本中的变量拼写或调用错误。
Set-StrictMode -Version Latest

# 设置错误处理策略，让单项检查失败时继续执行后续检查。
$ErrorActionPreference = 'Continue'

# 输出带分隔线的小节标题，方便用户阅读检查结果。
function Write-Section {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    Write-Host ""
    Write-Host "==== $Title ====" -ForegroundColor Cyan
}

# 安全读取注册表值，避免某个键不存在时中断整个脚本。
function Get-RegistryValueSafe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    try {
        $item = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        return $item.$Name
    }
    catch {
        return $null
    }
}

# 检查 WinHTTP 代理配置，Codex 或底层网络库可能会受到该配置影响。
Write-Section "WinHTTP 代理"
try {
    netsh winhttp show proxy
}
catch {
    Write-Warning "无法读取 WinHTTP 代理：$($_.Exception.Message)"
}

# 检查当前用户的系统代理注册表设置，这是 Windows 设置和多数代理软件常用的位置。
Write-Section "系统代理注册表设置"
$internetSettingsPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$proxyEnable = Get-RegistryValueSafe -Path $internetSettingsPath -Name 'ProxyEnable'
$proxyServer = Get-RegistryValueSafe -Path $internetSettingsPath -Name 'ProxyServer'
$autoConfigUrl = Get-RegistryValueSafe -Path $internetSettingsPath -Name 'AutoConfigURL'
$autoDetect = Get-RegistryValueSafe -Path $internetSettingsPath -Name 'AutoDetect'
Write-Host "ProxyEnable : $proxyEnable"
Write-Host "ProxyServer : $proxyServer"
Write-Host "AutoConfigURL: $autoConfigUrl"
Write-Host "AutoDetect   : $autoDetect"

# 检查 OpenAI 相关域名的 DNS 解析结果，确认域名能否被正常解析为 IP 地址。
Write-Section "DNS 解析检查"
$domains = @('chatgpt.com', 'openai.com', 'oaistatic.com', 'oaiusercontent.com')
foreach ($domain in $domains) {
    Write-Host ""
    Write-Host "域名：$domain" -ForegroundColor Yellow
    try {
        Resolve-DnsName -Name $domain -ErrorAction Stop | Select-Object Name, Type, IPAddress, NameHost | Format-Table -AutoSize
    }
    catch {
        Write-Warning "DNS 解析失败：$domain - $($_.Exception.Message)"
    }
}

# 发送 HTTPS 请求到 ChatGPT 网站，确认 TLS、代理和网络路径是否可用。
Write-Section "HTTPS 请求检查"
try {
    $response = Invoke-WebRequest -Uri 'https://chatgpt.com' -Method Head -TimeoutSec 20 -UseBasicParsing -ErrorAction Stop
    Write-Host "HTTPS 请求成功：状态码 $($response.StatusCode) $($response.StatusDescription)" -ForegroundColor Green
}
catch {
    Write-Warning "HTTPS 请求失败：https://chatgpt.com - $($_.Exception.Message)"
}

# 检查常见本地代理端口是否在监听，帮助判断 Clash、V2Ray、Sing-box 等代理是否已启动。
Write-Section "本地代理端口监听检查"
$proxyPorts = @(7890, 7897, 1080, 10808)
foreach ($port in $proxyPorts) {
    try {
        $listeners = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction Stop
        if ($listeners) {
            Write-Host "端口 $port：已监听" -ForegroundColor Green
            $listeners | Select-Object LocalAddress, LocalPort, OwningProcess | Format-Table -AutoSize
        }
    }
    catch {
        Write-Host "端口 $port：未发现监听" -ForegroundColor DarkYellow
    }
}

# 检查 APPDATA 和 LOCALAPPDATA 下可能与 Codex、OpenAI、ChatGPT 相关的缓存或配置目录。
Write-Section "缓存目录检查"
$basePaths = @($env:APPDATA, $env:LOCALAPPDATA) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
$namePatterns = @('*Codex*', '*OpenAI*', '*ChatGPT*')
foreach ($basePath in $basePaths) {
    Write-Host ""
    Write-Host "基础目录：$basePath" -ForegroundColor Yellow
    foreach ($pattern in $namePatterns) {
        Get-ChildItem -Path $basePath -Directory -Filter $pattern -ErrorAction SilentlyContinue |
            Select-Object FullName, LastWriteTime |
            Format-Table -AutoSize
    }
}

# 输出完成提示，提醒用户可根据结果决定是否运行重置脚本。
Write-Section "完成"
Write-Host "检查完成。如 Codex App 仍反复重连，可在确认无正在编辑内容后运行 .\reset-codex-client.ps1。"
