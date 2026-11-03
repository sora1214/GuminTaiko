# GuminTaiko を自分用のアプリとして配置する（保護付きのビルド・証明書・改変の検知・ショートカット）
#   使い方（ゲームのフォルダで）: powershell -ExecutionPolicy Bypass -File tools\package.ps1 [-AppDir Z:\GuminTaikoApp] [-Licensee 名前]
#   ・プログラムと素材（実行ファイル・Data\x64・third_party\vgmstream）は署名して読み取り専用にする。書き換えると起動しない
#   ・Songs と Data\x64\fumen（曲の追加。fumen の TJA の音源は Data\x64\sound の ogg・mp3）、
#     Data\x64\datatable\songs_index（曲の並び）、Backup（プレイヤーデータ・設定）、
#     Data\cache（音の変換結果）は自由に変えてよい
#   ・もう一度実行すると更新する（Songs は足すだけ、Backup は上書きしない）
param(
    [string]$AppDir = "Z:\GuminTaikoApp",
    [string]$Licensee = $env:USERNAME,
    [string]$UpdateUrl = "github:sora1214/GuminTaiko"   # ランチャーのアップデートの更新元（github:ユーザー/リポジトリ[@ブランチ]・URL・フォルダ）。update_url.txt に書く
)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

function Step($text) { Write-Host "== $text" -ForegroundColor Cyan }
function Robo($from, $to, $extra) {
    & robocopy $from $to /E /NFL /NDL /NJH /NJS /NP @extra | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "コピーに失敗しました: $from -> $to" }
}

# ---- 署名の鍵（初めてのときだけ作る）----
if (-not (Test-Path "keys\gumin_private.key")) {
    Step "署名の鍵を作ります"
    & ninja -C build gumin_sign.exe | Out-Null
    & build\gumin_sign.exe keygen
    if ($LASTEXITCODE -ne 0) { throw "鍵を作れません" }
}

# ---- 保護付きのビルド ----
Step "保護付きのビルドを作ります（build-release）"
& cmake -S . -B build-release -G Ninja -DCMAKE_BUILD_TYPE=Release -DGUMIN_PROTECT=ON -DCMAKE_CXX_COMPILER=C:/w64devkit/bin/c++.exe | Out-Null
& ninja -C build-release GuminTaiko.exe GuminLauncher.exe GuminDressUp.exe GuminDaniEditor.exe gumin_sign.exe GuminLicense.exe
if ($LASTEXITCODE -ne 0) { throw "ビルドに失敗しました" }

# ---- 配置 ----
Step "$AppDir に配置します"
New-Item -ItemType Directory -Force $AppDir | Out-Null
# 前の配置の読み取り専用を外す（上書きするため）
foreach ($p in @("$AppDir\*.exe", "$AppDir\*.dll", "$AppDir\license.cert", "$AppDir\manifest.sig")) {
    Get-ChildItem $p -ErrorAction SilentlyContinue | ForEach-Object { $_.IsReadOnly = $false }
}
foreach ($d in @("$AppDir\Data\x64", "$AppDir\third_party")) {
    if (Test-Path $d) { & attrib -R "$d\*" /S /D | Out-Null }
}
Copy-Item "build-release\GuminTaiko.exe" $AppDir -Force
Copy-Item "build-release\GuminLauncher.exe" $AppDir -Force
Copy-Item "build-release\GuminDressUp.exe" $AppDir -Force
Copy-Item "build-release\GuminDaniEditor.exe" $AppDir -Force
Robo "Data\x64" "$AppDir\Data\x64" @("/MIR", "/XD", "$Root\Data\x64\fumen", "$Root\Data\x64\datatable\songs_index",
                                       "$AppDir\Data\x64\fumen", "$AppDir\Data\x64\datatable\songs_index", "/XF", "*.ogg", "*.mp3")
