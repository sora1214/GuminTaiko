#pragma once
#include <string>
#include <vector>

#include "DonModel.hpp"
#include "EntryNameEntry.hpp"
#include "LumenPlayer.hpp"
#include "PlayData.hpp"
#include "raylib.h"

// エントリー画面の見た目（lumen/000_default/entry/entry と、そこへ LoadMovie する部品）
// lua の EntryMain から呼ばれている各モジュール（ModeSelect / CreditWait / Timer / NamePlate /
// CreditSide / ControlGuide / WaitDon）の見た目の操作を移植したもの。進行の判断は EntryScene が行う。
class EntryView {
public:
    EntryView() = default;
    ~EntryView();
    EntryView(const EntryView&) = delete;
    EntryView& operator=(const EntryView&) = delete;

    bool Load();
    bool IsLoaded() const { return loaded_; }

    void Update(float deltaTime);
    void Draw();

    // ---- 背景 ----
    void StartBackground();

    // ---- どんちゃん（3D の代わりに 2D のどんちゃんを描いて差し込む） ----
    void SetDonVisible(int player, bool visible);
    void DonFrameIn(int player);        // 飛び込んでくる
    void DonJump(int player);           // 飛んで回る
    void DonChange(int player);         // 定位置に置いて煙を出す（見た目が変わる）
    void DonGray(int player);           // クレジット待ち
    void DonOut(int player);            // 退場
    void Smoke(int player);

    // ---- ネームプレート ----
    void SetNamePlate(int player, bool visible);

    // ---- タイマー ----
    void SetTimer(int count, bool shadow);

    // ---- クレジット受付 ----
    void CreditStart();
    void CreditDecide(int row);
    void CreditFinish();
    bool CreditIsPlaying() const;
    bool CreditIsDecidePlaying() const;
    void SetCreditVisible(bool visible);

    // ---- 2人目参加受付 ----
    void SetCreditSide(int player, bool visible);

    // ---- 操作ガイド ----
    void GuideStart(int mode);          // 0: えらぶ+決定 1: 決定のみ
    void GuideChangeMode(int mode);
    void GuideUpdate(bool input);
    void GuideOut();
    void GuideIn();
    void SetGuideVisible(bool visible);

    // ---- モード選択（lua: ModeSelect / ModeSelectBorad） ----
    void ModeStart(const std::vector<GuminTaiko::GameMode>& menu, int selectIndex);
    void ModeChangeList(const std::vector<GuminTaiko::GameMode>& menu, int selectIndex);
    void ModeMove(int move);
    void ModeDecide();
    void ModeFinish();
    void SetModeVisible(bool visible);
    bool ModeCanInput() const { return modeState_ == ModeState::Main; }
    bool ModeIsReady() const { return modeState_ == ModeState::Main || modeState_ == ModeState::Decide; }
    bool ModeIsPlayBoard() const;
    // カーソル移動後に看板が開ききったら true を一度だけ返す（モード名のボイス用）
    bool ModeConsumeOpened();
    int ModeSelectIndex() const { return modeSelect_; }

    // ---- 通信中ウィンドウ ----
    NetWindow& Net() { return net_; }

    // ---- 使う太鼓の選択（lua: TaikoSelect）。cursor は 0:左 1:つかわない 2:右 ----
    void TaikoStart(int minCursor, int maxCursor, const GuminTaiko::CardProfile& card);
    void TaikoCursor(int cursor);
    void TaikoDecide(int cursor);
    bool TaikoIsDecidePlaying() const;
    void TaikoFinish();
    void TaikoHide();

