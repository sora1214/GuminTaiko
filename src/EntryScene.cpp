#include "EntryScene.hpp"

#include <algorithm>
#include <cmath>
#include <memory>
#include <numeric>

#include "AssetCache.hpp"
#include "AttractScene.hpp"
#include "DaniSelectScene.hpp"
#include "DonModel.hpp"
#include "DonSprite.hpp"
#include "GameFont.hpp"
#include "GameSettings.hpp"
#include "PlaceholderScene.hpp"
#include "PlayRecord.hpp"
#include "SceneManager.hpp"
#include "SongSelectScene.hpp"
#include "SoundManager.hpp"
#include "TaikoInput.hpp"
#include "WordList.hpp"

# include <iostream>

using namespace GuminTaiko;

namespace {

constexpr float kScreenW = 1920.0f;
constexpr float kScreenH = 1080.0f;

// entry.nutexb のレイヤー構成（0: 空のグラデーション / 1: 背景のぼかし版 / 2: 背景）
constexpr const char* kEntryAtlasPath = "Data/x64/lumen/000_default/entry/entry.nutexb";
constexpr int kAtlasSky = 0;
constexpr int kAtlasBackgroundBlur = 1;
constexpr int kAtlasBackground = 2;
constexpr Rectangle kAtlasBackgroundRect{4.0f, 4.0f, 1920.0f, 1080.0f};

constexpr Color kColor1P{236, 72, 48, 255};
constexpr Color kColor2P{36, 140, 232, 255};
constexpr Color kCream{255, 246, 222, 255};
constexpr Color kPanelColor{255, 250, 238, 250};
constexpr Color kInk{52, 26, 18, 255};
constexpr Color kGold{255, 206, 64, 255};
constexpr Color kWhite{255, 255, 255, 255};
constexpr Color kSubText{120, 90, 60, 255};

// ---- サウンド（lua: kEntrySoundSlot_* / TSound） ----
constexpr int kSlotBgm0 = 0;
constexpr int kSlotBgm1 = 1;
constexpr int kSlotVoice0 = 2;
constexpr int kSlotVoice2 = 4;
constexpr const char* kBankBgm = "bgm_entry_v12a";
constexpr const char* kBankSe = "se_common_v12a";
constexpr const char* kBankVoice = "voice_common_v12a";
constexpr const char* kBankVoiceEntry = "voice_entry_v12a";

void PlaySe(const std::string& tone) { SoundManager::Get().Play(kBankSe, tone); }
void PlayVoice(const std::string& tone) { SoundManager::Get().Play(kBankVoice, tone); }
void PlayVoiceEntry(const std::string& tone) { SoundManager::Get().Play(kBankVoiceEntry, tone); }

// 1人なら中央、2人なら左右から鳴らす音の接尾辞
std::string SideSuffix(int player) {
    if (PlayDataManager::Get().EntryUserCount() <= 1) return "_c";
    return player == 0 ? "_l" : "_r";
}

// テスト用のバナパスポート（F3: 開発者のカード / F4: もう1枚のカード）。
// どちらもプレイヤーデータ（Backup/players/<カードID>.json）があれば登録済み、なければはじめてのカード
constexpr const char* kDeveloperCardId = PlayRecords::kDeveloperCardId;
constexpr const char* kSecondCardId = "GMN-0002-0002";

// きせかえ（lua: Don.kPreset_Default / Cool / Cute / Joke / Coice）
const char* const kCostumeNames[] = {"いつもの", "クール", "キュート", "ジョーク", "おまかせ", "じぶんで"};
constexpr int kCostumeCount = 6;
constexpr int kCostumeRandom = kDonCostumeRandom;
constexpr int kCostumeCustom = kDonCostumeCustom;   // じぶんで（すべての着せかえから選ぶ。本家にはない）
constexpr int kCustomDecideRow = int(DonCatalog::Field::Count);   // 「じぶんで」の最後の行（けってい）
// 「じぶんで」のアイコンと編集の板の位置（きせかえの板の左上からの位置。2P の板は右に同じ形で置かれる）
constexpr float kCostumeBoardLeft[2] = {60.0f, 980.0f};
constexpr float kCustomIconX = 737.0f;
constexpr float kCustomIconY = 760.0f;
constexpr float kCustomIconSize = 84.0f;
constexpr Rectangle kCustomPanel{40.0f, 668.0f, 800.0f, 238.0f};

// 名前入力
constexpr int kNameMax = 5;
constexpr const char* kDefaultCardName = "どんだー";

struct NameRow {
    const char* label;
    const char* chars;
};
const NameRow kNameRows[] = {
    {"あ行", "あいうえおぁぃぅぇぉ"},
    {"か行", "かきくけこがぎぐげご"},
    {"さ行", "さしすせそざじずぜぞ"},
    {"た行", "たちつてとだぢづでどっ"},
    {"な行", "なにぬねの"},
    {"は行", "はひふへほばびぶべぼぱぴぷぺぽ"},
    {"ま行", "まみむめも"},
    {"や行", "やゆよゃゅょ"},
    {"ら行", "らりるれろ"},
    {"わ行", "わをんゎー"},
    {"カナ", "アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲンー"},
    {"英字", "ABCDEFGHIJKLMNOPQRSTUVWXYZ"},
    {"数字", "0123456789"},
    {"記号", "！？・♪☆"},
};
constexpr int kNameRowCount = int(sizeof(kNameRows) / sizeof(kNameRows[0]));
constexpr int kNameRingDelete = kNameRowCount;
constexpr int kNameRingEnd = kNameRowCount + 1;
constexpr int kNameRingCount = kNameRowCount + 2;

// モード選択の看板
struct ModeInfo {
    const char* title;
    const char* comment;
    Color top;
    Color bottom;
    bool singleOnly;
};

const ModeInfo& GetModeInfo(GameMode mode) {
    static const ModeInfo kEnso{"演奏ゲーム", "好きな曲をえらんで遊ぼう！", {255, 150, 40, 255}, {228, 64, 40, 255}, false};
    static const ModeInfo kDani{"段位道場", "課題曲に挑戦して段位を獲得しよう！", {80, 80, 124, 255}, {30, 30, 56, 255}, true};
    static const ModeInfo kAI{"AIバトル演奏", "AIと演奏で勝負しよう！", {90, 200, 230, 255}, {60, 70, 190, 255}, true};
    switch (mode) {
    case GameMode::Dani: return kDani;
    case GameMode::AI: return kAI;
    default: return kEnso;
    }
}

// 初回描画で読み込み待ちが出ないよう、画面で使う文字をまとめて登録しておく
constexpr const char* kPreloadText =
    "エントリーモード選択プレイヤー設定のこり参加受付太鼓をたたいてスタート！コインを入れてね"
    "こちらバナパスポートカードをタッチしてねクレジット1プレイフリープレイ"
    "2人目の参加受付中太鼓をたたいて参加！演奏ゲーム段位道場AIバトル演奏"
    "好きな曲をえらんで遊ぼう課題曲に挑戦して段位を獲得しようAIと演奏で勝負しよう1人専用NEW!"
    "ふちをたたいてえらぶ面をたたいてけってい"
    "どちらの太鼓でプレイしますか？左の太鼓右の太鼓つかわないはじめてのカードですこのあと名前を登録してね"
    "サーバーに接続しています読み込みに成功しましたバナパスポートを確認しました"
    "このデータはすでに読み込んでいます別のカードをタッチしてねゲスト"
    "参加だドン！モードをえらんでね！つかう太鼓をえらんでね！名前を決めてね！きせかえをえらんでね！ヨシ！決定だドン！"
    "いつものクールキュートジョークおまかせなまえを入力してね文字の種類をえらぶ文字をえらぶけすおわりもどる"
    "この名前でいいですか？はいいいえちょっと待ってねあ行か行さ行た行な行は行ま行や行ら行わ行カナ英字数字記号"
    "キー操作ガイド師範代ぐみん道場の";

// ---------------------------------------------------------------------------
// 描画用の小物
// ---------------------------------------------------------------------------
float Clamp01(float v) { return std::min(1.0f, std::max(0.0f, v)); }

float EaseOutCubic(float t) {
    const float u = 1.0f - Clamp01(t);
    return 1.0f - u * u * u;
}

float EaseOutBack(float t) {
    t = Clamp01(t);
    const float c1 = 1.70158f;
    const float c3 = c1 + 1.0f;
    const float u = t - 1.0f;
    return 1.0f + c3 * u * u * u + c1 * u * u;
}

float EaseInQuad(float t) {
    t = Clamp01(t);
    return t * t;
}

Color Mix(Color a, Color b, float t) {
    t = Clamp01(t);
    return Color{
        (unsigned char)(a.r + (b.r - a.r) * t),
        (unsigned char)(a.g + (b.g - a.g) * t),
        (unsigned char)(a.b + (b.b - a.b) * t),
        (unsigned char)(a.a + (b.a - a.a) * t),
    };
}

Color WithAlpha(Color c, float alpha) {
    c.a = (unsigned char)(c.a * Clamp01(alpha));
    return c;
}

Color SideColor(int player) { return player == 0 ? kColor1P : kColor2P; }

bool Blink(float time, float period = 1.0f, float on = 0.6f) { return std::fmod(time, period) < on; }

Rectangle CenterRect(float cx, float cy, float w, float h) { return Rectangle{cx - w * 0.5f, cy - h * 0.5f, w, h}; }

Rectangle Expand(Rectangle r, float amount) {
    return Rectangle{r.x - amount, r.y - amount, r.width + amount * 2.0f, r.height + amount * 2.0f};
}

void Text(const char* text, float x, float y, float size, Color color, TextAlign align = TextAlign::Left,
          float outline = 0.0f, Color outlineColor = kInk) {
    GameFont::Get().Draw(text, x, y, size + 15.0f, color, align, outline, outlineColor);
}

// 縦位置を中心で指定する版
void TextMid(const char* text, float cx, float cy, float size, Color color, float outline = 0.0f,
             Color outlineColor = kInk, FontFace face = FontFace::Auto) {
    GameFont::Get().Draw(text, cx, cy - size * 0.5f, size, color, TextAlign::Center, outline, outlineColor, face);
}

// クレジット（「フリープレイ」「クレジット n」）の文字は、選曲画面のジャンルの看板と同じフォント
constexpr FontFace kCreditFace = FontFace::Large;

void Panel(Rectangle r, float roundness, Color fill, Color border, float thick) {
    DrawRectangleRounded(Rectangle{r.x + 8.0f, r.y + 10.0f, r.width, r.height}, roundness, 16, Color{0, 0, 0, 70});
    DrawRectangleRounded(Expand(r, thick), roundness, 16, border);
    DrawRectangleRounded(r, roundness, 16, fill);
}

std::vector<std::string> SplitUtf8(const char* text) {
    std::vector<std::string> out;
    while (*text != '\0') {
        int bytes = 1;
        GetCodepointNext(text, &bytes);
        if (bytes < 1) bytes = 1;
        out.emplace_back(text, size_t(bytes));
        text += bytes;
    }
    return out;
}

// 名前入力の文字リング（先頭は「もどる」）
const std::vector<std::string>& NameChars(int row) {
    static std::vector<std::vector<std::string>> cache;
    if (cache.empty()) {
        for (const NameRow& r : kNameRows) {
            std::vector<std::string> chars{"もどる"};
            for (std::string& c : SplitUtf8(r.chars)) chars.push_back(std::move(c));
            cache.push_back(std::move(chars));
        }
    }
    return cache[size_t(row)];
}

std::string JoinName(const std::vector<std::string>& chars) {
    std::string out;
    for (const std::string& c : chars) out += c;
    return out;
}

// どんちゃん（1P）／かっちゃん（2P）を描く。gray はクレジット待ちの状態
void DrawDon(Vector2 c, float r, int side, int costume, bool gray, float alpha = 1.0f) {
    DrawDonSprite(c, r, side, costume, gray, alpha);
}

// 変身の煙
void DrawSmoke(Vector2 c, float t, float radius) {
    if (t < 0.0f || t > 1.0f) return;
    const float spread = EaseOutCubic(t);
    const float alpha = 1.0f - t;
    for (int i = 0; i < 8; ++i) {
        const float angle = float(i) * PI / 4.0f + 0.3f;
        const Vector2 p{c.x + std::cos(angle) * radius * (0.3f + 0.8f * spread),
                        c.y + std::sin(angle) * radius * (0.3f + 0.8f * spread)};
        DrawCircleV(p, radius * 0.38f * (1.0f - t * 0.4f), WithAlpha(Color{250, 248, 240, 255}, alpha * 0.9f));
    }
    DrawCircleV(c, radius * 0.7f * (1.0f - t), WithAlpha(Color{250, 248, 240, 255}, alpha));
}

} // namespace

