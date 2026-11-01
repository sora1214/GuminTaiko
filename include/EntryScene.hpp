#pragma once
#include <string>
#include <vector>
#include "EntryView.hpp"
#include "PlayData.hpp"
#include "Scene.hpp"
#include "raylib.h"

// エントリー画面
// Data/x64/lua/entry/entry_main.lua のステートマシンを移植したもの。
//   クレジット受付 → (バナパス読み込み → 使う太鼓選択) → モード選択（2人目の途中参加あり）
//   → セッティング（コイン: きせかえ選択 / 新規カード: 名前入力） → 次の画面へ
class EntryScene : public Scene {
public:
    void Initialize() override;
    void Update(float deltaTime) override;
    void Draw() override;
    void Finalize() override;

private:
    enum class State {
        FadeIn,
        CreditWaitIn, CreditWait, CreditDecide,
        CardRead, TaikoSelect,
        ModeSelectIn, ModeSelect, ModeSelectChangeList, ModeSelectDecide,
        SettingIn, Setting, ToNextWait,
        FadeOutNext, FadeOutAttract, End,
    };

    // 残り時間タイマー（lua: common.Timer）
    struct CountTimer {
        float remain = 60.0f;
        bool running = false;
        bool shadow = true;   // 止まっている間は暗く表示する

        void Set(int seconds) { remain = float(seconds); }
        void Start() { running = true; }
        void Stop() { running = false; }
        void Update(float dt);
        int Count() const;
        bool IsZero() const { return remain <= 0.0f; }
    };

    // バナパス読み込み（lua: CardLoad + NetAccessWindow）
    enum class CardPhase { Connecting, Success, Error };
    struct CardReadInfo {
        CardPhase phase = CardPhase::Connecting;
        float time = 0.0f;
        const GuminTaiko::CardProfile* card = nullptr;
    };

    // 使う太鼓選択（lua: TaikoSelect） 0:左 1:つかわない 2:右
    struct TaikoSelectInfo {
        int cursor = 1;
        int minCursor = 0;
        int maxCursor = 2;
        bool decided = false;
        bool finishing = false;
        float decideTime = 0.0f;
    };

    // セッティング（lua: CostumeSelect / NameEntry）
    enum class SettingType { None, Costume, NameEntry };
    enum class NamePhase { Row, Char, Accept };
    struct SettingPlayer {
        bool active = false;
        SettingType type = SettingType::None;
        bool finished = true;
        bool deciding = false;     // 決定の演出中（元の見た目のとき）
        float changeTime = 99.0f;
        // きせかえ
        int costumeCursor = 0;
        bool editing = false;      // 「じぶんで」の編集中
        int editRow = 0;           // 編集中の項目（DonCatalog::Field の番号。最後の1つ先が「けってい」）
        DonCostume dress;          // 「じぶんで」で選んでいる着せかえ
        // 名前入力
        NamePhase phase = NamePhase::Row;
        int rowIndex = 0;
        int charIndex = 1;
        int acceptCursor = 0;
        std::vector<std::string> name;
    };

    // ボイスの代わりに出す吹き出し
    static constexpr int kBubbleCenter = 2;
    struct Bubble {
        std::string text;
        float time = 0.0f;
    };

    // ---- 進行 ----
    void SetState(State state);
    void Say(int slot, const char* text);

    void StartCreditWait();
    void UpdateCreditWait();
    bool IsTimerCountInCreditWait() const;
    int CheckEntry();
    void OnEntrySuccess(int player, const GuminTaiko::PlayerData& before);
    const GuminTaiko::CardProfile* PollCardTouch() const;
    mutable GuminTaiko::CardProfile touchedCard_;   // タッチしたカードの情報（プレイヤーデータから読んだもの）

    void StartCardRead(const GuminTaiko::CardProfile* card, bool fromModeSelect);
    void UpdateCardRead(float dt);
    void StartTaikoSelect();
    void UpdateTaikoSelect(float dt);
    void CloseTaikoSelect();

    std::vector<GuminTaiko::GameMode> BuildMenu(int* defaultIndex) const;
    void StartModeSelect();
    void RebuildMenu();
    void UpdateModeSelect();
    void MoveCursor(int move);
    void DecideMode();

    void StartSetting();
    void UpdateSetting();
    void UpdateCostume(int player);
    void UpdateNameEntry(int player);
    void FinishSetting(int player);

    void GoNext();

    // ---- 描画 ----
    Vector2 DonPosition(int player) const;
    float SettingPanelX(int player) const;
    bool IsSettingVisible() const;

    void DrawBackground() const;
    void DrawHeader() const;
    void DrawTimer() const;
    void DrawPlayers() const;
    void DrawNamePlate(int player, float x, float y) const;
    void DrawCreditPanel() const;
    void DrawModeSelect() const;
    void DrawModeBoard(int index, float cx, float cy, float scale, bool isCenter, float dim) const;
    void DrawCreditSide() const;
    void DrawSettingPanels() const;
    void DrawCostumePanel(int player, Rectangle rect) const;
    // きせかえの6つ目「じぶんで」のアイコンと、編集中の項目の板（元の見た目の上に描く）
    void DrawCustomCostume(int player) const;
    void UpdateCustomCostume(int player);
    void DrawNameEntryPanel(int player, Rectangle rect) const;
    void DrawWaitPanel(int player, Rectangle rect) const;
    void DrawCardRead() const;
    void DrawTaikoSelect() const;
    void DrawBubbles() const;
    void DrawGuide() const;
    void DrawKeyGuide() const;

    // 元の見た目（Lumen）。読み込めなかったときは手描きの見た目にする
    EntryView view_;
    bool UseView() const { return view_.IsLoaded(); }
    void UpdateTimerSound();
    void UpdateCreditWords();
    int lastTimerCount_ = -1;
    bool creditFinishing_ = false;
    float frameDt_ = 0.0f;
    int settingPhase_ = 0;
    bool nameUploading_ = false;
    void UpdateSettingIn();

    // 背景（lumen/000_default/entry/entry.nutexb のアトラス。手描きの見た目のときに使う）
    const std::vector<Texture2D>* atlas_ = nullptr;

    State state_ = State::FadeIn;
    float stateTime_ = 0.0f;
    float time_ = 0.0f;
    float fade_ = 1.0f;
    CountTimer timer_;
    bool startVoice_ = false;
    bool showKeyGuide_ = false;

    float entryWait_[2] = {};     // エントリー直後は決定できない
    float donInTime_[2] = {};     // 飛び込んでくる演出
    float donJumpTime_[2] = {};   // 飛び跳ねる演出
    float smokeTime_[2] = {};     // 変身の煙
    int creditDecideSide_ = 0;

    CardReadInfo cardRead_;
    bool cardFromModeSelect_ = false;
    TaikoSelectInfo taikoSelect_;

    std::vector<GuminTaiko::GameMode> menu_;
    std::vector<bool> highlight_;
    int selectIndex_ = 0;
    float scrollPos_ = 0.0f;
    bool listRebuilt_ = false;
    float focusVoiceDelay_ = -1.0f;
    GuminTaiko::GameMode decidedMode_ = GuminTaiko::GameMode::Enso;

    SettingPlayer setting_[2];
    bool hasAddCount_ = false;
    bool settingActive_ = false;

    Bubble bubbles_[3];
};
