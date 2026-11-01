#!/usr/bin/env pwsh
#requires -Version 5.1
<#
    gh 登录向导
    ===========
    由 /wizard 生成的一次性脚本，跑完可以删。

    它做三件事：
      1. 找到 gh 可执行文件，并报告当前登录状态
      2. 在浏览器里完成 GitHub 设备授权（gh auth login --web）
      3. 用 gh auth status / gh api user 验证登录结果

    为什么是 PowerShell 而不是 bash：
      这台机器没有可用的 bash——WSL 没装任何发行版，Git Bash 也不在。
      脚本沿用 wizard 模板的分阶段结构：清屏、阶段提示、停顿确认、结尾汇总。

    用法（本机只有 Windows PowerShell 5.1，没有 pwsh 7）：
        powershell -ExecutionPolicy Bypass -File .\scripts\gh-login-wizard.ps1
#>

Set-StrictMode -Version 3.0
# gh 往 stderr 写字，Stop 在 PowerShell 5.1 里会被当成终止错误；
# 这里统一 Continue，由每个调用的退出码决定流程。
$ErrorActionPreference = 'Continue'

$script:TotalStages   = 3
$script:StageIndex    = 0
$script:Gh            = $null
$script:AlreadyAuthed = $false

# ── 向导库（与 template.sh 同构，别按单个脚本改动） ──────────────────────

function Clear-Screen {
    if (-not [Console]::IsOutputRedirected) {
        try { Clear-Host } catch { }
    }
}

function Write-Banner {
    param([string]$Title)
    Clear-Screen
    Write-Host ''
    Write-Host ('  ' + $Title) -ForegroundColor Cyan
    Write-Host ('  ' + $script:TotalStages + ' 个阶段') -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  浏览器由你来操作；这个向导告诉你点什么、并把结果核对一遍。' -ForegroundColor DarkGray
    Write-Host '  Ctrl-C 可随时退出，重跑时会先读当前登录状态，不会重复授权。' -ForegroundColor DarkGray
    Pause-Wizard '准备好就开始'
}

function Show-Stage {
    param([string]$Name)
    Clear-Screen
    $script:StageIndex++
    Write-Host ''
    Write-Host ('▸ 阶段 ' + $script:StageIndex + '/' + $script:TotalStages + ' · ' + $Name) -ForegroundColor Cyan
}

function Say {
    param([string]$Text)
    if ($Text) { Write-Host ('  ' + $Text) }
}

function Step {
    param([string]$Text)
    Write-Host ('  • ' + $Text) -ForegroundColor Blue
}

function Note {
    param([string]$Text)
    Write-Host ('  ' + $Text) -ForegroundColor DarkGray
}

function Warn-Wizard {
    param([string]$Text)
    Write-Host ('  ⚠ ' + $Text) -ForegroundColor Yellow
}

function Pause-Wizard {
    param([string]$Message = '按 Enter 继续')
    Write-Host ('  ' + $Message + ' ') -ForegroundColor DarkGray -NoNewline
    [void][Console]::ReadLine()
}

function Finish-Wizard {
    Clear-Screen
    Write-Host ''
    Write-Host '  ✓ 完成' -ForegroundColor Green
    Write-Host ''
}

# 依次尝试：DSH_GH_PATH → 本机安装位置 → PATH
function Resolve-Gh {
    $candidates = @()
    if ($env:DSH_GH_PATH) { $candidates += $env:DSH_GH_PATH }
    if ($env:LOCALAPPDATA) { $candidates += (Join-Path $env:LOCALAPPDATA 'Programs\gh\gh.exe') }
    $candidates += 'C:\Program Files\GitHub CLI\gh.exe'

    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) {
            return (Resolve-Path -LiteralPath $c).Path
        }
    }
    $cmd = Get-Command gh -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