// ===========================================================================
// タイマー
// ===========================================================================
void EntryScene::CountTimer::Update(float dt) {
    if (running) remain = std::max(0.0f, remain - dt);
}

int EntryScene::CountTimer::Count() const {
    return int(std::ceil(remain));
}

// ===========================================================================
// 初期化・終了
// ===========================================================================
void EntryScene::Initialize() {
    PlayDataManager::Get().ResetEntries();

    state_ = State::FadeIn;
    stateTime_ = 0.0f;
    time_ = 0.0f;
    fade_ = 1.0f;

    timer_ = CountTimer();
    timer_.Set(60);

    for (int p = 0; p < 2; ++p) {
        entryWait_[p] = 0.0f;
        donInTime_[p] = 99.0f;
        donJumpTime_[p] = 99.0f;
        smokeTime_[p] = 99.0f;
        setting_[p] = SettingPlayer();
    }
    for (Bubble& bubble : bubbles_) bubble = Bubble();

    menu_ = {GameMode::Enso};
    highlight_ = {false};
    selectIndex_ = 0;
    scrollPos_ = 0.0f;
    settingActive_ = false;
    hasAddCount_ = false;

    GameFont::Get().Preload(kPreloadText);

    const std::vector<Texture2D>& atlas = AssetCache::Get().Nutexb(kEntryAtlasPath);
    atlas_ = atlas.size() > size_t(kAtlasBackground) ? &atlas : nullptr;

    focusVoiceDelay_ = -1.0f;
    for (const char* bank : {kBankBgm, kBankSe, kBankVoice, kBankVoiceEntry}) SoundManager::Get().Preload(bank);

    lastTimerCount_ = -1;
    creditFinishing_ = false;
    // モード選択の「段位道場」の下の年（元のデータは 2020）
    WordList::Get().Set("mode_select_dani_sub", "2026");
    if (!view_.Load()) TraceLog(LOG_WARNING, "EntryScene: Lumen を読み込めないので手描きの見た目で表示します");
    UpdateCreditWords();
}

// クレジット表示の文言（ゲーム本体が埋める部分）
void EntryScene::UpdateCreditWords() {
    const PlayDataManager& pd = PlayDataManager::Get();
    for (int players = 1; players <= 2; ++players) {
        const std::string key = "credit_rest_" + std::to_string(players) + "p";
        const std::string text = pd.IsFreePlay()
                                     ? "フリープレイ"
                                     : TextFormat("クレジット %d/%d", pd.Coins(), pd.GameCost() * players);
        WordList::Get().Set(key, text);
    }
}

// 残り時間の読み上げと「ピ」（lua: Timer:Update の SoundSetting(true, true)）
void EntryScene::UpdateTimerSound() {
    const int count = timer_.Count();
    if (timer_.running && lastTimerCount_ >= 0 && count < lastTimerCount_) {
        if (count == 30) PlayVoice("timer_30sec");
        else if (count == 10) PlayVoice("timer_10sec");
        else if (count == 5) PlayVoice("timer_05sec");
        if (count <= 9) PlaySe("timer_count");
    }
    lastTimerCount_ = count;
}

void EntryScene::Finalize() {
    SoundManager::Get().StopAll();
}

void EntryScene::SetState(State state) {
    state_ = state;
    stateTime_ = 0.0f;
}

void EntryScene::Say(int slot, const char* text) {
    bubbles_[slot].text = text;
    bubbles_[slot].time = 2.2f;
}

// ===========================================================================
// 更新
// ===========================================================================
void EntryScene::Update(float deltaTime) {
    const float dt = deltaTime;
    frameDt_ = dt;
    time_ += dt;
    stateTime_ += dt;

    PlayDataManager& pd = PlayDataManager::Get();

    // 筐体・デバッグ入力
    if (TaikoInput::KeyPressed(KEY_F11)) showKeyGuide_ = !showKeyGuide_;   // F1 はテストスイッチ
    // フリープレイの切り替えはテストモードの設定（FREE PLAY）にも残す。コイン・サービスは main で受け付ける
    if (TaikoInput::IsFreePlayToggled()) GameSettings::Get().SetValue("ItemFreePlay", pd.IsFreePlay() ? 0 : 1);

    timer_.Update(dt);
    for (int p = 0; p < 2; ++p) {
        entryWait_[p] = std::max(0.0f, entryWait_[p] - dt);
        donInTime_[p] += dt;
        donJumpTime_[p] += dt;
        smokeTime_[p] += dt;
        setting_[p].changeTime += dt;
    }
    for (Bubble& bubble : bubbles_) bubble.time = std::max(0.0f, bubble.time - dt);
    scrollPos_ += (float(selectIndex_) - scrollPos_) * std::min(1.0f, dt * 14.0f);

    UpdateTimerSound();
    UpdateCreditWords();

    // カーソル移動後、看板が開いたらモード名のボイスを流す
    if (UseView()) {
        if (view_.ModeConsumeOpened() && state_ == State::ModeSelect) {
            const char* tones[] = {"focus_enso_loop", "focus_danidojo_loop", "focus_ai_loop"};
            SoundManager::Get().PlaySlot(kBankVoiceEntry, tones[int(menu_[size_t(selectIndex_)])], kSlotVoice2);
        }
    } else if (focusVoiceDelay_ >= 0.0f) {
        focusVoiceDelay_ -= dt;
        if (focusVoiceDelay_ < 0.0f && state_ == State::ModeSelect) {
            const char* tones[] = {"focus_enso_loop", "focus_danidojo_loop", "focus_ai_loop"};
            SoundManager::Get().PlaySlot(kBankVoiceEntry, tones[int(menu_[size_t(selectIndex_)])], kSlotVoice2);
        }
    }

    // ESC: 1つ前の画面（アトラクト）へ暗転して戻る
    if (TaikoInput::IsBackPressed() && state_ != State::FadeOutNext && state_ != State::FadeOutAttract && state_ != State::End) {
        SoundManager::Get().Play(kBankSe, "primal_cancel_c");
        SoundManager::Get().SetVolumeSlot(kSlotBgm0, -90.0f, 0.6f);
        SoundManager::Get().SetVolumeSlot(kSlotBgm1, -90.0f, 0.6f);
        SetState(State::FadeOutAttract);
        return;
    }

    switch (state_) {
    case State::FadeIn:
        fade_ = 1.0f - Clamp01(stateTime_ / 0.5f);
        if (stateTime_ >= 0.5f) {
            // BGM「エントリー汎用」。セッティング用の曲も同時に流して音量で切り替える
            SoundManager& sound = SoundManager::Get();
            sound.PlaySlot(kBankBgm, "primal_loop", kSlotBgm0);
            sound.PlaySlot(kBankBgm, "nameentry_loop", kSlotBgm1);
            sound.SetVolumeSlot(kSlotBgm1, -90.0f, 0.0f);
            view_.StartBackground();   // 背景をぼかす
            StartCreditWait();
        }
        break;

    // ---- クレジット受付 ----
    case State::CreditWaitIn:
        if (stateTime_ >= 0.5f) {
            // カードユーザーがいるときだけタイマーを動かす
            if (IsTimerCountInCreditWait()) {
                timer_.shadow = false;
                timer_.Start();
            }
            SetState(State::CreditWait);
        }
        break;
    case State::CreditWait:
        UpdateCreditWait();
        break;
    case State::CreditDecide:
        if (!UseView()) {
            if (stateTime_ >= 0.9f) StartModeSelect();
        } else if (!creditFinishing_) {
            // 決定の演出が終わったら受付ウィンドウを閉じる
            if (!view_.CreditIsDecidePlaying()) {
                view_.CreditFinish();
                creditFinishing_ = true;
            }
        } else if (!view_.CreditIsPlaying()) {
            view_.SetCreditVisible(false);
            creditFinishing_ = false;
            StartModeSelect();
        }
        break;

    // ---- バナパス ----
    case State::CardRead:
        UpdateCardRead(dt);
        break;
    case State::TaikoSelect:
        UpdateTaikoSelect(dt);
        break;

    // ---- モード選択 ----
    case State::ModeSelectIn:
        if (UseView() ? view_.ModeCanInput() : stateTime_ >= 0.8f) {
            Say(kBubbleCenter, "モードをえらんでね！");
            PlayVoiceEntry("mode_choose");
            timer_.shadow = false;
            timer_.Set(60);
            timer_.Start();

            // 2人目の参加受付と操作ガイド
            for (int p = 0; p < 2; ++p) view_.SetCreditSide(p, !pd.Player(p).isUseCredit);
            view_.GuideStart(1);
            if (menu_.size() > 1) view_.GuideChangeMode(0);
            SetState(State::ModeSelect);
        }
        break;
    case State::ModeSelect:
        UpdateModeSelect();
        break;
    case State::ModeSelectChangeList:
        if (UseView()) {
            // 看板の入れ替えは EntryView が行う。入れ替え後の演出が終わるまで待つ
            if (view_.ModeCanInput()) {
                view_.GuideChangeMode(menu_.size() > 1 ? 0 : 1);
                SetState(State::ModeSelect);
            }
            break;
        }
        // 看板が引っ込んだところで中身を入れ替える
        if (!listRebuilt_ && stateTime_ >= 0.35f) {
            RebuildMenu();
            listRebuilt_ = true;
        }
        if (stateTime_ >= 0.95f) SetState(State::ModeSelect);
        break;
    case State::ModeSelectDecide:
        if (!UseView()) {
            if (stateTime_ >= 1.3f) StartSetting();
        } else if (stateTime_ >= 0.5f && !view_.ModeIsPlayBoard()) {
            // 看板をしまってからセッティングへ（lua: ModeSelectFinishActionWait）
            view_.ModeFinish();
            view_.SetGuideVisible(false);
            for (int p = 0; p < 2; ++p) view_.SetCreditSide(p, false);
            StartSetting();
        }
        break;

    // ---- セッティング ----
    case State::SettingIn:
        if (UseView()) {
            UpdateSettingIn();
        } else if (stateTime_ >= 1.2f) {
            timer_.Start();
            SetState(State::Setting);
        }
        break;
    case State::Setting:
        UpdateSetting();
        break;
    case State::ToNextWait:
        if (stateTime_ >= 1.5f) SetState(State::FadeOutNext);
        break;

    // ---- 終了 ----
    case State::FadeOutNext:
        if (stateTime_ == dt) {
            SoundManager::Get().SetVolumeSlot(kSlotBgm0, -90.0f, 0.6f);
            SoundManager::Get().SetVolumeSlot(kSlotBgm1, -90.0f, 0.6f);
        }
        fade_ = Clamp01(stateTime_ / 0.6f);
        if (stateTime_ >= 0.6f) {
            GoNext();
            SetState(State::End);
        }
        break;
    case State::FadeOutAttract:
        // 時間切れ（だれも参加しなかった）ならアトラクトへ戻る
        fade_ = Clamp01(stateTime_ / 0.6f);
        if (stateTime_ >= 0.6f) {
            SceneManager::GetInstance().ChangeScene(std::make_unique<AttractScene>());
            SetState(State::End);
        }
        break;
    case State::End:
        break;
    }

    if (UseView()) {
        view_.SetTimer(timer_.Count(), timer_.shadow);
        if (state_ == State::ModeSelect) {
            view_.GuideUpdate(TaikoInput::AnyDon() || TaikoInput::AnyKaLeft() || TaikoInput::AnyKaRight());
        }
        view_.Update(dt);
    }
}

// ---------------------------------------------------------------------------
// クレジット受付
// ---------------------------------------------------------------------------
void EntryScene::StartCreditWait() {
    timer_.shadow = true;
    timer_.Set(60);
    timer_.Stop();

    startVoice_ = false;
    if (!PlayDataManager::Get().CanPay()) {
        Say(kBubbleCenter, "コインを入れてね！");
        SoundManager::Get().PlaySlot(kBankVoice, "insert_credit_loop", kSlotVoice0);
    }

    view_.CreditStart();
    creditFinishing_ = false;
    SetState(State::CreditWaitIn);
}

