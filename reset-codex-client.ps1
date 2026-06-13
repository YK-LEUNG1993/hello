# OpenAI Codex App Windows 客户端安全重置脚本
# 本脚本不会删除用户文件；它只会停止相关进程并把可能相关的缓存目录移动到带时间戳的备份目录。

# 使用严格模式帮助发现脚本中的变量拼写或调用错误。
Set-StrictMode -Version Latest

# 设置错误处理策略，让某一步失败时输出警告并继续执行后续安全步骤。
$ErrorActionPreference = 'Continue'

# 生成统一时间戳，用于所有备份目录名，方便用户查找同一次重置产生的备份。
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

# 输出带分隔线的小节标题，方便用户阅读执行进度。
function Write-Section {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    Write-Host ""
    Write-Host "==== $Title ====" -ForegroundColor Cyan
}

# 停止 Codex、OpenAI、ChatGPT 相关进程，避免缓存文件被占用导致备份失败。
Write-Section "停止相关进程"
$processNamePatterns = @('*Codex*', '*OpenAI*', '*ChatGPT*')
foreach ($pattern in $processNamePatterns) {
    $processes = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like $pattern }
    foreach ($process in $processes) {
        try {
            Write-Host "正在停止进程：$($process.ProcessName) (PID $($process.Id))"
            Stop-Process -Id $process.Id -Force -ErrorAction Stop
        }
        catch {
            Write-Warning "无法停止进程 $($process.ProcessName) (PID $($process.Id))：$($_.Exception.Message)"
        }
    }
}

# 定义可能包含 Codex、OpenAI、ChatGPT 缓存或配置的 Windows 用户应用数据目录。
Write-Section "备份缓存目录"
$basePaths = @($env:APPDATA, $env:LOCALAPPDATA) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
$namePatterns = @('*Codex*', '*OpenAI*', '*ChatGPT*')
$backedUpPaths = New-Object System.Collections.Generic.List[string]

# 查找匹配目录并移动到同级备份目录；使用 Move-Item 是为了保留内容而不是删除内容。
foreach ($basePath in $basePaths) {
    foreach ($pattern in $namePatterns) {
        $folders = Get-ChildItem -Path $basePath -Directory -Filter $pattern -ErrorAction SilentlyContinue
        foreach ($folder in $folders) {
            $backupPath = Join-Path -Path $folder.Parent.FullName -ChildPath "$($folder.Name).backup-$timestamp"
            try {
                Write-Host "备份目录：$($folder.FullName) -> $backupPath"
                Move-Item -Path $folder.FullName -Destination $backupPath -ErrorAction Stop
                $backedUpPaths.Add($backupPath) | Out-Null
            }
            catch {
                Write-Warning "备份失败：$($folder.FullName) - $($_.Exception.Message)"
            }
        }
    }
}

# 如果没有找到相关目录，明确告诉用户没有执行任何目录移动操作。
if ($backedUpPaths.Count -eq 0) {
    Write-Host "未发现需要备份的 Codex/OpenAI/ChatGPT 相关缓存目录。"
}
else {
    Write-Host "已创建以下备份目录：" -ForegroundColor Green
    $backedUpPaths | ForEach-Object { Write-Host "- $_" }
}

# 将当前 Windows 系统代理导入 WinHTTP，解决部分命令行或嵌入式网络组件不读取系统代理的问题。
Write-Section "导入系统代理到 WinHTTP"
try {
    netsh winhttp import proxy source=ie
}
catch {
    Write-Warning "导入 WinHTTP 代理失败：$($_.Exception.Message)"
}

# 打印重置后的下一步操作，让用户知道如何验证和恢复。
Write-Section "下一步"
Write-Host "1. 确认你的代理软件已启动，并且浏览器可以打开 https://chatgpt.com。"
Write-Host "2. 重新启动 OpenAI Codex App，并观察是否还会反复重连。"
Write-Host "3. 如果仍然失败，请运行 .\check-codex-network.ps1 并保存输出。"
Write-Host "4. 如果需要恢复缓存，请关闭 Codex App，然后把对应的 .backup-$timestamp 目录改回原目录名。"
Write-Host "5. 本脚本没有删除用户文件；所有可移动的相关目录都已用时间戳方式备份。"
