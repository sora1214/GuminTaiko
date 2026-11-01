# GuminTaiko のインストーラー（GuminTaiko-Setup.exe）を作る
#   使い方（ゲームのフォルダで）: powershell -ExecutionPolicy Bypass -File tools\make_installer.ps1 [-AppDir C:\GuminTaiko] [-Version 1.0] [-Out dist]
#   先に tools\package.ps1 で配置（署名・manifest.sig・ランチャーの作成）を済ませておく。
#   ・配布する中身: プログラム（exe）・Data\x64（本家の素材。曲の TJA と音源・曲の並びは除く）・third_party・manifest.sig
#   ・入れないもの: 曲（Songs・Data\x64\fumen・Data\x64\sound の ogg/mp3/wav）・Backup（プレイヤーデータ）・Data\cache・
#     license.cert（この PC 用。もらった人は、ランチャーで PC の ID を送って証明書をもらう）・秘密鍵（keys）
#   ・インストール先は C:\Users\名前\AppData\Local\Programs\GuminTaiko（書き込める場所）
param(
    [string]$AppDir = "C:\GuminTaiko",
    [string]$Version = (Get-Date -Format "yyyy.MM.dd"),
    [string]$Out = "dist"
)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

function Step($text) { Write-Host "== $text" -ForegroundColor Cyan }

foreach ($need in @("GuminTaiko.exe", "GuminLauncher.exe", "GuminDressUp.exe", "GuminDaniEditor.exe", "manifest.sig")) {
    if (-not (Test-Path (Join-Path $AppDir $need))) { throw "$AppDir に $need がありません。先に tools\package.ps1 を実行してください" }
}
if (Test-Path (Join-Path $AppDir "GuminLicense.exe")) { throw "$AppDir に GuminLicense.exe があります（配布に入れてはいけません）" }
$makensis = (Get-Command makensis -ErrorAction SilentlyContinue).Source
if (-not $makensis) { throw "makensis（NSIS）が見つかりません" }

# ---- 配布する中身を集める（Z: など広い場所に作る。2〜3GB）----
$stage = Join-Path $Root "build-installer\stage"
Step "配布する中身を集めます: $stage"
if (Test-Path $stage) {
    & attrib -R "$stage\*" /S /D | Out-Null
    Remove-Item $stage -Recurse -Force
}
New-Item -ItemType Directory -Force $stage | Out-Null
foreach ($f in @("GuminTaiko.exe", "GuminLauncher.exe", "GuminDressUp.exe", "GuminDaniEditor.exe", "manifest.sig")) {
    Copy-Item (Join-Path $AppDir $f) $stage
}
if (Test-Path (Join-Path $AppDir "update_url.txt")) { Copy-Item (Join-Path $AppDir "update_url.txt") $stage }   # アップデートの更新元
Get-ChildItem $AppDir -Filter *.dll -ErrorAction SilentlyContinue | ForEach-Object { Copy-Item $_.FullName $stage }
# Data\x64: 曲の TJA（fumen）と曲の並び以外・曲の音源以外
& robocopy (Join-Path $AppDir "Data\x64") (Join-Path $stage "Data\x64") /E /NFL /NDL /NJH /NJS /NP `
    /XD (Join-Path $AppDir "Data\x64\fumen") (Join-Path $AppDir "Data\x64\sound") | Out-Null
if ($LASTEXITCODE -ge 8) { throw "Data\x64 のコピーに失敗しました" }
# 音: 本家の音（nus3bank など）だけ。曲の音源（ogg・mp3・wav）は入れない
& robocopy (Join-Path $AppDir "Data\x64\sound") (Join-Path $stage "Data\x64\sound") /E /NFL /NDL /NJH /NJS /NP /XF *.ogg *.mp3 *.wav | Out-Null
if ($LASTEXITCODE -ge 8) { throw "Data\x64\sound のコピーに失敗しました" }
& robocopy (Join-Path $AppDir "third_party") (Join-Path $stage "third_party") /E /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "third_party のコピーに失敗しました" }
& attrib -R "$stage\*" /S /D | Out-Null

# 確認: 入ってはいけないものが入っていないか
foreach ($bad in @("license.cert", "keys", "Songs", "Backup")) {
    if (Test-Path (Join-Path $stage $bad)) { throw "配布の中身に $bad が入っています" }
}
# （datatable\sample のサンプルの譜面は、曲がないときの代わりに使う素材なので入れる）
$songs = Get-ChildItem (Join-Path $stage "Data\x64") -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in ".ogg", ".mp3", ".tja" -or ($_.Extension -eq ".wav" -and $_.FullName -like "*\Data\x64\sound\*") } |
    Where-Object { $_.FullName -notlike "*\Data\x64\datatable\sample\*" }
if ($songs) { throw "配布の中身に曲のファイルが入っています: $($songs[0].FullName)" }
$sizeMb = [math]::Round((Get-ChildItem $stage -Recurse -File | Measure-Object Length -Sum).Sum / 1MB, 0)
Write-Host "  中身: $sizeMb MB"

# ---- インストーラーを作る ----
New-Item -ItemType Directory -Force $Out | Out-Null
$outDir = (Resolve-Path $Out).Path
$outFile = Join-Path $outDir "GuminTaiko-Setup-$Version.exe"
$payload = Join-Path $outDir "GuminTaiko-Data.zip"
# 中身は 2GB を超えて NSIS の exe に入らないので、zip にして、インストーラーが同じフォルダから展開する
Step "中身を zip にします（数分かかります）: $payload"
if (Test-Path $payload) { Remove-Item $payload -Force }
& tar.exe -a -cf $payload -C $stage .
if ($LASTEXITCODE -ne 0) { throw "zip を作れませんでした" }
Step "インストーラーを作ります: $outFile"
& $makensis /V2 "/DOUTFILE=$outFile" "/DVERSION=$Version" "/DPAYLOAD=GuminTaiko-Data.zip" (Join-Path $Root "tools\installer.nsi")
if ($LASTEXITCODE -ne 0) { throw "インストーラーを作れませんでした" }

Step "できました: $outDir"
Write-Host "  配る物: $(Split-Path -Leaf $outFile)（$([math]::Round((Get-Item $outFile).Length / 1MB, 1)) MB）と GuminTaiko-Data.zip（$([math]::Round((Get-Item $payload).Length / 1MB, 0)) MB）。同じフォルダに置いて渡す"
Write-Host "  遊ぶ人は、インストーラーを実行 → ランチャーで「ID をコピー」→ あなたに送る → GuminLicense で証明書を作って送り返す → ランチャーの「証明書を入れる」"