void EntryScene::UpdateCreditWait() {
    PlayDataManager& pd = PlayDataManager::Get();

    if (const CardProfile* card = PollCardTouch()) {
        StartCardRead(card, false);
        return;
    }

    if (timer_.running && timer_.IsZero()) {
        SetState(State::FadeOutAttract);
        return;
    }

    // クレジットが成立したら「太鼓をたたいてスタート！」
    if (!startVoice_ && pd.CanPay()) {
        Say(kBubbleCenter, "太鼓をたたいてスタート！");
        SoundManager::Get().PlaySlot(kBankVoice, "entry_1p_primal_loop", kSlotVoice0);
        startVoice_ = true;
    }

    const int side = CheckEntry();
    if (side >= 0) {
        PlaySe("don_big");
        SoundManager::Get().StopSlot(kSlotVoice0);
        view_.CreditDecide(0);   // lua も上の段（1人プレイ）を光らせる
        creditDecideSide_ = side;
        SetState(State::CreditDecide);
    }
}

bool EntryScene::IsTimerCountInCreditWait() const {
    return PlayDataManager::Get().CardEntryUserCount() > 0;
}

// 面をたたいた側をコインでエントリーさせる。エントリーした側を返す
int EntryScene::CheckEntry() {
    PlayDataManager& pd = PlayDataManager::Get();
    for (int p = 0; p < 2; ++p) {
        if (!TaikoInput::IsDon(p)) continue;

        const PlayerData before = pd.Player(p);
        if (!pd.EntryCoin(p)) return -1;
        OnEntrySuccess(p, before);
        return p;
    }
    return -1;
}

void EntryScene::OnEntrySuccess(int player, const PlayerData& before) {
    const PlayerData& now = PlayDataManager::Get().Player(player);

    entryWait_[player] = 1.5f;

    const bool changed = before.userType != UserType::None &&
                         (before.userType != now.userType || before.costume != now.costume);
    if (before.userType == UserType::None) {
        donInTime_[player] = 0.0f;                       // 飛び込んでくる
    } else if (changed) {
        smokeTime_[player] = 0.0f;                       // 見た目が変わる
    } else {
        donJumpTime_[player] = 0.0f;                     // 飛び跳ねる
    }

    // lua: EntryMain:EntrySuccess のどんちゃんの動き
    if (!now.isUseCredit) {
        view_.DonGray(player);
        if (changed) view_.Smoke(player);
    } else if (before.userType == UserType::None) {
        view_.DonFrameIn(player);
    } else if (changed) {
        view_.DonChange(player);
    } else {
        view_.DonJump(player);
    }
    view_.SetNamePlate(0, PlayDataManager::Get().Player(0).userType != UserType::None);
    view_.SetNamePlate(1, PlayDataManager::Get().Player(1).userType != UserType::None);
    if (now.isUseCredit) view_.SetCreditSide(player, false);

    if (now.isUseCredit && !before.isUseCredit) {
        Say(player, "参加だドン！");
        PlayVoice("entry_join" + SideSuffix(player));
    }
}

// カードをタッチした。プレイヤーデータ（Backup/players/<カードID>.json）があればその情報、
// なければはじめてのカードとして、名前入力のあとにプレイヤーデータを登録する
const CardProfile* EntryScene::PollCardTouch() const {
    const char* cardId = TaikoInput::IsCardTouched() ? kDeveloperCardId : TaikoInput::IsNewCardTouched() ? kSecondCardId : nullptr;
    if (!cardId) return nullptr;
    if (!PlayRecords::Get().Card(cardId, touchedCard_)) {
        touchedCard_ = CardProfile{cardId, true, "", "", 0};
        TraceLog(LOG_INFO, "EntryScene: カード %s のプレイヤーデータがないので、はじめてのカードとして登録します", cardId);
    }
    return &touchedCard_;
}

// ---------------------------------------------------------------------------
// バナパス読み込み → 使う太鼓選択
// ---------------------------------------------------------------------------
void EntryScene::StartCardRead(const CardProfile* card, bool fromModeSelect) {
    cardRead_ = CardReadInfo();
    cardRead_.card = card;
    cardFromModeSelect_ = fromModeSelect;
    timer_.Stop();
    SoundManager::Get().StopSlot(kSlotVoice0);
    SoundManager::Get().StopSlot(kSlotVoice2);
    // 読み込み中は受付ウィンドウ・看板を隠す（lua: CreditWait:SetVisible(false) / ModeSelect:Stop）
    view_.SetCreditVisible(false);
    view_.SetModeVisible(false);
    view_.Net().Loading("now_connectserver");
    SetState(State::CardRead);
}

void EntryScene::UpdateCardRead(float dt) {
    cardRead_.time += dt;

    switch (cardRead_.phase) {
    case CardPhase::Connecting:
        if (cardRead_.time >= 1.2f) {
            // 同じカードがエントリー済みならエラー
            cardRead_.phase = PlayDataManager::Get().IsCardEntered(cardRead_.card->cardId)
                                  ? CardPhase::Error
                                  : CardPhase::Success;
            cardRead_.time = 0.0f;
            PlaySe(cardRead_.phase == CardPhase::Success ? "card_success" : "card_error");
            if (cardRead_.phase == CardPhase::Success) view_.Net().Success("connectserver_ok", "connectserver_ok_sub");
            else view_.Net().Error("card_samedata_error", "card_samedata_error_sub");
        }
        break;
    case CardPhase::Success:
        if (cardRead_.time >= 2.0f) {
            view_.Net().Close();
            StartTaikoSelect();
        }
        break;
    case CardPhase::Error:
        if (cardRead_.time >= 2.0f) {
            view_.Net().Close();
            if (cardFromModeSelect_) {
                timer_.Start();
                view_.SetModeVisible(true);
                SetState(State::ModeSelect);
            } else {
                if (IsTimerCountInCreditWait()) {
                    timer_.shadow = false;
                    timer_.Start();
                }
                view_.SetCreditVisible(true);
                SetState(State::CreditWait);
            }
        }
        break;
    }
}

void EntryScene::StartTaikoSelect() {
    const PlayDataManager& pd = PlayDataManager::Get();

    taikoSelect_ = TaikoSelectInfo();
    // カードでエントリー済みの側は選べない
    if (pd.Player(0).userType == UserType::Card) taikoSelect_.minCursor = 1;
    if (pd.Player(1).userType == UserType::Card) taikoSelect_.maxCursor = 1;

    Say(kBubbleCenter, "つかう太鼓をえらんでね！");
    PlayVoice("taiko_choose");

    timer_.shadow = false;
    timer_.Set(20);
    timer_.Start();

    view_.TaikoStart(taikoSelect_.minCursor, taikoSelect_.maxCursor, *cardRead_.card);
    SetState(State::TaikoSelect);
}

void EntryScene::UpdateTaikoSelect(float dt) {
    TaikoSelectInfo& ts = taikoSelect_;

    if (ts.decided) {
        ts.decideTime += dt;
        if (!UseView()) {
            if (ts.decideTime >= 0.7f) CloseTaikoSelect();
        } else if (!ts.finishing) {
            // 決定の点滅が終わったらウィンドウを閉じる（lua: TaikoSelect:Finish → 0.25 秒待ち）
            if (!view_.TaikoIsDecidePlaying()) {
                view_.TaikoFinish();
                ts.finishing = true;
                ts.decideTime = 0.0f;
            }
        } else if (ts.decideTime >= 0.25f) {
            view_.TaikoHide();
            CloseTaikoSelect();
        }
        return;
    }

    bool decide = false;
    if (timer_.IsZero()) {
        ts.cursor = 1;   // 時間切れは「つかわない」
        decide = true;
    } else if (TaikoInput::AnyKaLeft()) {
        if (ts.cursor > ts.minCursor) {
            --ts.cursor;
            PlaySe("katsu_c");
            view_.TaikoCursor(ts.cursor);
        }
    } else if (TaikoInput::AnyKaRight()) {
        if (ts.cursor < ts.maxCursor) {
            ++ts.cursor;
            PlaySe("katsu_c");
            view_.TaikoCursor(ts.cursor);
        }
    } else if (TaikoInput::AnyDon()) {
        decide = true;
    }

    if (decide) {
        PlaySe(ts.cursor == 1 ? "primal_cancel_c" : "don_c");
        view_.TaikoCursor(ts.cursor);
        view_.TaikoDecide(ts.cursor);
        ts.decided = true;
        ts.decideTime = 0.0f;
        timer_.Stop();
    }
}

void EntryScene::CloseTaikoSelect() {
    PlayDataManager& pd = PlayDataManager::Get();
    timer_.Set(60);

    // つかわない
    if (taikoSelect_.cursor == 1) {
        if (cardFromModeSelect_) {
            StartModeSelect();
        } else if (!pd.IsFreePlay() && pd.Coins() == 0 && pd.EntryUserCount() == 0) {
            SetState(State::FadeOutAttract);
        } else {
            StartCreditWait();
        }
        return;
    }

    const int player = taikoSelect_.cursor == 0 ? 0 : 1;
    const PlayerData before = pd.Player(player);
    pd.EntryCard(player, *cardRead_.card);
    OnEntrySuccess(player, before);

    // モード選択から来た or クレジット消費済みの人がいればモード選択へ
    if (cardFromModeSelect_ || pd.Player(0).isUseCredit || pd.Player(1).isUseCredit) {
        StartModeSelect();
    } else {
        StartCreditWait();
    }
}

// ---------------------------------------------------------------------------
// モード選択
// ---------------------------------------------------------------------------
// 看板の構成（lua: ModeSelect:CreateBoardList）
// 段位道場・AIバトルは「カードで1人、クレジット消費済み」のときだけ選べる
std::vector<GameMode> EntryScene::BuildMenu(int* defaultIndex) const {
    const PlayDataManager& pd = PlayDataManager::Get();
    auto isSingleCard = [&](int a, int b) {
        return pd.Player(a).userType == UserType::Card && pd.Player(a).isUseCredit &&
               pd.Player(b).userType == UserType::None;
    };
    const bool single = isSingleCard(0, 1) || isSingleCard(1, 0);

    std::vector<GameMode> menu;
    if (single) menu.push_back(GameMode::AI);
    if (defaultIndex) *defaultIndex = int(menu.size());
    menu.push_back(GameMode::Enso);
    if (single) menu.push_back(GameMode::Dani);
    return menu;
}

void EntryScene::StartModeSelect() {
    RebuildMenu();
    view_.ModeStart(menu_, selectIndex_);
    SetState(State::ModeSelectIn);
}

void EntryScene::RebuildMenu() {
    int defaultIndex = 0;
    std::vector<GameMode> menu = BuildMenu(&defaultIndex);

    // 新しく増えたモードは光らせる
    highlight_.assign(menu.size(), false);
    for (size_t i = 0; i < menu.size(); ++i) {
        highlight_[i] = std::find(menu_.begin(), menu_.end(), menu[i]) == menu_.end();
    }

    menu_ = std::move(menu);
    selectIndex_ = defaultIndex;
    scrollPos_ = float(defaultIndex);
}

void EntryScene::UpdateModeSelect() {
    PlayDataManager& pd = PlayDataManager::Get();

    // カードタッチ（2人ともカードなら受け付けない）
    if (pd.CardEntryUserCount() < 2) {
        if (const CardProfile* card = PollCardTouch()) {
            StartCardRead(card, true);
            return;
        }
    }

    // 途中参加の受付
    const int joined = CheckEntry();
    if (joined >= 0) {
        PlaySe(joined == 0 ? "don_l" : "don_r");
        if (BuildMenu(nullptr) != menu_) {
            SoundManager::Get().StopSlot(kSlotVoice2);
            focusVoiceDelay_ = -1.0f;
            listRebuilt_ = false;
            if (UseView()) {
                RebuildMenu();
                view_.ModeChangeList(menu_, selectIndex_);
            }
            SetState(State::ModeSelectChangeList);
        }
        return;
    }

    // 看板が動いている間は選べない
    if (UseView() && !view_.ModeCanInput()) return;

    if (timer_.IsZero()) {
        DecideMode();
        return;
    }

    for (int p = 0; p < 2; ++p) {
        const bool enable = entryWait_[p] <= 0.0f && pd.Player(p).isUseCredit;
        if (enable && TaikoInput::IsDon(p)) {
            DecideMode();
            return;
        }
    }

    for (int p = 0; p < 2; ++p) {
        if (!pd.Player(p).isUseCredit) continue;
        if (TaikoInput::IsKaLeft(p)) {
            MoveCursor(-1);
            break;
        }
        if (TaikoInput::IsKaRight(p)) {
            MoveCursor(1);
            break;
        }
    }
}

