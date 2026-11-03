# アップデートの配布物を作る（ランチャーの「アップデート」で配る）
#   使い方（ゲームのフォルダで）: powershell -ExecutionPolicy Bypass -File tools\make_update.ps1 [-AppDir Z:\GuminTaikoApp] [-Out update] [-Version 2026.11.02] [-Publish]
#   GitHub で配るとき: 既定の出力 update\ は、このリポジトリの中（raw.githubusercontent.com/<ユーザー>/<リポジトリ>/<ブランチ>/update で読める）。
#     -Publish をつけると、update\ をコミットして origin に push する（push は外に出る操作なので、つけたときだけ行う）。
#     中身が同じファイルは、Git が同じ物として保存するので、Data\x64 と重ねて置いても容量は増えない。1 ファイル 100MB まで
#   先に tools\package.ps1 で配置（署名・manifest.sig）を済ませておく。
#   できるもの: <Out>\update.idx（署名つきの目録）と <Out>\files\（配るファイル。曲・Backup・証明書は入らない）
#   <Out> の中身を、そのまま Web サーバー（GitHub Pages・レンタルサーバーなど）か共有フォルダに置く。
#   遊ぶ人のアプリには、その場所を update_url.txt（アプリのフォルダ。package.ps1 -UpdateUrl で入る）か
#   Backup\launcher.ini の update_url= に書く。ランチャーが起動すると、違うファイルだけを取ってきて入れ替える。
#   2 回目からは、変わったファイルだけが <Out>\files に足される（前の版の残りは消える）
param(
    [string]$AppDir = "Z:\GuminTaikoApp",
    [string]$Out = "update",
    [string]$Version = (Get-Date -Format "yyyy.MM.dd.HHmm"),
    [switch]$Publish
)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$sign = @("build-release\gumin_sign.exe", "build\gumin_sign.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $sign) { & ninja -C build gumin_sign.exe | Out-Null; $sign = "build\gumin_sign.exe" }
if (-not (Test-Path "keys\gumin_private.key")) { throw "秘密鍵 keys\gumin_private.key がありません（鍵のある PC で実行してください）" }
if (-not (Test-Path (Join-Path $AppDir "manifest.sig"))) { throw "$AppDir に manifest.sig がありません。先に tools\package.ps1 を実行してください" }

Write-Host "== アップデートの配布物を作ります: $Out （版 $Version）" -ForegroundColor Cyan
& $sign update $AppDir $Out --version $Version
if ($LASTEXITCODE -ne 0) { throw "作れませんでした" }
if ($Publish) {
    Write-Host "== GitHub に push します" -ForegroundColor Cyan
    & git add -- $Out
    & git commit -m "update $Version" -- $Out
    if ($LASTEXITCODE -ne 0) { Write-Host "  （コミットする変更がありません）" }
    & git push origin HEAD
    if ($LASTEXITCODE -ne 0) { throw "push に失敗しました（認証と、1 ファイル 100MB を超えるファイルがないかを確かめてください）" }
    Write-Host "  遊ぶ人のランチャーが、次に開いたときに更新を見つけます"
} else {
    Write-Host "  $Out の中身（update.idx と files フォルダ）を、更新元の場所に置いてください（GitHub なら -Publish）"
}