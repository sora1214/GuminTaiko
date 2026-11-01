#include "PlaceholderScene.hpp"

#include <algorithm>
#include <memory>

#include "EntryScene.hpp"
#include "GameFont.hpp"
#include "PlayData.hpp"
#include "SceneManager.hpp"
#include "SongDatabase.hpp"
#include "TaikoInput.hpp"
#include "WordList.hpp"
#include "raylib.h"

using namespace GuminTaiko;

void PlaceholderScene::Initialize() {
    time_ = 0.0f;
}

void PlaceholderScene::Update(float deltaTime) {
    time_ += deltaTime;
    if (time_ > 0.5f && TaikoInput::AnyDon()) {
        SceneManager::GetInstance().ChangeScene(std::make_unique<EntryScene>());
    }
}

void PlaceholderScene::Draw() {
    const PlayDataManager& pd = PlayDataManager::Get();
    GameFont& font = GameFont::Get();

    ClearBackground(Color{30, 24, 40, 255});

    // 曲選択画面から来たときは、選んだ曲と難易度を出す
    if (pd.DecidedMode() == GameMode::Enso && pd.SelectedSong() >= 0) {
        static const char* const kCourseKeys[] = {"course_easy", "course_normal", "course_hard", "course_mania", "course_ura"};
        const SongInfo* song = SongDatabase::Get().FindSong(pd.SelectedSong());
        font.Draw("曲が決まりました", 960.0f, 150.0f, 80.0f, GOLD, TextAlign::Center, 5.0f, BLACK);
        if (song) {
            font.Draw(WordList::Get().Text("song_" + song->id).c_str(), 960.0f, 280.0f, 64.0f, RAYWHITE, TextAlign::Center);
            font.Draw(WordList::Get().Text("song_sub_" + song->id).c_str(), 960.0f, 360.0f, 36.0f, LIGHTGRAY, TextAlign::Center);
        }
        font.Draw("次は「演奏画面」です（未実装）", 960.0f, 780.0f, 44.0f, RAYWHITE, TextAlign::Center);
        for (int p = 0; p < 2; ++p) {
            const PlayerData& data = pd.Player(p);
            if (data.userType == UserType::None) continue;
            const int course = std::clamp(pd.SelectedCourse(p), 0, 4);
            font.Draw(TextFormat("%dP: %s", p + 1, WordList::Get().Text(kCourseKeys[course]).c_str()), 960.0f,
                      480.0f + float(p) * 90.0f, 52.0f, p == 0 ? Color{255, 120, 100, 255} : Color{110, 180, 255, 255},
                      TextAlign::Center);
        }
        font.Draw("面をたたくとエントリー画面にもどります", 960.0f, 880.0f, 36.0f, LIGHTGRAY, TextAlign::Center);
        return;
    }

    const char* next = "曲選択画面";
    if (pd.DecidedMode() == GameMode::Dani) next = "段位道場 選択画面";
    if (pd.DecidedMode() == GameMode::AI) next = "AIバトル演奏 選択画面";

    font.Draw("エントリー完了", 960.0f, 200.0f, 80.0f, GOLD, TextAlign::Center, 5.0f, BLACK);
    font.Draw(TextFormat("次は「%s」です（未実装）", next), 960.0f, 330.0f, 48.0f, RAYWHITE, TextAlign::Center);

    for (int p = 0; p < 2; ++p) {
        const PlayerData& data = pd.Player(p);
        const float y = 480.0f + float(p) * 110.0f;
        const char* type = data.userType == UserType::Card ? "カード" : data.userType == UserType::Coin ? "ゲスト" : "不参加";
        if (data.userType == UserType::None) {
            font.Draw(TextFormat("%dP: 不参加", p + 1), 960.0f, y, 44.0f, GRAY, TextAlign::Center);
        } else {
            font.Draw(TextFormat("%dP: %s（%s） きせかえ %d", p + 1, data.name.c_str(), type, data.costume), 960.0f, y,
                      44.0f, p == 0 ? Color{255, 120, 100, 255} : Color{110, 180, 255, 255}, TextAlign::Center);
        }
    }

    font.Draw("面をたたくとエントリー画面にもどります", 960.0f, 860.0f, 36.0f, LIGHTGRAY, TextAlign::Center);
}