void EntryScene::MoveCursor(int move) {
    const int next = selectIndex_ + move;
    if (next < 0 || next >= int(menu_.size())) return;
    selectIndex_ = next;
    view_.ModeMove(move);

    PlaySe("katsu_c");
    SoundManager::Get().StopSlot(kSlotVoice2);
    focusVoiceDelay_ = 0.3f;
}

void EntryScene::DecideMode() {
    PlayDataManager& pd = PlayDataManager::Get();

    timer_.Stop();
    // エントリー締め切り
    pd.ClearNoCreditEntry();

    decidedMode_ = menu_[size_t(selectIndex_)];
    Say(kBubbleCenter, "決定だドン！");

    // lua の "glad_c" は glad_1_c〜glad_3_c から選ばれる
    PlaySe("don_big");
    PlayVoice(TextFormat("glad_%d_c", GetRandomValue(1, 3)));
    SoundManager::Get().StopSlot(kSlotVoice0);
    SoundManager::Get().StopSlot(kSlotVoice2);
    focusVoiceDelay_ = -1.0f;
    view_.ModeDecide();
    for (int p = 0; p < 2; ++p) {
        const bool entered = pd.Player(p).userType != UserType::None;
        view_.SetNamePlate(p, entered);
        view_.SetCreditSide(p, false);
        if (!entered) {
            bubbles_[p].time = 0.0f;
            view_.SetDonVisible(p, false);
            continue;
        }
        donJumpTime_[p] = 0.0f;
        view_.DonJump(p);
    }
    SetState(State::ModeSelectDecide);
}

// ---------------------------------------------------------------------------
// セッティング（きせかえ / 名前入力）
// ---------------------------------------------------------------------------
void EntryScene::StartSetting() {
    const PlayDataManager& pd = PlayDataManager::Get();

    bool anySetting = false;
    bool hasNameEntry = false;
    for (int p = 0; p < 2; ++p) {
        SettingPlayer& s = setting_[p];
        s = SettingPlayer();

        const PlayerData& player = pd.Player(p);
        s.active = player.userType != UserType::None;
        if (!s.active) continue;

        if (player.userType == UserType::Coin) {
            s.type = SettingType::Costume;       // コインユーザーはきせかえ
            s.costumeCursor = player.costume;
            s.dress = player.dress;
            view_.CostumeSetCustom(p, s.dress);
        } else if (player.isNewData) {
            s.type = SettingType::NameEntry;     // はじめてのカードは名前入力
        }
        s.finished = s.type == SettingType::None;

        anySetting |= s.type != SettingType::None;
        hasNameEntry |= s.type == SettingType::NameEntry;
    }

    // セッティング不要ならそのまま次へ
    if (!anySetting) {
        settingActive_ = false;
        SetState(State::ToNextWait);
        stateTime_ = 0.5f;
        return;
    }

    settingActive_ = true;
    Say(kBubbleCenter, hasNameEntry ? "名前を決めてね！" : "きせかえをえらんでね！");

    // どんちゃんは退場してセッティングの画面に移る。名前入力する人はネームプレートを隠す
    for (int p = 0; p < 2; ++p) {
        if (!setting_[p].active) continue;
        view_.DonOut(p);
        if (setting_[p].type == SettingType::NameEntry) view_.SetNamePlate(p, false);
    }
    PlayVoiceEntry(hasNameEntry ? "name_input" : "costume_choose");

    // BGM をセッティング用に切り替える
    SoundManager::Get().SetVolumeSlot(kSlotBgm0, -90.0f, 0.0f);
    SoundManager::Get().SetVolumeSlot(kSlotBgm1, 0.0f, 0.0f);

    timer_.shadow = false;
    timer_.Set(hasNameEntry ? 100 : 60);
    timer_.Stop();
    hasAddCount_ = hasNameEntry;
    settingPhase_ = 0;
    nameUploading_ = false;

    SetState(State::SettingIn);
}

// セッティング画面の出し方（lua: ToSettingAnimeWait → SettingStart → SettingStartWait → SettingStartWait2）
void EntryScene::UpdateSettingIn() {
    const int count = PlayDataManager::Get().EntryUserCount();

    if (settingPhase_ == 0 && stateTime_ >= 0.75f) {
        view_.SettingShow(true);
        view_.NameEntryShow(true);
        for (int p = 0; p < 2; ++p) {
            const SettingPlayer& s = setting_[p];
            view_.SetDonVisible(p, false);
            view_.NameEntry(p).SetPlayerNum(count);
            if (!s.active) continue;
            if (s.type == SettingType::NameEntry) {
                view_.NameEntry(p).Start();
                view_.SettingStart(p);
            } else if (s.type == SettingType::Costume) {
                view_.CostumeStart(p, s.costumeCursor);
                view_.SettingStart(p);
            } else if (count == 2) {
                view_.SettingStart(p);
            }
        }
        settingPhase_ = 1;
    }
    if (settingPhase_ == 1 && stateTime_ >= 1.25f) {
        for (int p = 0; p < 2; ++p) {
            const SettingPlayer& s = setting_[p];
            if (!s.active) continue;
            if (s.type == SettingType::Costume) {
                view_.CostumeSmoke(p);
                view_.SettingDispDon(p, true);
            } else if (s.type == SettingType::None && count == 2) {
                view_.SettingDispDon(p, true);
                view_.SettingWait(p, false);
            }
        }
        settingPhase_ = 2;
    }
    if (settingPhase_ == 2 && stateTime_ >= 2.25f) {
        timer_.Start();
        for (int p = 0; p < 2; ++p) {
            if (setting_[p].active && setting_[p].type == SettingType::NameEntry) view_.NameEntry(p).StartSelect();
        }
        SetState(State::Setting);
    }
}

void EntryScene::UpdateSetting() {
    if (timer_.IsZero()) {
        if (hasAddCount_) {
            // 名前入力があるときは一度だけ延長する
            timer_.Set(30);
            timer_.Start();
            hasAddCount_ = false;
        } else if (UseView()) {
            // 時間切れ：きせかえは今のカーソルで決定、名前入力は今の名前で登録
            timer_.Stop();
            for (int p = 0; p < 2; ++p) {
                SettingPlayer& s = setting_[p];
                if (!s.active || s.finished) continue;
                if (s.type == SettingType::Costume && s.costumeCursor == kCostumeCustom) {
                    // 「じぶんで」はいま選んでいる着せかえで決める
                    view_.CostumeEditMode(p, false);
                    view_.CostumeClose(p);
                    FinishSetting(p);
                } else if (s.type == SettingType::Costume && !s.deciding) {
                    view_.CostumeDecide(p);
                    s.deciding = true;
                } else if (s.type == SettingType::NameEntry) {
                    view_.NameEntry(p).TimeUp();
                }
            }
        } else {
            PlaySe("don_big");
            for (int p = 0; p < 2; ++p) {
                if (setting_[p].active && !setting_[p].finished) FinishSetting(p);
            }
        }
    }

    for (int p = 0; p < 2; ++p) {
        const SettingPlayer& s = setting_[p];
        if (!s.active || s.finished) continue;
        if (s.type == SettingType::Costume) UpdateCostume(p);
        else if (s.type == SettingType::NameEntry) UpdateNameEntry(p);
    }

    bool allFinished = true;
    for (const SettingPlayer& s : setting_) {
        if (s.active && !s.finished) allFinished = false;
    }
    if (allFinished) {
        timer_.Stop();
        view_.SettingFinishAll();
        SetState(State::ToNextWait);
    }
}

void EntryScene::UpdateCostume(int player) {
    SettingPlayer& s = setting_[player];

    // 決定の点滅が終わったら確定する
    if (s.deciding) {
        if (!view_.CostumeIsDecidePlaying(player)) {
            view_.CostumeClose(player);
            FinishSetting(player);
        }
        return;
    }
    if (s.editing) {
        UpdateCustomCostume(player);
        return;
    }

    int move = 0;
    if (TaikoInput::IsKaLeft(player) && s.costumeCursor > 0) move = -1;
    else if (TaikoInput::IsKaRight(player) && s.costumeCursor < kCostumeCount - 1) move = 1;

    if (move != 0) {
        s.costumeCursor += move;
        s.changeTime = 0.0f;
        PlaySe("katsu" + SideSuffix(player));
        // きせかえの名前を読み上げる（いつもの・じぶんで は無し）
        const char* voices[] = {nullptr, "costume_kakkoii", "costume_kawaii", "costume_omoshiroi", "costume_random", nullptr};
        if (voices[s.costumeCursor]) PlayVoiceEntry(voices[s.costumeCursor] + SideSuffix(player));
        view_.CostumeCursor(player, s.costumeCursor);
        if (UseView()) PlaySe("costume_change" + SideSuffix(player));
    } else if (TaikoInput::IsDon(player) && s.costumeCursor == kCostumeCustom) {
        // 「じぶんで」: 項目ごとに選ぶ板を開く
        PlaySe("don" + SideSuffix(player));
        s.editing = true;
        s.editRow = 0;
        s.changeTime = 0.0f;
        view_.CostumeEditMode(player, true);
    } else if (TaikoInput::IsDon(player)) {
        PlaySe("don" + SideSuffix(player));
        if (UseView()) {
            view_.CostumeDecide(player);
            s.deciding = true;
        } else {
            FinishSetting(player);
        }
    }
}

// 「じぶんで」の編集（本家にはない。すべての着せかえから選ぶ）
//   ふち: 選んでいる項目の中身を前・次へ（「けってい」の行では最初の項目に戻る）  面: 次の項目へ、「けってい」で決める
void EntryScene::UpdateCustomCostume(int player) {
    SettingPlayer& s = setting_[player];
    const bool left = TaikoInput::IsKaLeft(player);
    const bool right = TaikoInput::IsKaRight(player);
    if (left || right) {
        PlaySe("katsu" + SideSuffix(player));
        if (s.editRow == kCustomDecideRow) {
            s.editRow = 0;
        } else {
            DonCatalog::Step(s.dress, DonCatalog::Field(s.editRow), left ? -1 : 1);
            view_.CostumeSetCustom(player, s.dress);
        }
        s.changeTime = 0.0f;
        return;
    }
    if (!TaikoInput::IsDon(player)) return;
    PlaySe("don" + SideSuffix(player));
    if (s.editRow == kCustomDecideRow) {
        view_.CostumeEditMode(player, false);
        view_.CostumeClose(player);
        FinishSetting(player);
        return;
    }
    // きぐるみを着ているときは頭と体を飛ばす
    do {
        ++s.editRow;
    } while (s.editRow < kCustomDecideRow && !DonCatalog::FieldUsed(s.dress, DonCatalog::Field(s.editRow)));
    s.changeTime = 0.0f;
}