# 抓取输出的调用（不用于交互式命令）
function Invoke-Gh {
    param([string[]]$Arguments)
    $ErrorActionPreference = 'Continue'
    # 5.1 里 2>&1 会混入 ErrorRecord，ToString() 只留消息本身，输出才干净。
    $lines = & $script:Gh @Arguments 2>&1 | ForEach-Object { $_.ToString() }
    $code = $LASTEXITCODE
    $text = (($lines -join [Environment]::NewLine)).Trim()
    return [pscustomobject]@{ Output = $text; ExitCode = $code }
}

function Split-Lines {
    param([string]$Text)
    return ($Text -split '\r?\n' | Where-Object { $_ })
}

# ── 阶段 ─────────────────────────────────────────────────────────────────

Write-Banner 'gh 登录向导'

# ── 阶段 1：定位 gh，读当前状态 ──────────────────────────────────────────
Show-Stage '定位 gh 并读取当前登录状态'

$gh = Resolve-Gh
if (-not $gh) {
    Warn-Wizard '找不到 gh。先装好 gh CLI，再重跑本向导。'
    Note '安装说明：https://cli.github.com/'
    exit 1
}
$script:Gh = $gh
Say ('gh 可执行文件：' + $gh)

$version = Invoke-Gh @('--version')
if ($version.ExitCode -eq 0 -and $version.Output) {
    Say ('版本：' + (@(Split-Lines $version.Output)[0]))
} else {
    Warn-Wizard 'gh --version 执行失败，后面的步骤可能也不可靠。'
}

$status = Invoke-Gh @('auth', 'status')
if ($status.ExitCode -eq 0) {
    $script:AlreadyAuthed = $true
    Say '当前已登录：'
    Split-Lines $status.Output | ForEach-Object { Note $_ }
} else {
    $script:AlreadyAuthed = $false
    Say '当前未登录。'
    Split-Lines $status.Output | ForEach-Object { Note $_ }
}

# ── 阶段 2：浏览器授权 ───────────────────────────────────────────────────
Show-Stage '在浏览器完成 GitHub 授权'

if ($script:AlreadyAuthed) {
    Say '已有登录凭据，跳过授权这一步。'
    Note '想换账号就先执行 gh auth logout --hostname github.com，再重跑本向导。'
    Pause-Wizard '按 Enter 继续验证'
} else {
    Say '接下来 gh 会：'
    Step '生成一次性验证码（形如 ABCD-1234），显示在本窗口'
    Step '自动打开 https://github.com/login/device'
    Step '你在网页里输入验证码，点 Authorize'
    Note '浏览器没弹出来就手动打开上面的地址。'
    Pause-Wizard '按 Enter 开始登录'
    Write-Host ''
    & $script:Gh auth login --hostname github.com --git-protocol https --web
    if ($LASTEXITCODE -ne 0) {
        Write-Host ''
        Warn-Wizard ('gh auth login 退出码 ' + $LASTEXITCODE + '，授权可能没完成。')
        Pause-Wizard '按 Enter 继续，看看现在是什么状态'
    }
}

# ── 阶段 3：验证 ─────────────────────────────────────────────────────────
Show-Stage '验证登录结果'

$status = Invoke-Gh @('auth', 'status')
if ($status.ExitCode -ne 0) {
    Warn-Wizard '仍然是未登录状态。'
    Split-Lines $status.Output | ForEach-Object { Note $_ }
    Note '重新运行本脚本可以再走一次授权。'
    exit 1
}

Split-Lines $status.Output | ForEach-Object { Note $_ }

$who = Invoke-Gh @('api', 'user', '--jq', '.login')
if ($who.ExitCode -eq 0 -and $who.Output) {
    Say ('GitHub 账号：' + $who.Output)
} else {
    Warn-Wizard '读不到账号名，但凭据已存在；可以手动跑 gh api user 看看。'
}

if ($status.Output -match 'Token scopes:\s*(.+)') {
    Say ('Token scopes：' + $Matches[1].Trim())
}

Finish-Wizard
Say 'gh 已登录，命令行和插件都能用了。'
Note '验证：gh auth status'
Note '换账号：gh auth logout --hostname github.com'
