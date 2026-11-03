# リリース: 配置（署名）→ 変更をコミットして push → アップデートの配布物を作って GitHub に上げる
#   使い方（ゲームのフォルダで。ゲームとランチャーは閉じる）:
#     powershell -ExecutionPolicy Bypass -File tools\release.ps1 [-Message "コミットメッセージ"] [-Installer]
#   ・-Message を付けないと、コミットメッセージの入力を求める
#   ・-Installer を付けると、最後にウェブ版のインストーラーも作る（dist\ に出る）
param(
    [string]$Message = "",
    [switch]$Installer
)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

if (-not $Message) { $Message = Read-Host "コミットメッセージ" }
if (-not $Message.Trim()) { throw "メッセージが空なのでやめました" }

Write-Host "== 1/3 配置（署名）" -ForegroundColor Cyan
& powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\package.ps1"
if ($LASTEXITCODE -ne 0) { throw "package.ps1 に失敗しました" }

Write-Host "== 2/3 コミットして push" -ForegroundColor Cyan
& powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\push.ps1" -Message $Message
if ($LASTEXITCODE -ne 0) { throw "push.ps1 に失敗しました" }

Write-Host "== 3/3 アップデートの配布物を GitHub に上げる" -ForegroundColor Cyan
& powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\make_update.ps1" -Publish
if ($LASTEXITCODE -ne 0) { throw "make_update.ps1 に失敗しました" }

if ($Installer) {
    Write-Host "== インストーラー（ウェブ版）" -ForegroundColor Cyan
    & powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\make_installer.ps1" -Web
}
Write-Host "== リリースできました" -ForegroundColor Green