void EntryScene::UpdateNameEntry(int player) {
    SettingPlayer& s = setting_[player];
    const bool left = TaikoInput::IsKaLeft(player);
    const bool right = TaikoInput::IsKaRight(player);
    const bool don = TaikoInput::IsDon(player);

    // 元の名前入力（3段のリング）。入力も含めて NameEntryPanel が処理する
    if (UseView()) {
        const NameEntryPanel::Result result = view_.NameEntry(player).Update(frameDt_, left, right, don);
        const bool uploading = result == NameEntryPanel::Result::Upload;
        if (uploading != nameUploading_) {
            // 登録の通信中はタイマーを止める
            if (uploading) timer_.Stop();
            else if (!timer_.IsZero()) timer_.Start();
            nameUploading_ = uploading;
        }
        if (result == NameEntryPanel::Result::Finish) FinishSetting(player);
        return;
    }

    if (left || right) PlaySe("katsu" + SideSuffix(player));
    if (don) {
        const bool cancel = (s.phase == NamePhase::Row && s.rowIndex == kNameRingDelete) ||
                            (s.phase == NamePhase::Char && s.charIndex == 0) ||
                            (s.phase == NamePhase::Accept && s.acceptCursor == 1);
        PlaySe((cancel ? "primal_cancel" : "don") + SideSuffix(player));
    }

    switch (s.phase) {
    case NamePhase::Row:
        if (left) {
            s.rowIndex = (s.rowIndex + kNameRingCount - 1) % kNameRingCount;
        } else if (right) {
            s.rowIndex = (s.rowIndex + 1) % kNameRingCount;
        } else if (don) {
            if (s.rowIndex == kNameRingDelete) {
                if (!s.name.empty()) s.name.pop_back();
            } else if (s.rowIndex == kNameRingEnd) {
                // 空欄のままならデフォルトの名前にする
                if (s.name.empty()) s.name = SplitUtf8(kDefaultCardName);
                s.phase = NamePhase::Accept;
                s.acceptCursor = 0;
            } else {
                s.phase = NamePhase::Char;
                s.charIndex = 1;
            }
            s.changeTime = 0.0f;
        }
        break;

    case NamePhase::Char: {
        const int count = int(NameChars(s.rowIndex).size());
        if (left) {
            s.charIndex = (s.charIndex + count - 1) % count;
        } else if (right) {
            s.charIndex = (s.charIndex + 1) % count;
        } else if (don) {
            if (s.charIndex != 0 && int(s.name.size()) < kNameMax) {
                s.name.push_back(NameChars(s.rowIndex)[size_t(s.charIndex)]);
                if (int(s.name.size()) >= kNameMax) s.rowIndex = kNameRingEnd;
            }
            s.phase = NamePhase::Row;
            s.changeTime = 0.0f;
        }
        break;
    }

    case NamePhase::Accept:
        if (left || right) {
            s.acceptCursor = 1 - s.acceptCursor;
        } else if (don) {
            if (s.acceptCursor == 0) FinishSetting(player);
            else s.phase = NamePhase::Row;
        }
        break;
    }
}

void EntryScene::FinishSetting(int player) {
    SettingPlayer& s = setting_[player];
    PlayerData& data = PlayDataManager::Get().Player(player);

    if (s.type == SettingType::Costume) {
        // おまかせはきぐるみの中から1つ（3D のどんちゃんが読めないときは 2D の組から）
        data.costume = s.costumeCursor;
        // （選んでいるあいだに見せていたきぐるみをそのまま着る）
        data.kigurumi = -1;
        if (s.costumeCursor == kCostumeRandom) {
            data.kigurumi = view_.PreviewKigurumi(player) >= 0 ? view_.PreviewKigurumi(player) : DonModel::RandomKigurumi();
        }
        if (s.costumeCursor == kCostumeRandom && data.kigurumi < 0) data.costume = GetRandomValue(0, kCostumeRandom - 1);
        if (s.costumeCursor == kCostumeCustom) data.dress = s.dress;
        s.editing = false;
    } else if (s.type == SettingType::NameEntry) {
        const std::string name = UseView() ? view_.NameEntry(player).NameText() : JoinName(s.name);
        data.name = name.empty() ? kDefaultCardName : name;
        // はじめてのカード: 決めた名前でプレイヤーデータを登録する（Backup/players/<カードID>.json）
        if (data.userType == UserType::Card && data.isNewData) {
            if (PlayRecords::Get().RegisterCard(data.cardId, data.name)) {
                data.isNewData = false;
                TraceLog(LOG_INFO, "EntryScene: カード %s を「%s」で登録しました", data.cardId.c_str(), data.name.c_str());
            } else {
                TraceLog(LOG_WARNING, "EntryScene: カード %s のプレイヤーデータを登録できません", data.cardId.c_str());
            }
        }
    }

    s.finished = true;
    s.deciding = false;
    smokeTime_[player] = 0.0f;
    view_.SetNamePlate(player, true);
    // 台のどんちゃんを出して「ちょっとまってね」
    view_.SettingDispDon(player, true);
    view_.SettingWait(player, true);

    // もう片方がまだ選んでいるなら「ヨシ！」
    const SettingPlayer& other = setting_[1 - player];
    PlaySe("costume_change" + SideSuffix(player));
    if (other.active && !other.finished) {
        Say(player, "ヨシ！");
        PlayVoice("costume_decide_1" + SideSuffix(player));
    }
}

void EntryScene::GoNext() {
    PlayDataManager& pd = PlayDataManager::Get();

    // 段位道場・AIバトルに行けない組み合わせなら演奏ゲームにする
    GameMode mode = decidedMode_;
    if (mode != GameMode::Enso) {
        const bool ok = pd.EntryUserCount() == 1 && pd.CardEntryUserCount() == 1;
        if (!ok) mode = GameMode::Enso;
    }
    pd.SetDecidedMode(mode);

    if (mode == GameMode::Enso) SceneManager::GetInstance().ChangeScene(std::make_unique<SongSelectScene>());
    else if (mode == GameMode::Dani) SceneManager::GetInstance().ChangeScene(std::make_unique<DaniSelectScene>());
    else SceneManager::GetInstance().ChangeScene(std::make_unique<PlaceholderScene>());
}

// ===========================================================================
// 描画
// ===========================================================================
Vector2 EntryScene::DonPosition(int player) const {
    return Vector2{player == 0 ? 250.0f : kScreenW - 250.0f, 600.0f};
}

float EntryScene::SettingPanelX(int player) const {
    if (PlayDataManager::Get().EntryUserCount() == 1) return kScreenW * 0.5f;
    return player == 0 ? 480.0f : 1440.0f;
}

bool EntryScene::IsSettingVisible() const {
    if (!settingActive_) return false;
    return state_ == State::SettingIn || state_ == State::Setting || state_ == State::ToNextWait ||
           state_ == State::FadeOutNext || state_ == State::End;
}

void EntryScene::Draw() {
    // 元の見た目（Lumen）。クレジット表示とキー操作ガイドだけ手描きで重ねる
    if (UseView()) {
        view_.Draw();
        if (state_ == State::Setting) {
            for (int p = 0; p < 2; ++p) DrawCustomCostume(p);
        }
        DrawGuide();
        DrawKeyGuide();
        if (!showKeyGuide_) Text("F11: キー操作ガイド", 24.0f, 12.0f, 22.0f, kWhite, TextAlign::Left, 3.0f, kInk);
        if (fade_ > 0.0f) DrawRectangle(0, 0, int(kScreenW), int(kScreenH), WithAlpha(BLACK, fade_));
        return;
    }

    DrawBackground();
    DrawHeader();
    DrawTimer();

    switch (state_) {
    case State::CreditWaitIn:
    case State::CreditWait:
    case State::CreditDecide:
        DrawCreditPanel();
        break;
    case State::ModeSelectIn:
    case State::ModeSelect:
    case State::ModeSelectChangeList:
    case State::ModeSelectDecide:
        DrawModeSelect();
        break;
    default:
        break;
    }

    if (IsSettingVisible()) DrawSettingPanels();
    else DrawPlayers();

    if (state_ == State::ModeSelect || state_ == State::ModeSelectChangeList) DrawCreditSide();

    if (state_ == State::CardRead) DrawCardRead();
    if (state_ == State::TaikoSelect) DrawTaikoSelect();

    DrawBubbles();
    DrawGuide();
    DrawKeyGuide();

    if (fade_ > 0.0f) DrawRectangle(0, 0, int(kScreenW), int(kScreenH), WithAlpha(BLACK, fade_));
}

void EntryScene::DrawBackground() const {
    if (atlas_) {
        const Rectangle screen{0.0f, 0.0f, kScreenW, kScreenH};
        DrawTexturePro((*atlas_)[kAtlasSky], kAtlasBackgroundRect, screen, Vector2{0.0f, 0.0f}, 0.0f, WHITE);

        // 最初はくっきり、エントリー開始でぼかし版に切り替える（lua: bg_:GotoAndPlay("start")）
        const float blur = EaseOutCubic((time_ - 0.2f) / 0.5f);
        DrawTexturePro((*atlas_)[kAtlasBackground], kAtlasBackgroundRect, screen, Vector2{0.0f, 0.0f}, 0.0f,
                       WithAlpha(WHITE, 1.0f - blur));
        DrawTexturePro((*atlas_)[kAtlasBackgroundBlur], kAtlasBackgroundRect, screen, Vector2{0.0f, 0.0f}, 0.0f,
                       WithAlpha(WHITE, blur));

        DrawRectangle(0, 0, int(kScreenW), int(kScreenH), Color{0, 0, 0, 40});
        return;
    }

    DrawRectangleGradientV(0, 0, int(kScreenW), int(kScreenH), Color{255, 176, 64, 255}, Color{226, 58, 40, 255});

    // 放射状の光
    const Vector2 center{kScreenW * 0.5f, 600.0f};
    const float rot = time_ * 4.0f;
    for (int i = 0; i < 24; i += 2) {
        const float start = rot + float(i) * 15.0f;
        DrawCircleSector(center, 1600.0f, start, start + 15.0f, 4, Color{255, 255, 255, 26});
    }

    // 青海波
    const Color waveColors[2] = {Color{196, 40, 36, 255}, Color{244, 118, 60, 255}};
    for (int row = 2; row >= 0; --row) {
        const float y = kScreenH + 30.0f - float(row) * 46.0f;
        const float offset = (row % 2) * 70.0f;
        for (float x = -140.0f + offset; x < kScreenW + 140.0f; x += 140.0f) {
            for (int k = 0; k < 4; ++k) {
                DrawCircleSector(Vector2{x, y}, 72.0f - float(k) * 17.0f, 180.0f, 360.0f, 24, waveColors[k % 2]);
            }
        }
    }

    // 背景を少し落として手前を目立たせる
    DrawRectangle(0, 0, int(kScreenW), int(kScreenH), Color{0, 0, 0, 30});
}

void EntryScene::DrawHeader() const {
    const char* title = "エントリー";
    switch (state_) {
    case State::ModeSelectIn:
    case State::ModeSelect:
    case State::ModeSelectChangeList:
    case State::ModeSelectDecide:
        title = "モード選択";
        break;
    case State::SettingIn:
    case State::Setting:
    case State::ToNextWait:
    case State::FadeOutNext:
    case State::End:
        title = "プレイヤー設定";
        break;
    default:
        break;
    }

    DrawRectangleRounded(Rectangle{-60.0f, 26.0f, 600.0f, 92.0f}, 1.0f, 16, kInk);
    DrawRectangleRounded(Rectangle{-60.0f, 32.0f, 592.0f, 80.0f}, 1.0f, 16, kColor1P);
    DrawRectangleRounded(Rectangle{-60.0f, 38.0f, 580.0f, 32.0f}, 1.0f, 16, Color{255, 255, 255, 40});
    Text(title, 50.0f, 42.0f, 58.0f, kWhite, TextAlign::Left, 5.0f, kInk);

    if (!showKeyGuide_) Text("F11: キー操作ガイド", 40.0f, 128.0f, 22.0f, kWhite, TextAlign::Left, 3.0f, kInk);
}

void EntryScene::DrawTimer() const {
    const Vector2 c{1790.0f, 104.0f};
    const float r = 76.0f;
    const float alpha = timer_.shadow ? 0.5f : 1.0f;

    Color face = timer_.shadow ? Color{170, 170, 170, 255} : kGold;
    if (!timer_.shadow && timer_.running && timer_.Count() <= 10 && Blink(time_, 0.5f, 0.25f)) {
        face = Color{255, 110, 70, 255};
    }

    DrawCircleV(Vector2{c.x + 6.0f, c.y + 8.0f}, r + 8.0f, WithAlpha(BLACK, 0.3f * alpha));
    DrawCircleV(c, r + 8.0f, WithAlpha(kInk, alpha));
    DrawCircleV(c, r, WithAlpha(face, alpha));
    DrawRing(c, r - 16.0f, r - 9.0f, 0.0f, 360.0f, 48, WithAlpha(kCream, alpha));

    TextMid(TextFormat("%d", timer_.Count()), c.x, c.y + 4.0f, 84.0f, WithAlpha(kWhite, alpha), 6.0f,
            WithAlpha(kInk, alpha));
    Text("のこり", c.x - r - 24.0f, c.y - 20.0f, 34.0f, WithAlpha(kWhite, alpha), TextAlign::Right, 4.0f,
         WithAlpha(kInk, alpha));
}

