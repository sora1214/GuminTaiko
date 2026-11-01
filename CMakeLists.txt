cmake_minimum_required(VERSION 3.16)

if(POLICY CMP0167)
    cmake_policy(SET CMP0167 OLD)
endif()

project(GuminTaiko CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 自作ヘッダーおよび Raylib のインクルードパス指定
include_directories(
    ${CMAKE_SOURCE_DIR}/include
    ${CMAKE_SOURCE_DIR}/third_party/raylib/include
    ${CMAKE_SOURCE_DIR}/third_party/bcdec
)

# Raylib のライブラリ検索パス指定
link_directories(
    ${CMAKE_SOURCE_DIR}/third_party/raylib/lib
)

# ソースファイルの取得
file(GLOB_RECURSE SOURCES "src/*.cpp")

# 実行ファイルの作成
add_executable(GuminTaiko ${SOURCES})

# WindowsでRaylib動作に必要なシステムライブラリをまとめてリンク
target_link_libraries(GuminTaiko PRIVATE
    raylib
    opengl32
    gdi32
    winmm
    ole32   # 低遅延の効果音出力（WASAPI）
    dwmapi  # 垂直同期が効かないときに画面の合成に合わせて描く（DwmFlush）
    bcrypt  # アプリの保護（証明書と改変の検知。AppGuard）
    advapi32
)

# 保護付きのビルド（自分用に配置するアプリ。tools/package.ps1 が使う）
#   起動時に証明書（license.cert）と改変の検知（manifest.sig）を確かめる。コンソールの窓は出さない
option(GUMIN_PROTECT "証明書と改変の検知を有効にする" OFF)
if(GUMIN_PROTECT)
    target_compile_definitions(GuminTaiko PRIVATE GUMIN_PROTECT)
    set_target_properties(GuminTaiko PROPERTIES WIN32_EXECUTABLE ON)
endif()

# BC7 の展開はデバッグビルドだと遅いので、ここだけ常に最適化する
set_source_files_properties(src/Nutexb.cpp PROPERTIES COMPILE_OPTIONS "-O2")

# 確認用ツール: .nulm の構造を表示する
add_executable(lumen_dump tools/lumen_dump.cpp src/Lumen.cpp)

# 確認用ツール: .nulm を再生する
add_executable(lumen_view tools/lumen_view.cpp src/Lumen.cpp src/LumenPlayer.cpp src/Nutexb.cpp src/AssetCache.cpp src/GameFont.cpp src/WordList.cpp src/DataTable.cpp)
target_link_libraries(lumen_view PRIVATE
    raylib
    opengl32
    gdi32
    winmm
)

# 確認用ツール: SSBH モデルの中身を表示する
add_executable(ssbh_dump tools/ssbh_dump.cpp src/Ssbh.cpp)

# 確認用ツール: 3D どんちゃんを表示する
add_executable(don_view tools/don_view.cpp src/DonModel.cpp src/Ssbh.cpp src/Nutexb.cpp src/AssetCache.cpp)
target_link_libraries(don_view PRIVATE
    raylib
    opengl32
    gdi32
    winmm
)

# 着せかえアプリ: カード（Backup/players の JSON）のどんちゃんの着せかえを変える（本家のドンだーひろばの代わり）
add_executable(GuminDressUp WIN32 tools/gumin_dressup.cpp src/DonModel.cpp src/Ssbh.cpp src/Nutexb.cpp src/AssetCache.cpp
    src/GameFont.cpp src/WordList.cpp src/DataTable.cpp src/DonCatalog.cpp src/PlayRecord.cpp src/Json.cpp
    src/AppGuard.cpp src/GuardCrypto.cpp)
set_source_files_properties(tools/gumin_dressup.cpp PROPERTIES COMPILE_OPTIONS "-O2")
target_link_libraries(GuminDressUp PRIVATE
    raylib
    opengl32
    gdi32
    winmm
    bcrypt
    advapi32
)
if(GUMIN_PROTECT)
    target_compile_definitions(GuminDressUp PRIVATE GUMIN_PROTECT)
endif()

# 保護の鍵・署名・証明書を作るツール（開発の PC だけで使う。配置したアプリには入れない）
add_executable(gumin_sign tools/gumin_sign.cpp src/AppGuard.cpp src/GuardCrypto.cpp)
target_link_libraries(gumin_sign PRIVATE bcrypt advapi32 user32)

# 段位道場のお題（Dani/*.json）を作るアプリ
add_executable(GuminDaniEditor WIN32 tools/gumin_dani_editor.cpp src/DaniData.cpp src/SongDatabase.cpp src/Tja.cpp src/Fumen.cpp
    src/WordList.cpp src/DataTable.cpp src/Json.cpp src/GameFont.cpp src/Nutexb.cpp src/AssetCache.cpp src/SoundManager.cpp
    src/HitAudio.cpp src/ProcessUtil.cpp src/AppGuard.cpp src/GuardCrypto.cpp)
target_link_libraries(GuminDaniEditor PRIVATE
    raylib
    opengl32
    gdi32
    winmm
    ole32
    shell32
    uuid
    bcrypt
    advapi32
)
if(GUMIN_PROTECT)
    target_compile_definitions(GuminDaniEditor PRIVATE GUMIN_PROTECT)
endif()

# ライセンス作成アプリ: 別の PC 用の証明書（license.cert）を作る（秘密鍵のある開発の PC だけで使う）
add_executable(GuminLicense WIN32 tools/gumin_license.cpp src/AppGuard.cpp src/GuardCrypto.cpp src/ProcessUtil.cpp
    src/GameFont.cpp src/Nutexb.cpp src/AssetCache.cpp)
target_link_libraries(GuminLicense PRIVATE
    raylib
    opengl32
    gdi32
    winmm
    bcrypt
    advapi32
    shell32
    ole32
    uuid
)

# ランチャー: 遊ぶ・設定・ファイル確認・証明書・曲の追加（配布して遊ぶためのアプリ）
add_executable(GuminLauncher WIN32 tools/gumin_launcher.cpp tools/gumin_launcher_win.cpp src/AppGuard.cpp src/GuardCrypto.cpp src/ProcessUtil.cpp
    src/GameFont.cpp src/Nutexb.cpp src/AssetCache.cpp)
target_link_libraries(GuminLauncher PRIVATE
    raylib
    opengl32
    gdi32
    winmm
    bcrypt
    advapi32
    shell32
    ole32
    uuid
    comdlg32
    winhttp
)
if(GUMIN_PROTECT)
    target_compile_definitions(GuminLauncher PRIVATE GUMIN_PROTECT)
endif()

# 確認用ツール: .nutexb を PNG に書き出す
add_executable(nutexb_dump tools/nutexb_dump.cpp src/Nutexb.cpp)
target_link_libraries(nutexb_dump PRIVATE
    raylib
    opengl32
    gdi32
    winmm
)