    // ---- セッティング（lua: SettingBase / CostumeSelect / NameEntry） ----
    void SettingShow(bool visible);
    void SettingStart(int player);                 // 台を出す
    void SettingDispDon(int player, bool visible);
    void SettingWait(int player, bool decided);    // ちょっと待ってね
    void SettingFinishAll();
    void CostumeStart(int player, int cursor);
    void CostumeSmoke(int player);
    void CostumeCursor(int player, int cursor);
    void CostumeDecide(int player);
    bool CostumeIsDecidePlaying(int player) const;
    void CostumeClose(int player);
    // 「じぶんで」: 選んでいる着せかえ（どんちゃんに着せて見せる）と、編集中はアイコンの列と操作ガイドを隠す
    void CostumeSetCustom(int player, const DonCostume& dress) { customDress_[player] = dress; }
    void CostumeEditMode(int player, bool editing);
    NameEntryPanel& NameEntry(int player) { return nameEntry_[player]; }
    void NameEntryShow(bool visible);

    // 差し込むどんちゃんのきせかえを一時的に変える（-1 でプレイデータどおり）
    void SetDonCostume(int player, int costume) { donCostume_[player] = costume; }
    int PreviewKigurumi(int player) const { return previewKigurumi_[player]; }

private:
    enum class ModeState { Idle, StartWait, HighLight, StartWaitCount, Main, MenuMove, BoardOpenWait, Decide, ChangeList };

    Lumen::MovieClip* Clip(const std::string& path);
    void UpdateMode(float dt);
    void SetAllBoards();
    void ChangeBoardDisplay(int kanban, GuminTaiko::GameMode mode);
    Lumen::MovieClip* Board(int kanban);
    void RenderDons();

    bool loaded_ = false;
    Lumen::Stage stage_;

    Lumen::MovieClip* background_ = nullptr;
    Lumen::MovieClip* don_[2] = {};
    Lumen::MovieClip* smoke_[2] = {};
    Lumen::MovieClip* namePlate_[2] = {};
    Lumen::MovieClip* creditSide_[2] = {};
    Lumen::MovieClip* creditRoot_ = nullptr;
    Lumen::MovieClip* credit_ = nullptr;
    Lumen::MovieClip* creditText_[2] = {};
    bool creditDecided_[2] = {};
    Lumen::MovieClip* timerCounter_ = nullptr;
    Lumen::MovieClip* guide_ = nullptr;
    Lumen::MovieClip* modeRoot_ = nullptr;
    Lumen::MovieClip* modeList_ = nullptr;
    Lumen::MovieClip* kanban_[8] = {};

    DonModel don3d_;                    // 3D のどんちゃん（読めなければ 2D で描く）
    int previewKigurumi_[2] = {-1, -1}; // きせかえ選択で「おまかせ」にいるあいだ見せるきぐるみ
    RenderTexture2D donTexture_[2] = {};
    bool donVisible_[2] = {};
    int donCostume_[2] = {-1, -1};
    DonCostume customDress_[2];         // きせかえ選択の「じぶんで」で選んでいる着せかえ

    NetWindow net_;
    Lumen::MovieClip* taikoRoot_ = nullptr;
    Lumen::MovieClip* taikoMain_ = nullptr;
    Lumen::MovieClip* taikoBlink_ = nullptr;
    Lumen::MovieClip* settingRoot_ = nullptr;
    Lumen::MovieClip* settingBase_[2] = {};
    Lumen::MovieClip* settingBoard_[2] = {};
    Lumen::MovieClip* costumeRoot_ = nullptr;
    Lumen::MovieClip* costume_[2] = {};
    Lumen::MovieClip* costumeBoard_[2] = {};
    Lumen::MovieClip* nameEntryRoot_ = nullptr;
    NameEntryPanel nameEntry_[2];
    float costumeSmoke_[2] = {-1.0f, -1.0f};
    int costumeDecided_[2] = {};

    void CostumeUpdateIcon(int player, int cursor);

    int timerCount_ = -1;
    bool guideCenter_ = false;
    float guideIdle_ = 0.0f;

    ModeState modeState_ = ModeState::Idle;
    std::vector<GuminTaiko::GameMode> modeMenu_;
    std::vector<GuminTaiko::GameMode> modeNextMenu_;
    std::vector<int> modeHighlight_;
    int modeSelect_ = 0;
    int modeNextSelect_ = 0;
    float modeWait_ = 0.0f;
    float modeStop_ = 0.0f;
    bool modeOpened_ = false;
};