void EntryScene::DrawPlayers() const {
    const PlayDataManager& pd = PlayDataManager::Get();

    for (int p = 0; p < 2; ++p) {
        const PlayerData& data = pd.Player(p);
        if (data.userType == UserType::None) continue;

        Vector2 pos = DonPosition(p);
        // 画面外から飛び込んでくる
        const float in = EaseOutBack(donInTime_[p] / 0.6f);
        const float outside = p == 0 ? -220.0f : kScreenW + 220.0f;
        pos.x = outside + (pos.x - outside) * in;
        // 飛び跳ねる
        if (donJumpTime_[p] < 0.6f) pos.y -= std::sin(PI * donJumpTime_[p] / 0.6f) * 90.0f;
        pos.y += std::sin(time_ * 3.0f + float(p)) * 6.0f;

        DrawDon(pos, 130.0f, p, data.costume, !data.isUseCredit);
        DrawSmoke(pos, smokeTime_[p] / 0.6f, 150.0f);

        DrawNamePlate(p, p == 0 ? 40.0f : kScreenW - 40.0f - 540.0f, 850.0f);
    }
}

void EntryScene::DrawNamePlate(int player, float x, float y) const {
    const PlayerData& data = PlayDataManager::Get().Player(player);
    const Rectangle r{x, y, 540.0f, 112.0f};

    Panel(r, 0.35f, kCream, kInk, 5.0f);

    // 1P / 2P バッジ
    DrawRectangleRounded(Rectangle{x + 10.0f, y + 10.0f, 100.0f, 92.0f}, 0.4f, 12, SideColor(player));
    TextMid(player == 0 ? "1P" : "2P", x + 60.0f, y + 58.0f, 50.0f, kWhite, 4.0f);

    // クレジット待ちの間は名前の代わりに案内を出す
    if (!data.isUseCredit) {
        DrawRectangleRounded(Rectangle{x + 120.0f, y + 8.0f, r.width - 128.0f, r.height - 16.0f}, 0.35f, 16,
                             Color{90, 90, 90, 255});
        TextMid("コインを入れてね", x + 120.0f + (r.width - 128.0f) * 0.5f, y + r.height * 0.5f, 40.0f, kWhite, 4.0f);
        return;
    }

    // 称号と名前（長い名前は枠に収まるよう縮める）
    const std::string name = data.name.empty() ? (data.isNewData ? "はじめてのカード" : "") : data.name;
    const float nameMaxWidth = r.width - 130.0f - 136.0f;
    float nameSize = 50.0f;
    const float nameWidth = GameFont::Get().Measure(name.c_str(), nameSize).x;
    if (nameWidth > nameMaxWidth) nameSize *= nameMaxWidth / nameWidth;
    if (!data.title.empty()) {
        Text(data.title.c_str(), x + 130.0f, y + 12.0f, 26.0f, kSubText);
        Text(name.c_str(), x + 130.0f, y + 72.0f - nameSize * 0.5f, nameSize, kInk);
    } else {
        Text(name.c_str(), x + 130.0f, y + 56.0f - nameSize * 0.5f, nameSize, kInk);
    }

    // エントリー種別
    const bool isCard = data.userType == UserType::Card;
    DrawRectangleRounded(Rectangle{x + r.width - 124.0f, y + 12.0f, 108.0f, 34.0f}, 0.5f, 8,
                         isCard ? Color{40, 160, 90, 255} : Color{130, 130, 130, 255});
    TextMid(isCard ? "カード" : "ゲスト", x + r.width - 70.0f, y + 30.0f, 24.0f, kWhite);
}

void EntryScene::DrawCreditPanel() const {
    const PlayDataManager& pd = PlayDataManager::Get();

    float s = 1.0f;
    if (state_ == State::CreditWaitIn) s = EaseOutBack(stateTime_ / 0.5f);
    if (state_ == State::CreditDecide && stateTime_ > 0.5f) s = 1.0f - EaseInQuad((stateTime_ - 0.5f) / 0.4f);
    if (s < 0.05f) return;

    const Vector2 c{kScreenW * 0.5f, 540.0f};
    auto at = [&](float x, float y) { return Vector2{c.x + (x - c.x) * s, c.y + (y - c.y) * s}; };

    const Rectangle r = CenterRect(c.x, c.y, 900.0f * s, 440.0f * s);
    Panel(r, 0.12f, kPanelColor, kInk, 6.0f * s);

    // タイトルリボン
    const Rectangle ribbon = CenterRect(c.x, r.y, 380.0f * s, 78.0f * s);
    DrawRectangleRounded(Expand(ribbon, 5.0f * s), 1.0f, 16, kInk);
    DrawRectangleRounded(ribbon, 1.0f, 16, kColor1P);
    TextMid("参加受付", c.x, r.y + 2.0f * s, 46.0f * s, kWhite, 4.0f * s);

    // メッセージ
    const bool canPay = pd.CanPay();
    const float pulse = 1.0f + 0.04f * std::sin(time_ * 6.0f);
    Vector2 p = at(c.x, 440.0f);
    TextMid(canPay ? "太鼓をたたいてスタート！" : "コインを入れてね！", p.x, p.y, 72.0f * s * pulse,
            canPay ? kColor1P : Color{60, 60, 60, 255}, 7.0f * s, kWhite);

    // 1P / 2P の案内
    for (int side = 0; side < 2; ++side) {
        p = at(side == 0 ? 700.0f : 1220.0f, 545.0f);
        if (state_ == State::CreditDecide && creditDecideSide_ == side && Blink(time_, 0.16f, 0.08f)) {
            DrawRectangleRounded(CenterRect(p.x, p.y, 300.0f * s, 64.0f * s), 1.0f, 16, kGold);
        }
        TextMid(side == 0 ? "◀ 1Pはこちら" : "2Pはこちら ▶", p.x, p.y, 40.0f * s, SideColor(side), 3.0f * s, kWhite);
    }

    // カードの案内
    p = at(608.0f, 630.0f);
    DrawRectangleRounded(Rectangle{p.x, p.y - 24.0f * s, 76.0f * s, 48.0f * s}, 0.3f, 8, kColor2P);
    DrawRectangle(int(p.x), int(p.y - 12.0f * s), int(76.0f * s), int(8.0f * s), kInk);
    p = at(700.0f, 630.0f);
    Text("バナパスポートカードをタッチしてね", p.x, p.y - 18.0f * s, 36.0f * s, kInk);

    // クレジット
    p = at(c.x, 700.0f);
    const char* credit = pd.IsFreePlay()
                             ? "フリープレイ"
                             : TextFormat("クレジット %d　（1プレイ %dクレジット）", pd.Coins(), pd.GameCost());
    TextMid(credit, p.x, p.y, 30.0f * s, kSubText, 0.0f, kInk, kCreditFace);
}

void EntryScene::DrawModeSelect() const {
    float yOffset = 0.0f;
    switch (state_) {
    case State::ModeSelectIn:
        yOffset = (1.0f - EaseOutBack(stateTime_ / 0.6f)) * 800.0f;
        break;
    case State::ModeSelectChangeList:
        yOffset = stateTime_ < 0.35f ? EaseInQuad(stateTime_ / 0.35f) * 800.0f
                                     : (1.0f - EaseOutBack((stateTime_ - 0.35f) / 0.6f)) * 800.0f;
        break;
    case State::ModeSelectDecide:
        if (stateTime_ > 0.8f) yOffset = EaseInQuad((stateTime_ - 0.8f) / 0.5f) * 900.0f;
        break;
    default:
        break;
    }

    // 奥の看板から描く
    std::vector<int> order(menu_.size());
    std::iota(order.begin(), order.end(), 0);
    std::sort(order.begin(), order.end(), [&](int a, int b) {
        return std::fabs(float(a) - scrollPos_) > std::fabs(float(b) - scrollPos_);
    });

    for (int i : order) {
        const float offset = float(i) - scrollPos_;
        const float away = std::min(1.0f, std::fabs(offset));
        const float scale = 1.0f - 0.28f * away;
        DrawModeBoard(i, kScreenW * 0.5f + offset * 470.0f, 520.0f + yOffset + away * 30.0f, scale,
                      i == selectIndex_, away);
    }

    // 左右の矢印
    if (state_ == State::ModeSelect) {
        const float bounce = std::sin(time_ * 8.0f) * 8.0f;
        if (selectIndex_ > 0) TextMid("◀", kScreenW * 0.5f - 316.0f - bounce, 520.0f, 64.0f, kGold, 5.0f);
        if (selectIndex_ < int(menu_.size()) - 1) {
            TextMid("▶", kScreenW * 0.5f + 316.0f + bounce, 520.0f, 64.0f, kGold, 5.0f);
        }
    }
}

void EntryScene::DrawModeBoard(int index, float cx, float cy, float scale, bool isCenter, float dim) const {
    const GameMode mode = menu_[size_t(index)];
    const ModeInfo& info = GetModeInfo(mode);
    const bool decided = state_ == State::ModeSelectDecide && isCenter;

    float sc = scale;
    if (decided) sc *= 1.0f + 0.06f * std::sin(stateTime_ * 18.0f) * std::max(0.0f, 1.0f - stateTime_);

    const float w = 560.0f * sc;
    const float h = 600.0f * sc;
    const Rectangle r = CenterRect(cx, cy, w, h);

    const Color border = decided && Blink(time_, 0.12f, 0.06f) ? kGold : kInk;
    Panel(r, 0.10f, info.bottom, border, 8.0f * sc);

    // 見出し
    DrawRectangleRounded(Rectangle{r.x, r.y, w, 150.0f * sc}, 0.3f, 16, info.top);
    TextMid(info.title, cx, r.y + 78.0f * sc, 64.0f * sc, kWhite, 6.0f * sc);

    // イラスト
    const float iy = r.y + 330.0f * sc;
    switch (mode) {
    case GameMode::Enso:
        DrawDon(Vector2{cx - 110.0f * sc, iy}, 80.0f * sc, 0, 0, false);
        DrawDon(Vector2{cx + 110.0f * sc, iy}, 80.0f * sc, 1, 0, false);
        break;
    case GameMode::Dani:
        DrawCircleV(Vector2{cx, iy}, 130.0f * sc, kInk);
        DrawCircleV(Vector2{cx, iy}, 122.0f * sc, kGold);
        DrawRing(Vector2{cx, iy}, 100.0f * sc, 108.0f * sc, 0.0f, 360.0f, 48, Color{200, 140, 20, 255});
        TextMid("段", cx, iy + 4.0f * sc, 140.0f * sc, kInk);
        break;
    case GameMode::AI:
        DrawDon(Vector2{cx - 120.0f * sc, iy}, 80.0f * sc, 0, 0, false);
        TextMid("VS", cx, iy, 48.0f * sc, kGold, 4.0f * sc);
        DrawCircleV(Vector2{cx + 120.0f * sc, iy}, 88.0f * sc, kInk);
        DrawCircleV(Vector2{cx + 120.0f * sc, iy}, 80.0f * sc, Color{90, 200, 230, 255});
        TextMid("AI", cx + 120.0f * sc, iy + 2.0f * sc, 72.0f * sc, kWhite, 5.0f * sc);
        break;
    }

    // 説明
    const Rectangle cr{r.x + 24.0f * sc, r.y + h - 120.0f * sc, w - 48.0f * sc, 96.0f * sc};
    DrawRectangleRounded(cr, 0.4f, 12, WithAlpha(kCream, 0.95f));
    TextMid(info.comment, cx, cr.y + cr.height * 0.5f, 28.0f * sc, kInk);

    if (info.singleOnly) {
        const Rectangle badge{r.x + w - 170.0f * sc, r.y + 164.0f * sc, 150.0f * sc, 50.0f * sc};
        DrawRectangleRounded(badge, 0.5f, 12, Color{255, 90, 120, 255});
        TextMid("1人専用", badge.x + badge.width * 0.5f, badge.y + badge.height * 0.5f, 30.0f * sc, kWhite, 3.0f * sc);
    }

    // 新しく増えたモード
    if (size_t(index) < highlight_.size() && highlight_[size_t(index)] && Blink(time_, 0.8f, 0.5f)) {
        const Rectangle badge{r.x - 12.0f * sc, r.y - 26.0f * sc, 150.0f * sc, 58.0f * sc};
        DrawRectangleRounded(Expand(badge, 4.0f * sc), 0.5f, 12, kInk);
        DrawRectangleRounded(badge, 0.5f, 12, kGold);
        TextMid("NEW!", badge.x + badge.width * 0.5f, badge.y + badge.height * 0.5f, 40.0f * sc, kColor1P);
    }

    if (dim > 0.0f) DrawRectangleRounded(r, 0.10f, 16, WithAlpha(BLACK, 0.4f * dim));
}