# 曲の TJA（fumen）とその音源（sound の ogg・mp3）、曲の並び（songs_index）は Songs と同じく足すだけ（配置先で足したものは消さない）
if (Test-Path "Data\x64\fumen") { Robo "Data\x64\fumen" "$AppDir\Data\x64\fumen" @("/XO") }
& robocopy "Data\x64\sound" "$AppDir\Data\x64\sound" *.ogg *.mp3 /XO /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "コピーに失敗しました: Data\x64\sound の音源" }
if (Test-Path "Data\x64\datatable\songs_index") { Robo "Data\x64\datatable\songs_index" "$AppDir\Data\x64\datatable\songs_index" @("/XO") }
Robo "third_party\vgmstream" "$AppDir\third_party\vgmstream" @("/MIR")
Robo "Data\cache" "$AppDir\Data\cache" @("/XO")           # 変換ずみの音（無くても起動時に作る）
Robo "Songs" "$AppDir\Songs" @("/XO")                     # 曲は足すだけ（配置先で足した曲は消さない）
if (Test-Path "Dani") { Robo "Dani" "$AppDir\Dani" @("/XO") }   # 段位道場のお題（配置先で作ったお題は消さない）
if (-not (Test-Path "$AppDir\Backup")) { Robo "Backup" "$AppDir\Backup" @() }   # プレイヤーデータは初回だけ

# ---- 改変の検知と証明書 ----
Step "署名と証明書を作ります"
& build-release\gumin_sign.exe manifest $AppDir
if ($LASTEXITCODE -ne 0) { throw "署名に失敗しました" }
& build-release\gumin_sign.exe license $AppDir --licensee $Licensee
if ($LASTEXITCODE -ne 0) { throw "証明書を作れません" }

# ---- 読み取り専用（うっかり書き換えないように）----
Step "プログラムと素材を読み取り専用にします"
& attrib +R "$AppDir\*.exe" | Out-Null
& attrib +R "$AppDir\license.cert" | Out-Null
if ($UpdateUrl) { [IO.File]::WriteAllText("$AppDir\update_url.txt", $UpdateUrl + "`r`n") }
& attrib +R "$AppDir\manifest.sig" | Out-Null
& attrib +R "$AppDir\Data\x64\*" /S | Out-Null
foreach ($d in @("$AppDir\Data\x64\fumen", "$AppDir\Data\x64\datatable\songs_index")) {
    if (Test-Path $d) { & attrib -R "$d\*" /S /D | Out-Null }   # 曲は足したり変えたりしてよい
}
& attrib -R "$AppDir\Data\x64\sound\*.ogg" | Out-Null
& attrib -R "$AppDir\Data\x64\sound\*.mp3" | Out-Null
& attrib +R "$AppDir\third_party\*" /S | Out-Null

# ---- ショートカット（デスクトップとスタートメニュー）----
Step "ショートカットを作ります"
$shell = New-Object -ComObject WScript.Shell
$startMenu = Join-Path ([Environment]::GetFolderPath("Programs")) "GuminTaiko"
New-Item -ItemType Directory -Force $startMenu | Out-Null
foreach ($place in @([Environment]::GetFolderPath("Desktop"), $startMenu)) {
    foreach ($app in @(@("GuminTaiko ランチャー", "GuminLauncher.exe"), @("GuminTaiko", "GuminTaiko.exe"), @("GuminTaiko 着せかえ", "GuminDressUp.exe"),
                       @("GuminTaiko 段位道場のお題", "GuminDaniEditor.exe"))) {
        $lnk = $shell.CreateShortcut((Join-Path $place ($app[0] + ".lnk")))
        $lnk.TargetPath = Join-Path $AppDir $app[1]
        $lnk.WorkingDirectory = $AppDir
        $lnk.Save()
    }
    # ライセンス作成アプリは秘密鍵のあるゲームのフォルダで動かす（アプリのフォルダには入れない）
    $lnk = $shell.CreateShortcut((Join-Path $place "GuminTaiko ライセンス作成.lnk"))
    $lnk.TargetPath = Join-Path $Root "build-release\GuminLicense.exe"
    $lnk.WorkingDirectory = $Root
    $lnk.Save()
}

Step "できました: $AppDir"
Write-Host "  曲の追加: $AppDir\Songs に TJA のフォルダを入れる。または $AppDir\Data\x64\fumen に TJA、$AppDir\Data\x64\sound に ogg を入れる"
Write-Host "  ジャンルフォルダの曲の並び: $AppDir\Data\x64\datatable\songs_index の JSON（インデックスの大きい順）"
Write-Host "  段位道場のお題: 「GuminTaiko 段位道場のお題」で作る（$AppDir\Dani の JSON）"
Write-Host "  秘密鍵 keys\gumin_private.key はアプリと一緒に置かず、大事に保管してください"
