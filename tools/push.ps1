# 変更をコミットして GitHub に push する（コミットメッセージを入力できる）
#   使い方（ゲームのフォルダで）: powershell -ExecutionPolicy Bypass -File tools\push.ps1 [-Message "メッセージ"] [-NoPush]
#   ・-Message を付けないと、メッセージの入力を求める（空のままならやめる）
#   ・-NoPush を付けると、コミットだけして push はしない
#   ・上げてはいけないもの（秘密鍵・曲・Backup など）が入っていたら止める
param(
    [string]$Message = "",
    [switch]$NoPush,
    [string]$Remote = "origin"
)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

& git add -A
$bad = git diff --cached --name-only | Select-String -Pattern '^keys/|private\.key|^Backup/|^Songs/|\.ogg$|\.mp3$|\.zip$'
if ($bad) {
    & git reset -q
    throw "上げてはいけないものが入っています: $($bad[0])"
}
$changes = @(git diff --cached --name-status)
if ($changes.Count -eq 0) {
    Write-Host "コミットする変更はありません" -ForegroundColor Yellow
} else {
    Write-Host "== 変更 $($changes.Count) 個" -ForegroundColor Cyan
    $changes | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" }
    if ($changes.Count -gt 20) { Write-Host "  ...（ほか $($changes.Count - 20) 個）" }
    if (-not $Message) { $Message = Read-Host "コミットメッセージ" }
    if (-not $Message.Trim()) {
        & git reset -q
        throw "メッセージが空なのでやめました"
    }
    & git commit -m $Message
    if ($LASTEXITCODE -ne 0) { throw "コミットに失敗しました" }
}
if ($NoPush) { Write-Host "== コミットだけしました（push はしていません）"; return }
Write-Host "== $Remote に push します" -ForegroundColor Cyan
& git push $Remote HEAD
if ($LASTEXITCODE -ne 0) { throw "push に失敗しました（認証・通信・100MB を超えるファイルがないかを確かめてください）" }
Write-Host "== できました" -ForegroundColor Green