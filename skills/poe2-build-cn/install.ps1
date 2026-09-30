# 把 poe2-build-cn 技能安装到本机的 Claude Code。
# 用法：
#   powershell -ExecutionPolicy Bypass -File .\install.ps1            # 装到个人目录，全局可用
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 -Project   # 只装到当前仓库，随仓库走
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 -Uninstall # 卸载个人目录里的这一份

[CmdletBinding()]
param(
    [switch]$Project,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$SkillName = 'poe2-build-cn'
$Here      = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent (Split-Path -Parent $Here)
$Source    = Join-Path $Here 'SKILL.md'

if ($Project) {
    $Base = Join-Path $RepoRoot '.claude\skills'
} elseif ($env:CLAUDE_CONFIG_DIR) {
    $Base = Join-Path $env:CLAUDE_CONFIG_DIR 'skills'
} else {
    $Base = Join-Path $env:USERPROFILE '.claude\skills'
}
$Target = Join-Path $Base $SkillName

if ($Uninstall) {
    if (Test-Path $Target) {
        Remove-Item -Recurse -Force $Target
        Write-Host "[已卸载] $Target"
    } else {
        Write-Host "[跳过] 未找到 $Target"
    }
    exit 0
}

if (-not (Test-Path $Source)) {
    throw "找不到源文件：$Source"
}

New-Item -ItemType Directory -Force -Path $Target | Out-Null
Copy-Item -Force -LiteralPath $Source -Destination (Join-Path $Target 'SKILL.md')

$Installed = Join-Path $Target 'SKILL.md'
$Bytes = (Get-Item -LiteralPath $Installed).Length
$Lines = (Get-Content -LiteralPath $Installed -Encoding UTF8).Count

Write-Host ""
Write-Host "[已安装] $Installed"
Write-Host "         $Bytes 字节 / $Lines 行"
Write-Host ""
Write-Host "校验前三行："
Get-Content -LiteralPath $Installed -Encoding UTF8 -TotalCount 3 | ForEach-Object { Write-Host "  $_" }
Write-Host ""
Write-Host "重启 Claude Code 后用 /doctor 或 /skills 确认 $SkillName 已出现。"
