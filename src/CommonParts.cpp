#include "CommonParts.hpp"

#include <algorithm>
#include <string>

#include "EnsoScene.hpp"
#include "GameFont.hpp"
#include "SoundManager.hpp"
#include "TaikoInput.hpp"
#include "PlayData.hpp"
#include "PlayRecord.hpp"
#include "WordList.hpp"

using namespace GuminTaiko;

namespace CommonParts {

void SetNamePlate(Lumen::MovieClip* root, int player) {
    if (!root) return;
    const PlayDataManager& pd = PlayDataManager::Get();
    const PlayerData& data = pd.Player(player);
    Lumen::MovieClip* plate = root->Child("main");
    if (!plate) return;

    const std::string side = std::to_string(player + 1);
    std::string label = side + (data.userType == UserType::Coin ? "p_coin" : "p");
    if (data.userType == UserType::Card && !data.title.empty()) label += "_shougou";

    // 段位（lua: NamePlate の dani。合格したいちばん上の段位を、赤・金と、クリア・フルコンボ・ドンダフルの札で出す）
    int nowDani = 0;
    DaniRecord dani;
    if (data.userType == UserType::Card) {
        const std::string owner = PlayRecords::Owner(player);
        nowDani = PlayRecords::Get().NowDani(owner);
        if (nowDani > 0) dani = PlayRecords::Get().Dani(owner, nowDani);
    }
    if (nowDani > 0 && dani.rank >= 2) {
        label += "_dani";
        const int step = (dani.rank - 2) % 3;   // 0: クリア 1: フルコンボ 2: ドンダフル
        static const char* const kTypes[] = {"clear", "full", "donfull"};
        const std::string mark = std::string(DaniLabel(nowDani)) + (dani.rank >= 5 ? "_gold" : "_red");
        if (Lumen::MovieClip* clip = plate->Child("dani")) {
            clip->GotoAndStop(kTypes[step]);
            for (const char* type : kTypes) {
                if (Lumen::MovieClip* instance = clip->Child(std::string("dani_") + type + "_instance")) instance->GotoAndStop(mark);
            }
        }
    }
    plate->GotoAndStop(label);

    // 称号の地（lua: titlebase_name[title_base_id + 1]）
    if (Lumen::MovieClip* title = plate->Child("title_instance")) title->GotoAndStop(TitleDesignLabel(data.titleDesign));

    // 1人のときは右側でも「1P」
    const int index = pd.EntryUserCount() == 1 ? 0 : player;
    if (Lumen::MovieClip* number = plate->Child("plate_player_no")) {
        number->SetVisible(true);
        number->GotoAndStop(index == 0 ? "1p" : "2p");
    }
    if (Lumen::MovieClip* blank = plate->Child("blank_instance")) blank->GotoAndStop(data.isUseCredit ? "off" : "on");

    WordList::Get().Set("user_name_p" + side, data.name);
    WordList::Get().Set("user_title_p" + side, data.title);
    plate->SetText("text_name", "user_name_p" + side);
    plate->SetText("text_title", "user_title_p" + side);
    StyleNamePlateText(plate);
}

void DrawNoRecordNotice() {
    constexpr float kCenterX = 1400.0f, kTop = 990.0f, kWidth = 640.0f, kHeight = 56.0f, kSize = 34.0f;
    DrawRectangleRounded(Rectangle{kCenterX - kWidth * 0.5f, kTop, kWidth, kHeight}, 1.0f, 16, Color{0, 0, 0, 190});
    GameFont& font = GameFont::Get();
    const char* text = "オートプレイのため、記録は残りません";
    const Vector2 size = font.Measure(text, kSize);
    font.Draw(text, kCenterX, kTop + (kHeight - size.y) * 0.5f, kSize, WHITE, TextAlign::Center);
}

bool ToggleAutoPlay() {
    if (!TaikoInput::KeyPressed(KEY_F3)) return false;
    EnsoScene::autoPlay = !EnsoScene::autoPlay;
    // 太鼓の音色「豪華な太鼓」（se_neiro_03）のドン（オートにしたとき）とカッ（もどしたとき）
    SoundManager::Get().Play("se_neiro_03_v12a", EnsoScene::autoPlay ? "don_c" : "katsu_c");
    return true;
}

void DrawAutoBadge(float left, float centerY, float scale) {
    if (!EnsoScene::autoPlay) return;
    // 元の素材（Data\x64\lumen\000_default\Auto.png。80x40）。初めて描くときに読み込む
    static Texture2D texture = {};
    static bool tried = false;
    if (!tried) {
        tried = true;
        texture = LoadTexture("Data/x64/lumen/000_default/Auto.png");
        if (texture.id != 0) SetTextureFilter(texture, TEXTURE_FILTER_BILINEAR);
    }
    // 素材の左半分は透明なので、絵のある右半分（40〜80）だけを使う
    constexpr float kSourceLeft = 40.0f;
    const float kScale = scale;
    if (texture.id == 0) return;
    const Rectangle source = {kSourceLeft, 0.0f, float(texture.width) - kSourceLeft, float(texture.height)};
    const Rectangle dest = {left, centerY - source.height * kScale * 0.5f, source.width * kScale, source.height * kScale};
    DrawTexturePro(texture, source, dest, Vector2{0.0f, 0.0f}, 0.0f, WHITE);
}
void StyleNamePlateText(Lumen::MovieClip* plate) {
    if (!plate) return;
    // 位置はプレートの座標。文字の枠（高さ 60）の中央だと帯より下に出るので上げる
    constexpr float kTitleOffsetY = -5.0f;
    constexpr float kNameOffsetY = -5.5f;
    // 字形は選曲のジャンルの看板と同じ（jp_64）
    Lumen::MovieClip::TextStyle title;
    title.fill = Color{0, 0, 0, 255};
    title.outlineRatio = 0.0f;
    title.offsetY = kTitleOffsetY;
    title.face = FontFace::Large;
    plate->SetTextStyle("text_title", title);
    Lumen::MovieClip::TextStyle name;
    name.fill = Color{255, 255, 255, 255};
    name.outline = Color{0, 0, 0, 255};
    name.outlineRatio = 0.14f;
    name.offsetY = kNameOffsetY;
    name.face = FontFace::Large;
    plate->SetTextStyle("text_name", name);
}

void SetTimerCount(Lumen::MovieClip* timeCount, int count, int redLimit) {
    if (!timeCount) return;
    Lumen::MovieClip* counter = timeCount->Child("counter_instance");
    if (!counter) return;
    const int value = std::clamp(count, 0, 999);
    const std::string d0 = "_" + std::to_string(value % 10);
    const std::string d1 = "_" + std::to_string(value / 10 % 10);
    const std::string d2 = "_" + std::to_string(value / 100 % 10);

    auto digit = [&](const char* name, const std::string& label) {
        if (Lumen::MovieClip* d = counter->Child(name)) d->GotoAndStop(label);
    };
    if (value > 99) {
        counter->GotoAndStop("num3");
        digit("digit2", d2);
        digit("digit1", d1);
        digit("digit0", d0);
    } else if (value > 9) {
        counter->GotoAndStop("num2");
        digit("digit1", d1);
        digit("digit0", d0);
    } else if (value > redLimit) {
        counter->GotoAndStop("num1");
        digit("digit0", d0);
    } else {
        counter->GotoAndStop("num1_effect");
        if (Lumen::MovieClip* effect = counter->Child("digit0_effect")) {
            if (Lumen::MovieClip* body = effect->Child("body")) body->GotoAndStop(d0);
            effect->Play();
        }
    }
}

} // namespace CommonParts
