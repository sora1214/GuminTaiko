// GuminDressUp: バナパスポート（カード）のどんちゃんの着せかえアプリ
//   本家の「ドンだーひろば」の着せかえの代わり。Backup/players/<カードID>.json の profile.costume / dress を書き換える。
//   着せかえはすべて解放してある（datatable/don_cos_reward.bin のうち、モデルのデータがあるもの）。
//
//   操作: ↑↓ 項目を選ぶ  ←→ 選んでいる項目を変える（Shift で 10 ずつ）  Enter / Ctrl+S 保存
//         Tab / Shift+Tab カードを切り替える  マウス: 行をクリックで選択、◀ ▶ をクリックで変更、ホイールで変更
//         プレビューのどんちゃんはドラッグで回せる
//   使い方: GuminDressUp [--card カードID] [--shot 出力.png --after 秒]
#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <string>
#include <vector>

#include "AppGuard.hpp"
#include "AssetCache.hpp"
#include "DonCostume.hpp"
#include "DonModel.hpp"
#include "GameFont.hpp"
#include "PlayRecord.hpp"
#include "raymath.h"

using namespace GuminTaiko;

namespace {

constexpr int kWidth = 1280;
constexpr int kHeight = 720;
constexpr int kPreviewSize = 640;

const Color kBack{250, 236, 210, 255};
const Color kInk{52, 26, 18, 255};
const Color kSub{120, 90, 60, 255};
const Color kPanel{255, 250, 238, 255};
const Color kGold{255, 206, 64, 255};
const Color kRed{236, 72, 48, 255};
const Color kDim{52, 26, 18, 90};

const char* const kCostumeNames[] = {"いつもの", "クール", "キュート", "ジョーク", "", "じぶんで"};
// きせかえの行で選べる番号（4: おまかせ はカードでは使わない）
const int kCostumeChoices[] = {0, 1, 2, 3, kDonCostumeCustom};

// 行: 0 きせかえ、1〜7 着せかえの項目、8 保存
constexpr int kRowCostume = 0;
constexpr int kRowFirstField = 1;
constexpr int kRowSave = kRowFirstField + int(DonCatalog::Field::Count);
constexpr float kRowTop = 150.0f;
constexpr float kRowHeight = 58.0f;
constexpr float kRowLeft = 660.0f;
constexpr float kRowWidth = 590.0f;

void Text(const std::string& text, float x, float y, float size, Color color, TextAlign align = TextAlign::Left) {
    GameFont::Get().Draw(text.c_str(), x, y, size, color, align);
}

// 横幅に収まるように縮めて描く
void FitText(const std::string& text, float x, float y, float size, float width, Color color) {
    const float measured = GameFont::Get().Measure(text.c_str(), size).x;
    if (measured > width) size *= width / measured;
    Text(text, x, y + (24.0f - size) * 0.5f, size, color);
}

Rectangle RowRect(int row) { return Rectangle{kRowLeft, kRowTop + float(row) * kRowHeight, kRowWidth, kRowHeight - 8.0f}; }
Rectangle LeftArrow(int row) {
    const Rectangle r = RowRect(row);
    return Rectangle{r.x + 190.0f, r.y + 6.0f, 36.0f, r.height - 12.0f};
}
Rectangle RightArrow(int row) {
    const Rectangle r = RowRect(row);
    return Rectangle{r.x + r.width - 46.0f, r.y + 6.0f, 36.0f, r.height - 12.0f};
}

struct App {
    std::vector<std::string> cards;
    int cardIndex = 0;
    CardProfile profile;
    CardProfile saved;           // 最後に保存した（読み込んだ）中身。変えたかどうかの判定に使う
    int row = kRowCostume;
    std::string message;
    float messageTime = 0.0f;

    bool Dirty() const { return profile.costume != saved.costume || profile.dress != saved.dress; }

