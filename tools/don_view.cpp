// 3D どんちゃんの確認用ビューア
//   使い方: don_view [--shot 出力.png --after 秒] [--yaw 角度] [--face 表情]
//                    [--pose アニメーション名 [--frame フレーム | --play 1]]
#include <cstdio>
#include <cstdlib>
#include <string>

#include "AssetCache.hpp"
#include "DonModel.hpp"
#include "raymath.h"

int main(int argc, char** argv) {
    std::string shot;
    float after = 1.0f, yaw = 0.0f;
    int face = 0;
    std::string pose;
    float poseFrame = 0.0f;
    bool play = false;
    for (int i = 1; i + 1 < argc; i += 2) {
        const std::string key = argv[i];
        if (key == "--pose") pose = argv[i + 1];
        else if (key == "--frame") poseFrame = float(std::atof(argv[i + 1]));
        else if (key == "--play") play = std::atoi(argv[i + 1]) != 0;
        else if (key == "--shot") shot = argv[i + 1];
        else if (key == "--after") after = float(std::atof(argv[i + 1]));
        else if (key == "--yaw") yaw = float(std::atof(argv[i + 1]));
        else if (key == "--face") face = std::atoi(argv[i + 1]);
    }
    // 着せかえ: --cos N（きぐるみ）/ --body N / --head N / --faceset N / --colors 顔,胴,ふち
    DonModel::Costume costume;
    for (int i = 1; i + 1 < argc; i += 2) {
        const std::string key = argv[i];
        if (key == "--cos") costume.kigurumi = std::atoi(argv[i + 1]);
        else if (key == "--body") costume.body = std::atoi(argv[i + 1]);
        else if (key == "--head") costume.head = std::atoi(argv[i + 1]);
        else if (key == "--faceset") costume.face = std::atoi(argv[i + 1]);
        else if (key == "--preset") costume = DonModel::Preset(std::atoi(argv[i + 1]));
        else if (key == "--colors") std::sscanf(argv[i + 1], "%d,%d,%d", &costume.faceColor, &costume.bodyColor, &costume.legsColor);
    }

    SetTraceLogLevel(LOG_WARNING);
    SetConfigFlags(FLAG_MSAA_4X_HINT);
    InitWindow(1200, 600, "don_view");
    SetTargetFPS(60);

    DonModel don;
    don.SetCostume(0, costume);
    don.Load();
    if (!pose.empty()) don.SetPose(pose, poseFrame);

    float zoom = 1.0f;
    float targetY = 0.14f;
    for (int i = 1; i + 1 < argc; i += 2) {
        if (std::string(argv[i]) == "--zoom") zoom = float(std::atof(argv[i + 1]));
        if (std::string(argv[i]) == "--ty") targetY = float(std::atof(argv[i + 1]));
        if (std::string(argv[i]) == "--outline") don.SetOutline(std::atoi(argv[i + 1]) != 0);
    }
    Camera3D camera{};
    camera.position = Vector3{0.0f, targetY + 0.01f, 1.6f / zoom};
    camera.target = Vector3{0.0f, targetY, 0.0f};
    camera.up = Vector3{0.0f, 1.0f, 0.0f};
    camera.fovy = 22.0f;
    camera.projection = CAMERA_PERSPECTIVE;

    float time = 0.0f;
    while (!WindowShouldClose()) {
        time += GetFrameTime();
        if (IsKeyDown(KEY_LEFT)) yaw -= 90.0f * GetFrameTime();
        if (IsKeyDown(KEY_RIGHT)) yaw += 90.0f * GetFrameTime();
        if (play && !pose.empty()) don.PlayLoop(pose, time);

        BeginDrawing();
        ClearBackground(Color{70, 70, 90, 255});
        BeginMode3D(camera);
        for (int side = 0; side < 2; ++side) {
            const Matrix m = MatrixMultiply(MatrixRotateY(yaw * DEG2RAD), MatrixTranslate(side == 0 ? -0.2f : 0.2f, 0.0f, 0.0f));
            don.Draw(side, face, m);
        }
        EndMode3D();
        EndDrawing();

        if (!shot.empty() && time >= after) {
            TakeScreenshot(shot.c_str());
            break;
        }
    }
    don.Unload();
    AssetCache::Get().UnloadAll();
    CloseWindow();
    return 0;
}