// 2人目の参加受付（lua: CreditSide）
void EntryScene::DrawCreditSide() const {
    const PlayDataManager& pd = PlayDataManager::Get();

    for (int p = 0; p < 2; ++p) {
        if (pd.Player(p).isUseCredit) continue;

        const float x = DonPosition(p).x;
        const Rectangle r = CenterRect(x, 330.0f, 420.0f, 200.0f);
        Panel(r, 0.2f, WithAlpha(kCream, 0.96f), SideColor(p), 6.0f);

        TextMid("2人目の参加受付中", x, r.y + 42.0f, 34.0f, SideColor(p));
        const float pulse = 1.0f + 0.05f * std::sin(time_ * 6.0f);
        TextMid(pd.CanPay() ? "太鼓をたたいて参加！" : "コインを入れてね！", x, r.y + 102.0f, 38.0f * pulse, kInk);
        TextMid(pd.IsFreePlay() ? "フリープレイ" : TextFormat("クレジット %d", pd.Coins()), x, r.y + 160.0f, 28.0f,
                kSubText, 0.0f, kInk, kCreditFace);
    }
}

void EntryScene::DrawSettingPanels() const {
    float yOffset = 0.0f;
    if (state_ == State::SettingIn) yOffset = (1.0f - EaseOutBack(stateTime_ / 0.5f)) * 900.0f;

    for (int p = 0; p < 2; ++p) {
        const SettingPlayer& s = setting_[p];
        if (!s.active) continue;

        const Rectangle r = CenterRect(SettingPanelX(p), 545.0f + yOffset, 860.0f, 680.0f);
        if (!s.finished && s.type == SettingType::Costume) DrawCostumePanel(p, r);
        else if (!s.finished && s.type == SettingType::NameEntry) DrawNameEntryPanel(p, r);
        else DrawWaitPanel(p, r);
    }
}

// 「じぶんで」のアイコン（きせかえのアイコンの列の6つ目）と、編集中の項目の板
void EntryScene::DrawCustomCostume(int player) const {
    const SettingPlayer& s = setting_[player];
    if (!s.active || s.finished || s.type != SettingType::Costume || s.deciding) return;
    const float left = kCostumeBoardLeft[player];

    if (!s.editing) {
        const bool selected = s.costumeCursor == kCostumeCustom;
        const Rectangle icon{left + kCustomIconX - kCustomIconSize * 0.5f, kCustomIconY - kCustomIconSize * 0.5f, kCustomIconSize,
                             kCustomIconSize};
        if (selected) {
            DrawRectangleRounded(Rectangle{icon.x - 8.0f, icon.y - 8.0f, icon.width + 16.0f, icon.height + 16.0f}, 0.3f, 8, kGold);
        }
        DrawRectangleRounded(Rectangle{icon.x - 3.0f, icon.y - 3.0f, icon.width + 6.0f, icon.height + 6.0f}, 0.3f, 8, kInk);
        DrawRectangleRounded(icon, 0.3f, 8, Color{150, 90, 220, 255});
        TextMid("じぶん", icon.x + icon.width * 0.5f, icon.y + 30.0f, 22.0f, kWhite, 3.0f);
        TextMid("で", icon.x + icon.width * 0.5f, icon.y + 58.0f, 22.0f, kWhite, 3.0f);
        return;
    }

    const Rectangle panel{left + kCustomPanel.x, kCustomPanel.y, kCustomPanel.width, kCustomPanel.height};
    DrawRectangleRounded(Rectangle{panel.x - 4.0f, panel.y - 4.0f, panel.width + 8.0f, panel.height + 8.0f}, 0.12f, 8, kInk);
    DrawRectangleRounded(panel, 0.12f, 8, kCream);
    constexpr float kRowHeight = 54.0f;
    constexpr float kColumnWidth = 390.0f;
    constexpr float kValueWidth = 222.0f;
    for (int row = 0; row <= kCustomDecideRow; ++row) {
        const int column = row < 4 ? 0 : 1;
        const float x = panel.x + 14.0f + float(column) * (kColumnWidth + 6.0f);
        const float y = panel.y + 12.0f + float(row % 4) * kRowHeight;
        const bool selected = row == s.editRow;
        const Rectangle cell{x, y, kColumnWidth, kRowHeight - 8.0f};
        if (selected) DrawRectangleRounded(cell, 0.35f, 8, kGold);
        if (row == kCustomDecideRow) {
            TextMid("けってい", cell.x + cell.width * 0.5f, cell.y + cell.height * 0.5f, 28.0f, selected ? kInk : kSubText);
            continue;
        }
        const DonCatalog::Field field = DonCatalog::Field(row);
        const bool used = DonCatalog::FieldUsed(s.dress, field);
        const Color ink = used ? kInk : Color{kInk.r, kInk.g, kInk.b, 90};
        Text(DonCatalog::FieldName(field), cell.x + 12.0f, cell.y + 12.0f, 22.0f, used ? kSubText : ink);
        // 中身の名前（長いものは縮める）。色は見本も出す
        const std::string value = DonCatalog::ValueText(s.dress, field);
        float valueX = cell.x + cell.width - kValueWidth - 8.0f;
        if (field == DonCatalog::Field::FaceColor || field == DonCatalog::Field::BodyColor || field == DonCatalog::Field::LegsColor) {
            unsigned char r = 255, g = 255, b = 255;
            const int color = field == DonCatalog::Field::FaceColor ? s.dress.faceColor
                              : field == DonCatalog::Field::BodyColor ? s.dress.bodyColor
                                                                      : s.dress.legsColor;
            DonCatalog::ColorRgb(color, r, g, b);
            DrawRectangle(int(valueX), int(cell.y + 10.0f), 26, 26, kInk);
            DrawRectangle(int(valueX) + 2, int(cell.y + 12.0f), 22, 22, color < 0 ? kCream : Color{r, g, b, 255});
            valueX += 32.0f;
        }
        const float width = cell.x + cell.width - 8.0f - valueX - (selected ? 24.0f : 0.0f);
        float size = 24.0f;
        const float measured = GameFont::Get().Measure(value.c_str(), size).x;
        if (measured > width) size *= width / measured;
        Text(value.c_str(), valueX + (selected ? 12.0f : 0.0f), cell.y + cell.height * 0.5f - size * 0.5f, size, ink);
        if (selected) {
            Text("◀", valueX - 16.0f, cell.y + 12.0f, 20.0f, kColor1P);
            Text("▶", cell.x + cell.width - 24.0f, cell.y + 12.0f, 20.0f, kColor1P);
        }
    }
}

void EntryScene::DrawCostumePanel(int player, Rectangle r) const {
    const SettingPlayer& s = setting_[player];
    const float cx = r.x + r.width * 0.5f;

    Panel(r, 0.08f, kPanelColor, SideColor(player), 8.0f);
    DrawRectangleRounded(Rectangle{r.x + 24.0f, r.y - 30.0f, 110.0f, 60.0f}, 0.5f, 12, SideColor(player));
    TextMid(player == 0 ? "1P" : "2P", r.x + 79.0f, r.y, 40.0f, kWhite, 3.0f);
    TextMid("きせかえをえらんでね", cx, r.y + 64.0f, 48.0f, kInk);

    // プレビュー
    const Vector2 dc{cx, r.y + 290.0f};
    const float pop = 1.0f + 0.08f * std::max(0.0f, 1.0f - s.changeTime / 0.2f);
    const int preview = s.costumeCursor == kCostumeRandom ? int(time_ * 6.0f) % kCostumeRandom : s.costumeCursor;
    DrawDon(dc, 130.0f * pop, player, preview, false);
    if (s.costumeCursor == kCostumeRandom) TextMid("？", dc.x + 150.0f, dc.y - 130.0f, 96.0f, kGold, 6.0f);
    DrawSmoke(dc, s.changeTime / 0.4f, 130.0f);

    // 選択肢
    for (int i = 0; i < kCostumeCount; ++i) {
        const float ix = cx + float(i - 2) * 156.0f;
        const Rectangle ir = CenterRect(ix, r.y + 570.0f, 140.0f, 150.0f);
        const bool selected = i == s.costumeCursor;

        DrawRectangleRounded(Expand(ir, selected ? 6.0f : 3.0f), 0.2f, 12, selected ? kGold : kInk);
        DrawRectangleRounded(ir, 0.2f, 12, selected ? Color{255, 240, 190, 255} : Color{235, 225, 205, 255});
        if (i < kCostumeRandom) DrawDon(Vector2{ix, ir.y + 56.0f}, 38.0f, player, i, false);
        else TextMid("？", ix, ir.y + 58.0f, 64.0f, SideColor(player), 4.0f, kWhite);
        TextMid(kCostumeNames[i], ix, ir.y + 124.0f, 26.0f, kInk);
    }
}

void EntryScene::DrawNameEntryPanel(int player, Rectangle r) const {
    const SettingPlayer& s = setting_[player];
    const float cx = r.x + r.width * 0.5f;
    const Color side = SideColor(player);

    Panel(r, 0.08f, kPanelColor, side, 8.0f);
    DrawRectangleRounded(Rectangle{r.x + 24.0f, r.y - 30.0f, 110.0f, 60.0f}, 0.5f, 12, side);
    TextMid(player == 0 ? "1P" : "2P", r.x + 79.0f, r.y, 40.0f, kWhite, 3.0f);
    TextMid("なまえを入力してね", cx, r.y + 64.0f, 48.0f, kInk);

    // 名前のプレート
    for (int i = 0; i < kNameMax; ++i) {
        const float bx = cx + float(i - 2) * 120.0f;
        const Rectangle br = CenterRect(bx, r.y + 190.0f, 104.0f, 110.0f);
        const bool cursor = i == int(s.name.size()) && s.phase != NamePhase::Accept;

        DrawRectangleRounded(Expand(br, cursor ? 6.0f : 3.0f), 0.2f, 10, cursor && Blink(time_, 0.6f, 0.3f) ? kGold : kInk);
        DrawRectangleRounded(br, 0.2f, 10, kWhite);
        if (i < int(s.name.size())) TextMid(s.name[size_t(i)].c_str(), bx, br.y + br.height * 0.5f, 72.0f, kInk);
    }

    if (s.phase == NamePhase::Accept) {
        TextMid("この名前でいいですか？", cx, r.y + 340.0f, 46.0f, kInk);
        const char* labels[2] = {"はい", "いいえ"};
        for (int i = 0; i < 2; ++i) {
            const float bx = cx + (i == 0 ? -170.0f : 170.0f);
            const Rectangle br = CenterRect(bx, r.y + 480.0f, 240.0f, 110.0f);
            const bool selected = s.acceptCursor == i;
            DrawRectangleRounded(Expand(br, selected ? 8.0f : 4.0f), 0.4f, 12, selected ? kGold : kInk);
            DrawRectangleRounded(br, 0.4f, 12, selected ? side : Color{160, 150, 140, 255});
            TextMid(labels[i], bx, br.y + br.height * 0.5f, 52.0f, kWhite, 4.0f);
        }
        return;
    }

    // 横に回るリング
    const bool rowPhase = s.phase == NamePhase::Row;
    TextMid(rowPhase ? "文字の種類をえらぶ" : "文字をえらぶ", cx, r.y + 300.0f, 32.0f, kSubText);

    const int count = rowPhase ? kNameRingCount : int(NameChars(s.rowIndex).size());
    const int current = rowPhase ? s.rowIndex : s.charIndex;
    const int visible = std::min(3, (count - 1) / 2);
    for (int k = -visible; k <= visible; ++k) {
        const int index = ((current + k) % count + count) % count;
        const bool center = k == 0;
        const float size = center ? 124.0f : 96.0f;
        const Rectangle ir = CenterRect(cx + float(k) * 114.0f, r.y + 430.0f, size, size);

        const char* label = nullptr;
        Color fill = Color{245, 235, 215, 255};
        float fontSize = 56.0f;
        if (rowPhase) {
            fontSize = 34.0f;
            if (index == kNameRingDelete) {
                label = "けす";
                fill = Color{200, 200, 200, 255};
            } else if (index == kNameRingEnd) {
                label = "おわり";
                fill = Color{130, 210, 140, 255};
            } else {
                label = kNameRows[index].label;
            }
        } else {
            label = NameChars(s.rowIndex)[size_t(index)].c_str();
            if (index == 0) {
                fill = Color{200, 200, 200, 255};
                fontSize = 30.0f;
            }
        }
        if (center) fill = side;

        DrawRectangleRounded(Expand(ir, center ? 6.0f : 3.0f), 0.25f, 12, center ? kGold : kInk);
        DrawRectangleRounded(ir, 0.25f, 12, fill);
        TextMid(label, ir.x + ir.width * 0.5f, ir.y + ir.height * 0.5f, center ? fontSize * 1.15f : fontSize,
                center ? kWhite : kInk, center ? 4.0f : 0.0f);
    }

    const float bounce = std::sin(time_ * 8.0f) * 6.0f;
    TextMid("▼", cx, r.y + 340.0f + bounce, 34.0f, kGold, 4.0f);
}