    void LoadCard(int index) {
        if (cards.empty()) return;
        cardIndex = (index % int(cards.size()) + int(cards.size())) % int(cards.size());
        if (!PlayRecords::Get().Card(cards[size_t(cardIndex)], profile)) profile = CardProfile{cards[size_t(cardIndex)]};
        // おまかせ（4）はカードでは使わないので いつもの にする
        if (profile.costume == kDonCostumeRandom) profile.costume = 0;
        saved = profile;
    }

    void Save() {
        if (PlayRecords::Get().SetCard(profile)) {
            saved = profile;
            Show("保存しました（" + profile.cardId + "）");
        } else {
            Show("保存できませんでした");
        }
    }

    void Show(const std::string& text) {
        message = text;
        messageTime = 3.0f;
    }

    // 行の中身を変える
    void Change(int targetRow, int direction) {
        if (targetRow == kRowCostume) {
            int index = 0;
            for (int i = 0; i < 5; ++i) {
                if (kCostumeChoices[i] == profile.costume) index = i;
            }
            profile.costume = kCostumeChoices[((index + direction) % 5 + 5) % 5];
            return;
        }
        if (targetRow >= kRowFirstField && targetRow < kRowSave) {
            // 項目を変えたら「じぶんで」にする（組のままだと着せかえが見えないので）
            if (profile.costume != kDonCostumeCustom) {
                profile.dress = DonModel::Preset(std::clamp(profile.costume, 0, DonModel::kPresetCount - 1));
                profile.costume = kDonCostumeCustom;
            }
            DonCatalog::Step(profile.dress, DonCatalog::Field(targetRow - kRowFirstField), direction);
        }
    }
};

} // namespace

