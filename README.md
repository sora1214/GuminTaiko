# GuminTaiko

太鼓の達人 ニジイロ ver. の画面・遊びかたを再現した、C++17 / raylib の個人用ゲームです。

## 遊ぶ（Windows 10 / 11）

1. インストーラー `GuminTaiko-WebSetup-*.exe`（[Releases](../../releases)）を実行します。
2. 入ったランチャーを開くと、足りないファイルを GitHub から取ってきます（初回は約 2.4GB。右下の「アップデート」を押す）。
3. 証明書（license.cert）はお使いの PC ごとのものです。ランチャーの「ID をコピー」で PC の ID をコピーして作者に送り、
   もらった license.cert を「証明書を入れる」で入れてください。
4. 「ゲームを起動」で遊べます。

曲は付いていません。自分で用意した曲（TJA と音源）を、ランチャーの「曲を追加」（ドラッグ＆ドロップ）か、
`Data\x64\fumen`（TJA）と `Data\x64\sound`（ogg・mp3）に入れてください。ランチャーの「Data」で、フォルダを開けます。

## 作る（開発者向け）

- 必要なもの: Windows、w64devkit（g++ / ninja）、CMake、NSIS（インストーラー）
- `cmake -S . -B build -G Ninja -DCMAKE_CXX_COMPILER=C:/w64devkit/bin/c++.exe` → `ninja -C build GuminTaiko.exe GuminLauncher.exe`
- 配布用: `tools\package.ps1`（署名つきのビルドを配置）→ `tools\make_update.ps1 -Publish`（アップデートを GitHub に出す）→
  `tools\make_installer.ps1 -Web`（ウェブ版のインストーラー）
- 署名の秘密鍵 `keys\gumin_private.key` は、リポジトリに入れません（`tools\gumin_sign keygen` で自分用を作る）

## 権利について

画面・モデル・音などの素材（`Data\x64`）は、太鼓の達人（バンダイナムコ）のものを元にしています。曲・譜面は含みません。