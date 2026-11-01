// Lumen（.nulm）の確認用ビューア
//   使い方: lumen_view <lumen/.../名前> [オプション...]
//     --load <lumen/.../名前>@<インスタンス>   LoadMovie でインスタンスの中身を差し替える
//     --play <インスタンス>@<ラベル>            GotoAndPlay する（"root" はルート）
//     --stop <インスタンス>@<ラベル>            GotoAndStop する
//     --hide <インスタンス>                     非表示にする
//     --shot <出力.png> --after <秒>            指定秒後に画面を保存して終了
//     --frame <N>                               --after の代わりに、1/60 秒ずつ N フレーム進めてから保存する
//   操作: Space 一時停止 / Esc 終了
#include <cstdlib>
#include <string>
#include <vector>

#include "AssetCache.hpp"
#include "GameFont.hpp"
#include "LumenPlayer.hpp"
#include "raylib.h"

namespace {

Lumen::MovieClip* Target(Lumen::Stage& stage, const std::string& name) {
    return name == "root" ? stage.Root() : stage.GetMovieClip(name);
}

bool Split(const std::string& arg, std::string& a, std::string& b) {
    const size_t at = arg.find('@');
    if (at == std::string::npos) return false;
    a = arg.substr(0, at);
    b = arg.substr(at + 1);
    return true;
}

} // namespace

int main(int argc, char** argv) {
    if (argc < 2) {
        TraceLog(LOG_ERROR, "usage: lumen_view <lumen/path> [options]");
        return 1;
    }

    std::string shotPath;
    float shotAfter = 2.0f;
    float drawX = 0.0f, drawY = 0.0f;   // --at x,y: 描く位置
    int shotFrame = -1;                 // --frame N: 1/60 秒ずつ N フレーム進めてから保存する（読み込みの時間に左右されない）
    std::vector<std::pair<std::string, std::string>> commands;
    for (int i = 2; i + 1 < argc; i += 2) {
        const std::string key = argv[i];
        if (key == "--shot") shotPath = argv[i + 1];
        else if (key == "--after") shotAfter = float(std::atof(argv[i + 1]));
        else if (key == "--frame") shotFrame = std::atoi(argv[i + 1]);
        else if (key == "--at") std::sscanf(argv[i + 1], "%f,%f", &drawX, &drawY);
        else commands.emplace_back(key, argv[i + 1]);
    }

    SetTraceLogLevel(LOG_WARNING);
    SetConfigFlags(FLAG_MSAA_4X_HINT);
    InitWindow(1920, 1080, "lumen_view");
    SetTargetFPS(60);

    Lumen::Stage stage;
    if (!stage.Load(argv[1])) {
        TraceLog(LOG_ERROR, "load failed: %s", argv[1]);
        CloseWindow();
        return 1;
    }

    for (const auto& command : commands) {
        std::string a, b;
        if (command.first == "--load" && Split(command.second, a, b)) {
            stage.LoadMovie(a, b);
        } else if ((command.first == "--play" || command.first == "--stop") && Split(command.second, a, b)) {
            Lumen::MovieClip* clip = Target(stage, a);
            if (!clip) {
                TraceLog(LOG_WARNING, "instance not found: %s", a.c_str());
                continue;
            }
            const bool ok = command.first == "--play" ? clip->GotoAndPlay(b) : clip->GotoAndStop(b);
            if (!ok) TraceLog(LOG_WARNING, "label not found: %s@%s", a.c_str(), b.c_str());
        } else if (command.first == "--hide") {
            if (Lumen::MovieClip* clip = Target(stage, command.second)) clip->SetVisible(false);
        }
    }

    // --ext <配置名>: 差し込み枠に確認用の画像（枠線と中央の円）を貼る
    Image testImage = GenImageColor(1920, 1080, Color{0, 0, 0, 0});
    ImageDrawRectangleLines(&testImage, Rectangle{0, 0, 1920, 1080}, 12, YELLOW);
    ImageDrawCircle(&testImage, 960, 540, 200, RED);
    ImageDrawCircle(&testImage, 960, 540, 20, WHITE);
    Texture2D testTexture = LoadTextureFromImage(testImage);
    UnloadImage(testImage);
    for (const auto& command : commands) {
        if (command.first == "--ext") Lumen::SetExternalTexture(command.second, &testTexture);
    }

    bool paused = false;
    float time = 0.0f;
    int frames = 0;
    while (!WindowShouldClose()) {
        const float dt = shotFrame >= 0 ? 1.0f / 60.0f : GetFrameTime();
        time += dt;
        if (IsKeyPressed(KEY_SPACE)) paused = !paused;
        if (!paused) stage.Update(dt);

        BeginDrawing();
        ClearBackground(Color{40, 40, 48, 255});
        stage.Draw(drawX, drawY);
        EndDrawing();

        if (!shotPath.empty() && (shotFrame >= 0 ? frames++ >= shotFrame : time >= shotAfter)) {
            TakeScreenshot(shotPath.c_str());
            break;
        }
    }

    Lumen::UnloadAllMovies();
    AssetCache::Get().UnloadAll();
    GameFont::Get().Unload();
    CloseWindow();
    return 0;
}
