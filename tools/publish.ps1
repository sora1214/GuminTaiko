# GitHub に上げる（初回）。コミットを古い順に 1 つずつ push する（一度に 2GB 以上を送ると失敗しやすいため）
#   使い方（ゲームのフォルダで）: powershell -ExecutionPolicy Bypass -File tools\publish.ps1 [-Remote origin] [-Branch main]
#   ・認証の窓が出たら、GitHub にサインインする（Git Credential Manager）
#   ・途中で止まったら、もう一度実行すると続きから送る
#   ・秘密鍵（keys\）・曲・Backup は .gitignore で除いてあります（git ls-files に入っていないことを確かめてから上げる）
param(
    [string]$Remote = "origin",
    [string]$Branch = "main"
)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$bad = git ls-files | Select-String -Pattern '^keys/|private\.key|^Backup/|^Songs/|\.ogg$|\.mp3$'
if ($bad) { throw "上げてはいけないものが入っています: $($bad[0])" }
$commits = @(git rev-list --reverse $Branch)
Write-Host "== $($commits.Count) 個のコミットを $Remote/$Branch に送ります" -ForegroundColor Cyan
$i = 0
foreach ($sha in $commits) {
    ++$i
    $title = git log -1 --format=%s $sha
    Write-Host "  [$i/$($commits.Count)] $title"
    & git push $Remote "${sha}:refs/heads/$Branch"
    if ($LASTEXITCODE -ne 0) { throw "push に失敗しました（認証・通信・100MB を超えるファイルがないかを確かめて、もう一度実行してください）" }
}
Write-Host "== できました" -ForegroundColor Green