int main(int argc, char** argv) {
    std::string cardArg, shot;
    float after = 2.0f;
    for (int i = 1; i + 1 < argc; i += 2) {
        const std::string key = argv[i];
        if (key == "--card") cardArg = argv[i + 1];
        else if (key == "--shot") shot = argv[i + 1];
        else if (key == "--after") after = float(std::atof(argv[i + 1]));
    }

    // 保護付きのビルド: 証明書と改変の検知（ゲームと同じ）
    if (!AppGuard::CheckAtStartup()) return 1;
    // ゲームと同じく、Data のあるフォルダ（ゲームのフォルダ）で動かす
    if (!DirectoryExists("Data")) {
        ChangeDirectory(GetApplicationDirectory());
        if (!DirectoryExists("Data") && DirectoryExists("../Data")) ChangeDirectory("..");
    }

    SetTraceLogLevel(LOG_WARNING);
    SetConfigFlags(FLAG_MSAA_4X_HINT | FLAG_VSYNC_HINT);
    InitWindow(kWidth, kHeight, "GuminTaiko 着せかえ");
    SetTargetFPS(60);
    SetExitKey(KEY_NULL);

    App app;
    app.cards = PlayRecords::Get().CardIds();
    int start = 0;
    for (size_t i = 0; i < app.cards.size(); ++i) {
        if (app.cards[i] == cardArg) start = int(i);
    }
    app.LoadCard(start);

    DonModel don;
    don.SetCostume(0, DonModel::FromEntry(app.profile.costume, -1, app.profile.dress));
    don.Load();
    RenderTexture2D preview = LoadRenderTexture(kPreviewSize, kPreviewSize);
    SetTextureFilter(preview.texture, TEXTURE_FILTER_BILINEAR);

    Camera3D camera{};
    camera.target = Vector3{0.0f, 0.14f, 0.0f};
    camera.position = Vector3{0.0f, 0.2f, 1.7f};
    camera.up = Vector3{0.0f, 1.0f, 0.0f};
    camera.fovy = 0.62f;
    camera.projection = CAMERA_ORTHOGRAPHIC;

    float time = 0.0f;
    float yaw = 20.0f;
    bool dragging = false;
    while (!WindowShouldClose()) {
        const float dt = GetFrameTime();
        time += dt;
        app.messageTime = std::max(0.0f, app.messageTime - dt);

        // ---- 入力 ----
        const bool shift = IsKeyDown(KEY_LEFT_SHIFT) || IsKeyDown(KEY_RIGHT_SHIFT);
        const bool ctrl = IsKeyDown(KEY_LEFT_CONTROL) || IsKeyDown(KEY_RIGHT_CONTROL);
        const int step = shift ? 10 : 1;
        if (IsKeyPressed(KEY_UP) || IsKeyPressedRepeat(KEY_UP)) app.row = (app.row + kRowSave) % (kRowSave + 1);
        if (IsKeyPressed(KEY_DOWN) || IsKeyPressedRepeat(KEY_DOWN)) app.row = (app.row + 1) % (kRowSave + 1);
        if (IsKeyPressed(KEY_LEFT) || IsKeyPressedRepeat(KEY_LEFT)) app.Change(app.row, -step);
        if (IsKeyPressed(KEY_RIGHT) || IsKeyPressedRepeat(KEY_RIGHT)) app.Change(app.row, step);
        if (IsKeyPressed(KEY_ENTER) || (ctrl && IsKeyPressed(KEY_S))) app.Save();
        if (IsKeyPressed(KEY_TAB) && app.cards.size() > 1) {
            if (app.Dirty()) app.Show("保存していない変更は消えました");
            app.LoadCard(app.cardIndex + (shift ? -1 : 1));
        }

        const Vector2 mouse = GetMousePosition();
        for (int r = 0; r <= kRowSave; ++r) {
            if (!CheckCollisionPointRec(mouse, RowRect(r))) continue;
            if (IsMouseButtonPressed(MOUSE_BUTTON_LEFT)) {
                app.row = r;
                if (r == kRowSave) app.Save();
                else if (CheckCollisionPointRec(mouse, LeftArrow(r))) app.Change(r, -1);
                else if (CheckCollisionPointRec(mouse, RightArrow(r))) app.Change(r, 1);
            }
            const float wheel = GetMouseWheelMove();
            if (wheel != 0.0f && r != kRowSave) {
                app.row = r;
                app.Change(r, wheel > 0.0f ? -1 : 1);
            }
        }
        // プレビューのドラッグで回す
        const Rectangle previewRect{20.0f, 70.0f, 600.0f, 600.0f};
        if (IsMouseButtonPressed(MOUSE_BUTTON_LEFT) && CheckCollisionPointRec(mouse, previewRect)) dragging = true;
        if (IsMouseButtonReleased(MOUSE_BUTTON_LEFT)) dragging = false;
        if (dragging) yaw += GetMouseDelta().x * 0.5f;
        else yaw += 12.0f * dt;

        // ---- どんちゃん ----
        don.SetCostume(0, DonModel::FromEntry(app.profile.costume, -1, app.profile.dress));
        if (don.IsLoaded()) don.PlayLoop("don_select_loop", time);
        BeginTextureMode(preview);
        ClearBackground(Color{0, 0, 0, 0});
        if (don.IsLoaded()) {
            BeginMode3D(camera);
            don.Draw(0, don.Expression(), MatrixRotateY(yaw * DEG2RAD));
            EndMode3D();
        }
        EndTextureMode();

        // ---- 画面 ----
        BeginDrawing();
        ClearBackground(kBack);
        DrawRectangle(0, 0, kWidth, 56, kRed);
        Text("GuminTaiko 着せかえ", 24.0f, 12.0f, 30.0f, WHITE);
        if (!app.cards.empty()) {
            const std::string card = "カード " + app.profile.cardId + (app.cards.size() > 1 ? "（Tab で切り替え）" : "");
            Text(card, float(kWidth) - 24.0f, 16.0f, 24.0f, WHITE, TextAlign::Right);
        }

        DrawRectangleRounded(previewRect, 0.06f, 8, kPanel);
        DrawTexturePro(preview.texture, Rectangle{0.0f, 0.0f, float(kPreviewSize), -float(kPreviewSize)}, previewRect,
                       Vector2{0.0f, 0.0f}, 0.0f, WHITE);
        Text(app.profile.title, previewRect.x + 24.0f, previewRect.y + 18.0f, 24.0f, kSub);
        Text(app.profile.name, previewRect.x + 24.0f, previewRect.y + 48.0f, 36.0f, kInk);

        if (app.cards.empty()) {
            Text("カードのプレイヤーデータがありません（Backup/players）", kRowLeft, kRowTop, 24.0f, kRed);
        }
        Text("着せかえはすべて解放されています", kRowLeft, 84.0f, 22.0f, kSub);
        for (int r = 0; r <= kRowSave; ++r) {
            const Rectangle rect = RowRect(r);
            const bool selected = r == app.row;
            DrawRectangleRounded(rect, 0.3f, 8, selected ? kGold : kPanel);
            if (r == kRowSave) {
                const std::string label = app.Dirty() ? "保存する（Enter）" : "保存済み";
                Text(label, rect.x + rect.width * 0.5f, rect.y + 12.0f, 26.0f, app.Dirty() ? kInk : kSub, TextAlign::Center);
                continue;
            }
            std::string name, value;
            bool used = true;
            if (r == kRowCostume) {
                name = "きせかえ";
                value = kCostumeNames[std::clamp(app.profile.costume, 0, kDonCostumeCustom)];
            } else {
                const DonCatalog::Field field = DonCatalog::Field(r - kRowFirstField);
                name = DonCatalog::FieldName(field);
                value = DonCatalog::ValueText(app.profile.dress, field);
                used = app.profile.costume == kDonCostumeCustom && DonCatalog::FieldUsed(app.profile.dress, field);
                if (field == DonCatalog::Field::FaceColor || field == DonCatalog::Field::BodyColor || field == DonCatalog::Field::LegsColor) {
                    const int color = field == DonCatalog::Field::FaceColor ? app.profile.dress.faceColor
                                      : field == DonCatalog::Field::BodyColor ? app.profile.dress.bodyColor
                                                                              : app.profile.dress.legsColor;
                    unsigned char cr = 255, cg = 255, cb = 255;
                    DonCatalog::ColorRgb(color, cr, cg, cb);
                    const Rectangle swatch{rect.x + 236.0f, rect.y + 12.0f, 26.0f, 26.0f};
                    DrawRectangleRec(swatch, kInk);
                    DrawRectangleRec(Rectangle{swatch.x + 2.0f, swatch.y + 2.0f, 22.0f, 22.0f}, color < 0 ? kPanel : Color{cr, cg, cb, 255});
                }
            }
            Text(name, rect.x + 16.0f, rect.y + 13.0f, 24.0f, used ? kSub : kDim);
            const bool color = r >= kRowFirstField + int(DonCatalog::Field::FaceColor);
            FitText(value, rect.x + (color ? 272.0f : 236.0f), rect.y + 13.0f, 24.0f, rect.width - (color ? 330.0f : 294.0f), used ? kInk : kDim);
            Text("◀", LeftArrow(r).x + 8.0f, LeftArrow(r).y + 8.0f, 22.0f, selected ? kRed : kDim);
            Text("▶", RightArrow(r).x + 8.0f, RightArrow(r).y + 8.0f, 22.0f, selected ? kRed : kDim);
        }
        Text("↑↓ 項目   ←→ 変更（Shift で 10 ずつ）   Enter 保存   ドラッグで回す", 24.0f, float(kHeight) - 36.0f, 20.0f, kSub);
        if (app.messageTime > 0.0f) Text(app.message, float(kWidth) - 24.0f, float(kHeight) - 36.0f, 22.0f, kRed, TextAlign::Right);
        EndDrawing();

        if (!shot.empty() && time >= after) {
            TakeScreenshot(shot.c_str());
            break;
        }
    }
    UnloadRenderTexture(preview);
    don.Unload();
    GameFont::Get().Unload();
    AssetCache::Get().UnloadAll();
    CloseWindow();
    return 0;
}