void EntryScene::DrawWaitPanel(int player, Rectangle r) const {
    const PlayerData& data = PlayDataManager::Get().Player(player);
    const float cx = r.x + r.width * 0.5f;

    Panel(r, 0.08f, WithAlpha(kPanelColor, 0.92f), SideColor(player), 8.0f);
    DrawRectangleRounded(Rectangle{r.x + 24.0f, r.y - 30.0f, 110.0f, 60.0f}, 0.5f, 12, SideColor(player));
    TextMid(player == 0 ? "1P" : "2P", r.x + 79.0f, r.y, 40.0f, kWhite, 3.0f);

    Vector2 dc{cx, r.y + 280.0f};
    dc.y += std::sin(time_ * 3.0f + float(player)) * 8.0f;
    DrawDon(dc, 150.0f, player, data.costume, false);
    DrawSmoke(dc, smokeTime_[player] / 0.6f, 170.0f);

    if (!data.title.empty()) TextMid(data.title.c_str(), cx, r.y + 490.0f, 28.0f, kSubText);
    TextMid(data.name.c_str(), cx, r.y + 540.0f, 56.0f, SideColor(player), 4.0f, kWhite);
    if (Blink(time_, 1.2f, 0.9f)) TextMid("ちょっと待ってね", cx, r.y + 620.0f, 40.0f, kInk);
}

void EntryScene::DrawCardRead() const {
    DrawRectangle(0, 0, int(kScreenW), int(kScreenH), Color{0, 0, 0, 115});

    const Rectangle r = CenterRect(kScreenW * 0.5f, 540.0f, 980.0f, 260.0f);
    Panel(r, 0.2f, kPanelColor, kInk, 6.0f);
    const Vector2 icon{r.x + 120.0f, r.y + r.height * 0.5f};
    const float textX = r.x + 210.0f;

    switch (cardRead_.phase) {
    case CardPhase::Connecting: {
        const float angle = time_ * 360.0f;
        DrawRing(icon, 36.0f, 50.0f, angle, angle + 270.0f, 32, kColor2P);
        const int dots = int(time_ * 3.0f) % 4;
        const std::string text = std::string("サーバーに接続しています") + std::string(size_t(dots), '.');
        Text(text.c_str(), textX, icon.y - 24.0f, 44.0f, kInk);
        break;
    }
    case CardPhase::Success:
        DrawCircleV(icon, 54.0f, Color{40, 170, 90, 255});
        TextMid("OK", icon.x, icon.y + 2.0f, 44.0f, kWhite);
        Text("読み込みに成功しました", textX, icon.y - 52.0f, 46.0f, Color{30, 130, 70, 255});
        Text("バナパスポートを確認しました", textX, icon.y + 12.0f, 32.0f, kSubText);
        break;
    case CardPhase::Error:
        DrawCircleV(icon, 54.0f, Color{210, 50, 50, 255});
        TextMid("×", icon.x, icon.y + 2.0f, 64.0f, kWhite);
        Text("このデータはすでに読み込んでいます", textX, icon.y - 52.0f, 42.0f, Color{190, 40, 40, 255});
        Text("別のカードをタッチしてね", textX, icon.y + 12.0f, 32.0f, kSubText);
        break;
    }
}

void EntryScene::DrawTaikoSelect() const {
    const TaikoSelectInfo& ts = taikoSelect_;
    const CardProfile& card = *cardRead_.card;
    const float cx = kScreenW * 0.5f;

    DrawRectangle(0, 0, int(kScreenW), int(kScreenH), Color{0, 0, 0, 140});

    const Rectangle r = CenterRect(cx, 540.0f, 1240.0f, 700.0f);
    Panel(r, 0.08f, kPanelColor, kInk, 8.0f);
    TextMid("どちらの太鼓でプレイしますか？", cx, r.y + 72.0f, 56.0f, kInk);

    // 読み込んだカードの情報
    const Rectangle ir = CenterRect(cx, r.y + 250.0f, 760.0f, 190.0f);
    DrawRectangleRounded(ir, 0.2f, 12, Color{245, 232, 205, 255});
    DrawDon(Vector2{ir.x + 110.0f, ir.y + 92.0f}, 66.0f, 0, card.costume, false);
    if (card.isNew) {
        Text("はじめてのカードです", ir.x + 220.0f, ir.y + 40.0f, 44.0f, kColor1P);
        Text("このあと名前を登録してね", ir.x + 220.0f, ir.y + 106.0f, 32.0f, kInk);
    } else {
        Text(card.title.c_str(), ir.x + 220.0f, ir.y + 36.0f, 30.0f, kSubText);
        Text(card.name.c_str(), ir.x + 220.0f, ir.y + 82.0f, 62.0f, kInk);
    }

    // 選択肢
    const char* labels[3] = {"左の太鼓", "つかわない", "右の太鼓"};
    const Color colors[3] = {kColor1P, Color{150, 140, 130, 255}, kColor2P};
    for (int i = 0; i < 3; ++i) {
        if (i < ts.minCursor || i > ts.maxCursor) continue;

        const float x = cx + float(i - 1) * 380.0f;
        const Rectangle br = CenterRect(x, r.y + 545.0f, 330.0f, 130.0f);
        const bool selected = ts.cursor == i;
        const bool flash = ts.decided && selected && Blink(ts.decideTime, 0.1f, 0.05f);

        DrawRectangleRounded(Expand(br, selected ? 10.0f : 4.0f), 0.3f, 12, selected ? kGold : kInk);
        DrawRectangleRounded(br, 0.3f, 12, flash ? kWhite : colors[i]);
        TextMid(labels[i], x, br.y + br.height * 0.5f, 46.0f, kWhite, 5.0f);

        if (selected && !ts.decided) {
            const float bounce = std::fabs(std::sin(time_ * 6.0f)) * 12.0f;
            TextMid("▼", x, br.y - 36.0f - bounce, 42.0f, kGold, 4.0f);
        }
    }
}

void EntryScene::DrawBubbles() const {
    for (int i = 0; i < 3; ++i) {
        const Bubble& bubble = bubbles_[i];
        if (bubble.time <= 0.0f || bubble.text.empty()) continue;

        // 中央はヘッダーの高さに出して、パネルの見出しと重ならないようにする
        Vector2 pos{kScreenW * 0.5f, 72.0f};
        if (i != kBubbleCenter) {
            pos = IsSettingVisible() ? Vector2{SettingPanelX(i), 72.0f}
                                     : Vector2{DonPosition(i).x, DonPosition(i).y - 250.0f};
        }

        const float age = 2.2f - bubble.time;
        const float s = EaseOutBack(age / 0.25f);
        const float alpha = Clamp01(bubble.time / 0.3f);
        const Vector2 size = GameFont::Get().Measure(bubble.text.c_str(), 40.0f);
        const float w = (size.x + 64.0f) * s;
        const float h = 78.0f * s;
        const Rectangle r = CenterRect(pos.x, pos.y, w, h);

        DrawRectanglePro(Rectangle{pos.x, pos.y + h * 0.5f, 30.0f * s, 30.0f * s}, Vector2{15.0f * s, 15.0f * s},
                         45.0f, WithAlpha(kInk, alpha));
        DrawRectangleRounded(Expand(r, 5.0f * s), 1.0f, 16, WithAlpha(kInk, alpha));
        DrawRectanglePro(Rectangle{pos.x, pos.y + h * 0.5f - 3.0f * s, 22.0f * s, 22.0f * s},
                         Vector2{11.0f * s, 11.0f * s}, 45.0f, WithAlpha(kWhite, alpha));
        DrawRectangleRounded(r, 1.0f, 16, WithAlpha(kWhite, alpha));
        TextMid(bubble.text.c_str(), pos.x, pos.y, 40.0f * s, WithAlpha(kInk, alpha));
    }
}

void EntryScene::DrawGuide() const {
    const PlayDataManager& pd = PlayDataManager::Get();

    // Lumen の操作ガイドがある画面では出さない
    const bool showGuide = !UseView() && (state_ == State::TaikoSelect || state_ == State::Setting ||
                                          state_ == State::ModeSelect);
    if (showGuide) {
        const float y = 1000.0f;
        const float cx = kScreenW * 0.5f;
        DrawRectangleRounded(CenterRect(cx, y, 840.0f, 60.0f), 1.0f, 16, Color{0, 0, 0, 130});

        DrawRing(Vector2{cx - 380.0f, y}, 14.0f, 22.0f, 0.0f, 360.0f, 32, Color{90, 190, 255, 255});
        Text("ふちをたたいて えらぶ", cx - 346.0f, y - 17.0f, 34.0f, kWhite);
        DrawCircleV(Vector2{cx + 50.0f, y}, 22.0f, kColor1P);
        DrawCircleV(Vector2{cx + 50.0f, y}, 14.0f, Color{255, 140, 110, 255});
        Text("面をたたいて けってい", cx + 84.0f, y - 17.0f, 34.0f, kWhite);
    }

    const char* credit = pd.IsFreePlay() ? "フリープレイ" : TextFormat("クレジット %d", pd.Coins());
    TextMid(credit, kScreenW * 0.5f, 1054.0f, 30.0f, kWhite, 3.0f, kInk, kCreditFace);
}

void EntryScene::DrawKeyGuide() const {
    if (!showKeyGuide_) return;

    // 今の割り当て（テストモードの KEY CONFIG で変えられる）から作る
    using TaikoInput::Action;
    auto keys = [](Action action) {
        std::string s = TaikoInput::KeyName(TaikoInput::BoundKey(action, 0));
        const int second = TaikoInput::BoundKey(action, 1);
        if (second != 0) s += "/" + TaikoInput::KeyName(second);
        return s;
    };
    auto drum = [&](int player) {
        return std::string(player == 0 ? "1P: " : "2P: ") + "ふち(左)=" + keys(TaikoInput::PadAction(player, TaikoInput::Pad::LeftKa)) +
               "  面(左)=" + keys(TaikoInput::PadAction(player, TaikoInput::Pad::LeftDon)) +
               "  面(右)=" + keys(TaikoInput::PadAction(player, TaikoInput::Pad::RightDon)) +
               "  ふち(右)=" + keys(TaikoInput::PadAction(player, TaikoInput::Pad::RightKa));
    };
    const std::string text[] = {
        "キー操作ガイド（F11で閉じる。テストモードの KEY CONFIG で変更）",
        drum(0),
        drum(1),
        keys(Action::FreePlay) + ": フリープレイ切替   " + keys(Action::Coin) + ": コイン投入",
        keys(Action::Card) + ": カードタッチ（登録済み）   " + keys(Action::NewCard) + ": カードタッチ（新規）",
        keys(Action::Test) + ": テストモード   " + keys(Action::Service) + ": サービス",
    };
    const int count = int(sizeof(text) / sizeof(text[0]));
    const char* lines[count];
    for (int i = 0; i < count; ++i) lines[i] = text[i].c_str();
    float width = 1000.0f;
    for (int i = 1; i < count; ++i) width = std::max(width, GameFont::Get().Measure(lines[i], 26.0f).x + 60.0f);
    const Rectangle r{30.0f, 130.0f, width, 60.0f + 40.0f * float(count)};
    DrawRectangleRounded(r, 0.1f, 12, Color{0, 0, 0, 190});
    for (int i = 0; i < count; ++i) {
        Text(lines[i], r.x + 24.0f, r.y + 18.0f + float(i) * 40.0f, i == 0 ? 30.0f : 26.0f, i == 0 ? kGold : kWhite);
    }
}