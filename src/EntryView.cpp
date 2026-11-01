#include "EntryView.hpp"

#include <algorithm>
#include <cmath>

#include "CommonParts.hpp"
#include "DonSprite.hpp"
#include "raymath.h"
#include "WordList.hpp"

using namespace GuminTaiko;

namespace {

constexpr const char* kEntryMovie = "lumen/000_default/entry/entry";

// モード選択の看板（上から順。lua: ModeSelect.mc_name_list_）
const char* const kKanbanNames[8] = {"kanban_8", "kanban_6", "kanban_4", "kanban_2",
                                      "kanban_1", "kanban_3", "kanban_5", "kanban_7"};
constexpr int kCenterKanban = 4;
constexpr const char* kModeList = "mode_select_instance/mode_select_list_instance";
constexpr float kModeTitleOffsetY = 18.0f;   // モード選択の板のモード名を下げる量（板の座標）

// タイマーの数字が赤く点滅し始める値（lua: timer_:Setup(9)）
constexpr int kTimerRedLimit = 9;

// 差し込み枠に描くどんちゃん
constexpr int kDonTextureWidth = 1920;
constexpr int kDonTextureHeight = 1080;
constexpr float kDonRadius = 170.0f;

const char* ModeLabel(GameMode mode) {
    switch (mode) {
    case GameMode::Dani: return "dani";
    case GameMode::AI: return "ai";
    default: return "enso";
    }
}

void Goto(Lumen::MovieClip* clip, const char* label, bool play) {
    if (!clip) return;
    if (play) clip->GotoAndPlay(label);
    else clip->GotoAndStop(label);
}

} // namespace

EntryView::~EntryView() {
    for (RenderTexture2D& texture : donTexture_) {
        if (texture.id != 0) UnloadRenderTexture(texture);
    }
    don3d_.Unload();
    Lumen::ClearExternalTextures();
}

Lumen::MovieClip* EntryView::Clip(const std::string& path) {
    Lumen::MovieClip* clip = stage_.GetMovieClip(path);
    if (!clip) TraceLog(LOG_WARNING, "EntryView: %s が見つかりません", path.c_str());
    return clip;
}

bool EntryView::Load() {
    if (!stage_.Load(kEntryMovie)) return false;
    // ---- 部品の読み込み（lua: EntryMain の "Begin"） ----
    stage_.LoadMovie("lumen/000_default/common/timer", "timer_instance");
    stage_.LoadMovie("lumen/000_default/common/control_guide", "controlguide_instance");
    stage_.LoadMovie("lumen/000_default/common/name_plate", "nameplate_instance_1");
    stage_.LoadMovie("lumen/000_default/common/name_plate", "nameplate_instance_2");
    stage_.LoadMovie("lumen/000_default/common/credit_player_side", "credit_side_instance_1");
    stage_.LoadMovie("lumen/000_default/common/credit_player_side", "credit_side_instance_2");
    stage_.LoadMovie("lumen/000_default/entry/entry_credit", "entrycredit_instance");
    for (const char* name : kKanbanNames) {
        stage_.LoadMovie("lumen/000_default/entry/mode_select", std::string(kModeList) + "/" + name);
    }
    stage_.LoadMovie("lumen/000_default/entry/banapass_entry", "taiko_select_instance");
    stage_.LoadMovie("lumen/000_default/common/name_plate", "taiko_select_instance/main_instance/info_instance/nameplate_instance");
    stage_.LoadMovie("lumen/000_default/entry/setting_base", "setting_base_instance");
    stage_.LoadMovie("lumen/000_default/entry/costume", "cosutume_select_instance");
    stage_.LoadMovie("lumen/000_default/entry/name_entry", "nameentry_instance");
    stage_.LoadMovie("lumen/000_default/common/banapass_load", "banapassload_instance");

    // ---- 背景・どんちゃん ----
    don3d_.Load();
    background_ = Clip("entrybg_instance");
    don_[0] = Clip("don_1p");
    don_[1] = Clip("don_2p");
    for (int p = 0; p < 2; ++p) {
        if (don_[p]) don_[p]->SetVisible(false);
        smoke_[p] = Clip("donsmoke_instance/smoke_instance_" + std::to_string(p + 1));
        donTexture_[p] = LoadRenderTexture(kDonTextureWidth, kDonTextureHeight);
        SetTextureFilter(donTexture_[p].texture, TEXTURE_FILTER_BILINEAR);
        Lumen::SetExternalTexture(p == 0 ? "don1p" : "don2p", &donTexture_[p].texture, true);
    }
    // 待ちどんちゃんは使わない（lua: WaitDon:Setup）
    if (Lumen::MovieClip* wait = Clip("donwait_instance")) {
        for (const char* name : {"wait_instance_1", "wait_instance_2"}) {
            if (Lumen::MovieClip* child = wait->Child(name)) child->SetVisible(false);
        }
    }

    // ---- タイマー ----
    timerCounter_ = Clip("timer_instance/timer_main_instance/time_count_instance");

    // ---- 操作ガイド ----
    guide_ = Clip("controlguide_instance");
    if (guide_) {
        if (Lumen::MovieClip* main = guide_->Child("main")) {
            if (Lumen::MovieClip* small = main->Child("taiko_small")) {
                if (Lumen::MovieClip* all = small->Child("all")) all->SetText("guide_text_instance", "text_guide", "decide");
                if (Lumen::MovieClip* decide = small->Child("decide")) decide->SetText("guide_text_instance", "text_guide", "decide");
            }
            if (Lumen::MovieClip* large = main->Child("taiko_large")) {
                if (Lumen::MovieClip* decide = large->Child("decide")) decide->SetText("guide_text_instance", "text_guide", "decide");
            }
        }
        guide_->SetVisible(false);
    }

    // ---- ネームプレート・2人目受付 ----
    // クレジットの文字（「フリープレイ」「クレジット n」）は、選曲画面のジャンルの看板と同じフォントにする（色と縁取りは元のまま）
    Lumen::MovieClip::TextStyle creditStyle;
    creditStyle.face = FontFace::Large;
    creditStyle.colors = false;
    for (int p = 0; p < 2; ++p) {
        namePlate_[p] = Clip("nameplate_instance_" + std::to_string(p + 1));
        if (namePlate_[p]) namePlate_[p]->SetVisible(false);

        creditSide_[p] = Clip("credit_side_instance_" + std::to_string(p + 1));
        if (creditSide_[p]) {
            if (Lumen::MovieClip* all = creditSide_[p]->Find("attract_credit_instance/credit_all_instance")) {
                all->SetText("text_player_instance", "text_player", "credit_play_2p");
                all->SetText("text_credit_instance", "text_credit", "credit_rest_2p");
                if (Lumen::MovieClip* text = all->Child("text_credit_instance")) text->SetTextStyle("text_credit", creditStyle);
            }
            creditSide_[p]->SetVisible(false);
        }
    }

    // ---- クレジット受付 ----
    creditRoot_ = Clip("entrycredit_instance");
    credit_ = creditRoot_ ? creditRoot_->Child("credit_instance") : nullptr;
    if (credit_) {
        credit_->SetText("player1_text_instance", "text_player", "credit_play_1p");
        credit_->SetText("player2_text_instance", "text_player", "credit_play_2p");
        creditText_[0] = credit_->Child("player1_text_instance");
        creditText_[1] = credit_->Child("player2_text_instance");
        for (int i = 0; i < 2; ++i) {
            if (!creditText_[i]) continue;
            const char* key = i == 0 ? "credit_rest_1p" : "credit_rest_2p";
            creditText_[i]->SetText("text_message_instance", "text_credit", key);
            creditText_[i]->SetText("text_message_instance_2", "text_credit", key);
            for (const char* name : {"text_message_instance", "text_message_instance_2"}) {
                if (Lumen::MovieClip* text = creditText_[i]->Child(name)) text->SetTextStyle("text_credit", creditStyle);
            }
        }
    }
    if (creditRoot_) creditRoot_->SetVisible(false);

    // ---- モード選択 ----
    modeRoot_ = Clip("mode_select_instance");
    modeList_ = Clip(kModeList);
    for (int i = 0; i < 8; ++i) kanban_[i] = modeList_ ? modeList_->Child(kKanbanNames[i]) : nullptr;
    if (modeRoot_) modeRoot_->SetVisible(false);
    modeMenu_ = {GameMode::Enso};

    // ---- 通信中ウィンドウ ----
    net_.Setup(Clip("banapassload_instance"));

    // ---- 使う太鼓の選択（lua: TaikoSelect:Setup） ----
    taikoRoot_ = Clip("taiko_select_instance");
    taikoMain_ = taikoRoot_ ? taikoRoot_->Child("main_instance") : nullptr;
    if (taikoMain_) {
        taikoMain_->SetText("text_message", "whitch_taiko");
        taikoMain_->SetText("p1_instance", "text_message", "left");
        taikoMain_->SetText("p2_instance", "text_message", "right");
        taikoMain_->SetText("nouse_instance", "text_message", "no_use_taiko");
        if (Lumen::MovieClip* info = taikoMain_->Child("info_instance")) {
            info->SetText("new_msg_instance", "text_message", "new_card_warning");
        }
        if (Lumen::MovieClip* guide = taikoMain_->Child("guide_instance")) {
            if (Lumen::MovieClip* s = guide->Child("select_instance")) s->SetText("text_guide_instance", "text_guide", "select");
            if (Lumen::MovieClip* d = guide->Child("decide_instance")) d->SetText("text_guide_instance", "text_guide", "decide");
        }
    }
    if (taikoRoot_) taikoRoot_->SetVisible(false);

    // ---- セッティングの台（lua: SettingBase:Setup） ----
    settingRoot_ = Clip("setting_base_instance");
    for (int p = 0; p < 2; ++p) {
        const std::string side = std::to_string(p + 1);
        settingBase_[p] = settingRoot_ ? settingRoot_->Child("settingbase_" + side + "p_instance") : nullptr;
        if (settingBase_[p]) settingBase_[p]->Stop();
        settingBoard_[p] = settingBase_[p] ? settingBase_[p]->Child("board_instance") : nullptr;
        if (!settingBoard_[p]) continue;
        settingBoard_[p]->Stop();
        if (Lumen::MovieClip* don = settingBoard_[p]->Child("don" + side + "p")) {
            don->Stop();
            don->SetVisible(false);
        }
        if (Lumen::MovieClip* message = settingBoard_[p]->Child("message_instance")) {
            message->SetText("text_message_instance", "text_message", "wait_a_minutes");
            message->Stop();
        }
    }
    if (settingRoot_) settingRoot_->SetVisible(false);

    // ---- きせかえ（lua: CostumeSelectOnePlayer:Setup） ----
    costumeRoot_ = Clip("cosutume_select_instance");
    for (int p = 0; p < 2; ++p) {
        costume_[p] = costumeRoot_ ? costumeRoot_->Child("costume_" + std::to_string(p + 1) + "p_instance") : nullptr;
        if (costume_[p]) costume_[p]->Stop();
        costumeBoard_[p] = costume_[p] ? costume_[p]->Child("board_instance") : nullptr;
        if (Lumen::MovieClip* board = costumeBoard_[p]) {
            board->Stop();
            board->SetText("text_title", "costume_select");
            Goto(board->Child("smoke_instance"), "smoke_in", false);
            if (Lumen::MovieClip* select = board->Child("select_instance")) {
                for (const char* arrow : {"arrow_l_instance", "arrow_r_instance"}) {
                    if (Lumen::MovieClip* a = select->Child(arrow)) {
                        a->GotoAndPlay("arrow_on");
                        a->SetVisible(false);
                    }
                }
            }
            if (Lumen::MovieClip* guide = board->Child("guide_instance")) {
                if (Lumen::MovieClip* s = guide->Child("select_instance")) s->SetText("text_guide_instance", "text_guide", "select");
                if (Lumen::MovieClip* d = guide->Child("decide_instance")) d->SetText("text_guide_instance", "text_guide", "decide");
            }
        }
    }
    if (costumeRoot_) costumeRoot_->SetVisible(false);

    // ---- 名前入力（lua: NameEntry:Setup） ----
    nameEntryRoot_ = Clip("nameentry_instance");
    for (int p = 0; p < 2; ++p) {
        const std::string side = std::to_string(p + 1);
        nameEntry_[p].Setup(nameEntryRoot_ ? nameEntryRoot_->Child("nameentry_" + side + "p_instance") : nullptr,
                            nameEntryRoot_ ? nameEntryRoot_->Child("guide_instance_" + side) : nullptr, p, &net_);
    }
    if (nameEntryRoot_) nameEntryRoot_->SetVisible(false);

    loaded_ = background_ != nullptr;
    return loaded_;
}

void EntryView::Update(float deltaTime) {
    if (!loaded_) return;
    stage_.Update(deltaTime);
    UpdateMode(deltaTime);
    guideIdle_ += deltaTime;

    // きせかえの煙は、着替えが終わったら消す（lua: Don.IsLoadedDon を待って smoke_out）
    for (int p = 0; p < 2; ++p) {
        if (costumeSmoke_[p] < 0.0f) continue;
        costumeSmoke_[p] -= deltaTime;
        if (costumeSmoke_[p] < 0.0f && costumeBoard_[p]) Goto(costumeBoard_[p]->Child("smoke_instance"), "smoke_out", true);
    }
}

void EntryView::Draw() {
    if (!loaded_) return;
    RenderDons();
    stage_.Draw();
}

void EntryView::RenderDons() {
    const PlayDataManager& pd = PlayDataManager::Get();
    // 3D のどんちゃんを写すカメラ（描画先の中央に、2D のときと同じくらいの大きさで写る）
    // 平行投影なので遠近感は付かない。fovy は写る範囲の高さ（ワールド座標）で、
    // 以前の透視投影（画角 22°・距離 1.7）で注視点の位置に写っていた高さ 2 × 1.7 × tan(11°) に合わせる
    Camera3D camera{};
    camera.target = Vector3{0.0f, 0.14f, 0.0f};
    camera.position = Vector3{0.0f, 0.2f, 1.7f};   // 少し上から見下ろす向きだけに意味がある
    camera.up = Vector3{0.0f, 1.0f, 0.0f};
    camera.fovy = 2.0f * 1.7f * std::tan(11.0f * DEG2RAD);
    camera.projection = CAMERA_ORTHOGRAPHIC;
    // 待機のアニメーション（lua: Don.SetLoopAnimation(…, "select_loop")）。1P と 2P は同じ姿勢
    if (don3d_.IsLoaded()) don3d_.PlayLoop("don_select_loop", float(GetTime()));

    // 太鼓選択やセッティングの枠にも使うので、表示状態に関係なく毎フレーム描く
    for (int p = 0; p < 2; ++p) {
        if (donTexture_[p].id == 0) continue;
        BeginTextureMode(donTexture_[p]);
        ClearBackground(Color{0, 0, 0, 0});
        if (don3d_.IsLoaded()) {
            // きせかえ: 選んでいる最中はカーソルの組（おまかせは選んだ時に決めたきぐるみ）、決まったらプレイヤーの組
            const PlayerData& data = pd.Player(p);
            if (donCostume_[p] >= 0) {
                if (donCostume_[p] == DonModel::kCostumeRandom && previewKigurumi_[p] < 0) previewKigurumi_[p] = DonModel::RandomKigurumi();
                if (donCostume_[p] < DonModel::kPresetCount) previewKigurumi_[p] = -1;
                don3d_.SetCostume(p, DonModel::FromEntry(donCostume_[p], previewKigurumi_[p], customDress_[p]));
            } else {
                don3d_.SetCostume(p, DonModel::FromEntry(data.costume, data.kigurumi, data.dress));
            }
            // 画面の中央側へ少し向ける
            const float yaw = (p == 0 ? 30.0f : -30.0f) * DEG2RAD;
            BeginMode3D(camera);
            don3d_.Draw(p, don3d_.Expression(), MatrixRotateY(yaw));
            EndMode3D();
        } else {
            int costume = donCostume_[p] >= 0 ? donCostume_[p] : pd.Player(p).costume;
            if (costume == 4) costume = int(GetTime() * 6.0) % 4;   // おまかせは切り替えて見せる
            DrawDonSprite(Vector2{kDonTextureWidth * 0.5f, kDonTextureHeight * 0.5f}, kDonRadius, p, costume, false);
        }
        EndTextureMode();
    }
}

// ---------------------------------------------------------------------------
// 背景・どんちゃん
// ---------------------------------------------------------------------------
void EntryView::StartBackground() {
    Goto(background_, "start", true);
}

void EntryView::SetDonVisible(int player, bool visible) {
    donVisible_[player] = visible;
    if (don_[player]) don_[player]->SetVisible(visible);
}

void EntryView::DonFrameIn(int player) {
    SetDonVisible(player, true);
    Goto(don_[player], "framein", true);
}

void EntryView::DonJump(int player) {
    SetDonVisible(player, true);
    Goto(don_[player], "mode_select", true);
}

void EntryView::DonChange(int player) {
    SetDonVisible(player, true);
    Goto(don_[player], "init", false);
    Smoke(player);
}

void EntryView::DonGray(int player) {
    SetDonVisible(player, true);
    Goto(don_[player], "don_gray", true);
}

void EntryView::DonOut(int player) {
    Goto(don_[player], "out", true);
}

void EntryView::Smoke(int player) {
    Goto(smoke_[player], "smoke_in", true);
}

// ---------------------------------------------------------------------------
// ネームプレート（lua: NamePlate:SetPlayerInfo）
// ---------------------------------------------------------------------------
void EntryView::SetNamePlate(int player, bool visible) {
    Lumen::MovieClip* root = namePlate_[player];
    if (!root) return;
    root->SetVisible(visible);
    if (visible) CommonParts::SetNamePlate(root, player);
}

// ---------------------------------------------------------------------------
// タイマー（lua: Timer:DisplayCount）
// ---------------------------------------------------------------------------
void EntryView::SetTimer(int count, bool shadow) {
    if (!timerCounter_) return;
    if (Lumen::MovieClip* s = timerCounter_->Child("shadow")) s->SetVisible(shadow);
    if (count == timerCount_) return;
    timerCount_ = count;
    CommonParts::SetTimerCount(timerCounter_, count, kTimerRedLimit);
}

// ---------------------------------------------------------------------------
// クレジット受付（lua: CreditWait）
// ---------------------------------------------------------------------------
void EntryView::CreditStart() {
    if (!creditRoot_ || !credit_) return;
    creditRoot_->SetVisible(true);
    creditRoot_->Play();
    credit_->GotoAndPlay("fade_in");
    for (int i = 0; i < 2; ++i) {
        creditDecided_[i] = false;
        Goto(creditText_[i], "start", true);
    }
}

void EntryView::CreditDecide(int row) {
    Goto(creditText_[row], "choose", true);
    creditDecided_[row] = true;
}

void EntryView::CreditFinish() {
    Goto(credit_, "fade_out", true);
}

bool EntryView::CreditIsPlaying() const {
    return credit_ && credit_->IsPlay();
}

bool EntryView::CreditIsDecidePlaying() const {
    for (int i = 0; i < 2; ++i) {
        if (creditDecided_[i] && creditText_[i] && creditText_[i]->IsPlay()) return true;
    }
    return false;
}

void EntryView::SetCreditVisible(bool visible) {
    if (creditRoot_) creditRoot_->SetVisible(visible);
}

// ---------------------------------------------------------------------------
// 2人目参加受付（lua: CreditSide）
// ---------------------------------------------------------------------------
void EntryView::SetCreditSide(int player, bool visible) {
    Lumen::MovieClip* clip = creditSide_[player];
    if (!clip) return;
    if (visible && !clip->IsVisible()) clip->GotoAndPlay("main");
    clip->SetVisible(visible);
}

// ---------------------------------------------------------------------------
// 操作ガイド（lua: ControlGuide）
// ---------------------------------------------------------------------------
void EntryView::GuideStart(int mode) {
    if (!guide_) return;
    guide_->SetVisible(true);
    guide_->GotoAndPlay("start");
    if (Lumen::MovieClip* main = guide_->Child("main")) main->GotoAndStop("default");
    guideCenter_ = false;
    guideIdle_ = 0.0f;
    GuideChangeMode(mode);
}

void EntryView::GuideChangeMode(int mode) {
    Lumen::MovieClip* main = guide_ ? guide_->Child("main") : nullptr;
    if (!main) return;
    const char* label = mode == 0 ? "all" : "decide";
    Goto(main->Child("taiko_small"), label, false);
    Goto(main->Child("taiko_large"), label, false);
}

// 入力がない時間が続いたら、ガイドを中央に大きく出す
void EntryView::GuideUpdate(bool input) {
    Lumen::MovieClip* main = guide_ ? guide_->Child("main") : nullptr;
    if (!main) return;
    if (input) {
        guideIdle_ = 0.0f;
        if (guideCenter_) {
            guideCenter_ = false;
            main->GotoAndPlay("to_default");
        }
    }
    if (!guideCenter_ && guideIdle_ > 3.0f) {
        guideCenter_ = true;
        main->GotoAndPlay("to_center");
    }
}

void EntryView::GuideOut() {
    // lua は "outside" を指定しているが、control_guide にそのラベルはない（何も起きない）
}

void EntryView::GuideIn() {
}

void EntryView::SetGuideVisible(bool visible) {
    if (guide_) guide_->SetVisible(visible);
}

// ---------------------------------------------------------------------------
// モード選択（lua: ModeSelect / ModeSelectBorad）
// ---------------------------------------------------------------------------
Lumen::MovieClip* EntryView::Board(int kanban) {
    return kanban_[kanban] ? kanban_[kanban]->Child("board_main_instance") : nullptr;
}

void EntryView::ChangeBoardDisplay(int kanban, GameMode mode) {
    Lumen::MovieClip* board = Board(kanban);
    if (!board) return;
    const std::string label = ModeLabel(mode);

    for (const char* name : {"board_bg_top_instance", "board_bg_center_instance", "board_bg_bottom_instance",
                             "board_chara_r_instance", "board_chara_l_instance"}) {
        Goto(board->Child(name), label.c_str(), false);
    }
    Goto(board->Child("board_icon_instance"), mode == GameMode::Enso ? "none" : "only_1", false);

    if (Lumen::MovieClip* title = board->Child("text_title_instance")) {
        title->GotoAndStop(label);
        title->SetText("text_instance_1", "text_title", "mode_select_" + label);
        title->SetText("text_instance_2", "text_title", "mode_select_" + label);
        // モード名は板（四角）の中で上寄りに出るので、真ん中に来るよう下げる
        for (const char* name : {"text_instance_1", "text_instance_2"}) {
            if (Lumen::MovieClip* text = title->Child(name)) text->SetTextOffsetY(kModeTitleOffsetY);
        }
    }
    board->SetText("text_info_instance", "text_info", "mode_select_comment_" + label);
    if (mode == GameMode::Dani) {
        if (Lumen::MovieClip* chara = board->Child("board_chara_r_instance")) {
            chara->SetText("chara_year_instance", "text_year", "mode_select_dani_sub");
        }
    }
}

void EntryView::SetAllBoards() {
    for (int i = 0; i < 8; ++i) {
        if (!kanban_[i]) continue;
        const int menuIndex = modeSelect_ + i - kCenterKanban;
        if (menuIndex >= 0 && menuIndex < int(modeMenu_.size())) {
            kanban_[i]->SetVisible(true);
            ChangeBoardDisplay(i, modeMenu_[size_t(menuIndex)]);
            Goto(Board(i), "off", false);
        } else {
            kanban_[i]->SetVisible(false);
        }
    }
}

void EntryView::ModeStart(const std::vector<GameMode>& menu, int selectIndex) {
    // 直前のメニューになかったモードは光らせる
    modeHighlight_.clear();
    for (size_t i = 0; i < menu.size(); ++i) {
        if (std::find(modeMenu_.begin(), modeMenu_.end(), menu[i]) == modeMenu_.end()) modeHighlight_.push_back(int(i));
    }
    modeMenu_ = menu;
    modeSelect_ = selectIndex;
    SetAllBoards();

    for (Lumen::MovieClip* kanban : kanban_) Goto(kanban, "start", false);
    Goto(Board(kCenterKanban), "in", true);
    Goto(modeList_, "in", true);
    if (modeRoot_) modeRoot_->SetVisible(true);

    modeWait_ = 0.0f;
    modeStop_ = 0.0f;
    modeOpened_ = false;
    modeState_ = ModeState::StartWait;
}

void EntryView::ModeChangeList(const std::vector<GameMode>& menu, int selectIndex) {
    modeNextMenu_ = menu;
    modeNextSelect_ = selectIndex;
    Goto(modeList_, "outside", true);
    modeState_ = ModeState::ChangeList;
}

void EntryView::ModeMove(int move) {
    if (move < 0) {
        --modeSelect_;
        Goto(modeList_, "list_anim_up", true);
        Goto(Board(kCenterKanban), "select_off", true);
    } else {
        // 下に移るときは、先に看板を組み直してからリストを動かす
        ++modeSelect_;
        SetAllBoards();
        Goto(Board(kCenterKanban - 1), "select_off", true);
        Goto(modeList_, "list_anim_down", true);
    }
    modeOpened_ = false;
    modeState_ = ModeState::MenuMove;
}

void EntryView::ModeDecide() {
    Goto(Board(kCenterKanban), "choose", true);
    modeState_ = ModeState::Decide;
}

void EntryView::ModeFinish() {
    for (Lumen::MovieClip* kanban : kanban_) Goto(kanban, "finish", true);
    modeState_ = ModeState::Idle;
}

void EntryView::SetModeVisible(bool visible) {
    if (modeRoot_) modeRoot_->SetVisible(visible);
}

bool EntryView::ModeIsPlayBoard() const {
    Lumen::MovieClip* board = kanban_[kCenterKanban] ? kanban_[kCenterKanban]->Child("board_main_instance") : nullptr;
    return board && board->IsPlay();
}

// ---------------------------------------------------------------------------
// 使う太鼓の選択（lua: TaikoSelect）
// ---------------------------------------------------------------------------
void EntryView::TaikoStart(int minCursor, int maxCursor, const CardProfile& card) {
    if (!taikoRoot_ || !taikoMain_) return;
    const PlayDataManager& pd = PlayDataManager::Get();

    taikoRoot_->SetVisible(true);
    taikoBlink_ = nullptr;
    TaikoCursor(1);

    // カードでエントリー済みの側は選べない
    for (const char* name : {"p1_instance", "blink_left_instance"}) {
        if (Lumen::MovieClip* c = taikoMain_->Child(name)) c->SetVisible(minCursor == 0);
    }
    for (const char* name : {"p2_instance", "blink_right_instance"}) {
        if (Lumen::MovieClip* c = taikoMain_->Child(name)) c->SetVisible(maxCursor == 2);
    }

    // 読み込んだカードのどんちゃんを出す側
    int useDon = 1;
    if (pd.Player(0).userType == UserType::Card) useDon = 2;
    if (pd.Player(1).userType == UserType::Card) useDon = 1;
    if (pd.Player(0).userType == UserType::Coin && pd.Player(1).userType == UserType::None) useDon = 2;

    Lumen::MovieClip* info = taikoMain_->Child("info_instance");
    if (info) {
        if (Lumen::MovieClip* d = info->Child("don1p")) d->SetVisible(useDon == 1);
        if (Lumen::MovieClip* d = info->Child("don2p")) d->SetVisible(useDon == 2);
    }
    CostumeSetCustom(useDon - 1, card.dress);   // 着せかえアプリで決めた着せかえ（costume が 5 のとき）
    SetDonCostume(useDon - 1, card.isNew ? 0 : card.costume);

    if (info && card.isNew) {
        info->GotoAndStop("newcard");
    } else if (info) {
        info->GotoAndStop("player");
        // ネームプレート（lua: NamePlate:SetPlayerInfoEntry）
        if (Lumen::MovieClip* plate = info->Find("nameplate_instance/main")) {
            std::string label = "newentry";
            if (card.title[0] != '\0') label += "_shougou";
            plate->GotoAndStop(label);
            Goto(plate->Child("title_instance"), TitleDesignLabel(card.titleDesign), false);
            if (Lumen::MovieClip* number = plate->Child("plate_player_no")) number->SetVisible(false);
            Goto(plate->Child("blank_instance"), "off", false);
            WordList::Get().Set("user_name_entry", card.name);
            WordList::Get().Set("user_title_entry", card.title);
            plate->SetText("text_name", "user_name_entry");
            plate->SetText("text_title", "user_title_entry");
            CommonParts::StyleNamePlateText(plate);
        }
    }

    Goto(taikoMain_->Child("guide_instance"), "fade_in", true);
    taikoRoot_->GotoAndPlay("in");
}

void EntryView::TaikoCursor(int cursor) {
    static const char* const kLabels[3] = {"player_left", "not_use", "player_right"};
    Goto(taikoMain_, kLabels[cursor], false);
}

void EntryView::TaikoDecide(int cursor) {
    if (!taikoMain_) return;
    static const char* const kCursors[3] = {"p1_cursor_instance", "center_cursor_instance", "p2_cursor_instance"};
    static const char* const kBlinks[3] = {"blink_left_instance", "blink_center_instance", "blink_right_instance"};
    Goto(taikoMain_->Child(kCursors[cursor]), "decide", true);
    taikoBlink_ = taikoMain_->Child(kBlinks[cursor]);
    Goto(taikoBlink_, "decide", true);
}

bool EntryView::TaikoIsDecidePlaying() const {
    return taikoBlink_ && taikoBlink_->IsPlay();
}

void EntryView::TaikoFinish() {
    Goto(taikoRoot_, "out", true);
}

void EntryView::TaikoHide() {
    if (taikoRoot_) taikoRoot_->SetVisible(false);
    SetDonCostume(0, -1);
    SetDonCostume(1, -1);
}

// ---------------------------------------------------------------------------
// セッティングの台（lua: SettingBase）
// ---------------------------------------------------------------------------
void EntryView::SettingShow(bool visible) {
    if (settingRoot_) settingRoot_->SetVisible(visible);
    if (costumeRoot_) costumeRoot_->SetVisible(visible);
}

void EntryView::SettingStart(int player) {
    Goto(settingBase_[player], "fade_in", true);
}

void EntryView::SettingDispDon(int player, bool visible) {
    if (!settingBoard_[player]) return;
    if (Lumen::MovieClip* don = settingBoard_[player]->Child(player == 0 ? "don1p" : "don2p")) don->SetVisible(visible);
}

void EntryView::SettingWait(int player, bool decided) {
    if (!settingBoard_[player]) return;
    Goto(settingBoard_[player]->Child("message_instance"), "fade_in", true);
    if (decided) Goto(settingBoard_[player]->Child(player == 0 ? "don1p" : "don2p"), "select", true);
}

void EntryView::SettingFinishAll() {
    for (Lumen::MovieClip* board : settingBoard_) {
        if (board) Goto(board->Child("message_instance"), "init", false);
    }
}

// ---------------------------------------------------------------------------
// きせかえ（lua: CostumeSelectOnePlayer）
// ---------------------------------------------------------------------------
void EntryView::CostumeUpdateIcon(int player, int cursor) {
    static const char* const kLabels[5] = {"don", "cool", "cute", "joke", "choice"};
    Lumen::MovieClip* select = costumeBoard_[player] ? costumeBoard_[player]->Child("select_instance") : nullptr;
    if (!select) return;
    for (int i = 0; i < 5; ++i) {
        Lumen::MovieClip* icon = select->Child("icon_instance_" + std::to_string(i + 1));
        if (!icon) continue;
        icon->GotoAndStop(kLabels[i]);
        Goto(icon->Child("cursor_instance"), i == cursor ? "cursor_on" : "cursor_off", false);
    }
    if (Lumen::MovieClip* left = select->Child("arrow_l_instance")) left->SetVisible(cursor > 0);
    // 右の矢印の場所には6つ目の「じぶんで」を描く（EntryScene）ので出さない
    if (Lumen::MovieClip* right = select->Child("arrow_r_instance")) right->SetVisible(false);
}

void EntryView::CostumeEditMode(int player, bool editing) {
    Lumen::MovieClip* board = costumeBoard_[player];
    if (!board) return;
    if (Lumen::MovieClip* select = board->Child("select_instance")) select->SetVisible(!editing);
    if (Lumen::MovieClip* guide = board->Child("guide_instance")) guide->SetVisible(!editing);
}

void EntryView::CostumeStart(int player, int cursor) {
    Goto(costume_[player], "fade_in", true);
    CostumeUpdateIcon(player, cursor);
    SetDonCostume(player, cursor);
}

void EntryView::CostumeSmoke(int player) {
    if (!costumeBoard_[player]) return;
    Goto(costumeBoard_[player]->Child("smoke_instance"), "smoke_in", true);
    costumeSmoke_[player] = 0.25f;
}

void EntryView::CostumeCursor(int player, int cursor) {
    CostumeUpdateIcon(player, cursor);
    SetDonCostume(player, cursor);
    CostumeSmoke(player);
}

void EntryView::CostumeDecide(int player) {
    Lumen::MovieClip* board = costumeBoard_[player];
    if (!board) return;
    int cursor = 0;
    for (int i = 0; i < 5; ++i) {
        Lumen::MovieClip* icon = board->Find("select_instance/icon_instance_" + std::to_string(i + 1));
        Lumen::MovieClip* c = icon ? icon->Child("cursor_instance") : nullptr;
        if (c && c->CurrentFrame() == c->LabelFrame("cursor_on")) cursor = i;
    }
    costumeDecided_[player] = cursor;
    if (Lumen::MovieClip* icon = board->Find("select_instance/icon_instance_" + std::to_string(cursor + 1))) {
        if (Lumen::MovieClip* c = icon->Child("cursor_instance")) Goto(c->Child("cursor_anim_instance"), "decide", true);
        Goto(icon->Child("blink_instance"), "decide", true);
    }
    board->SetText("text_title", "");
    Goto(board->Child("guide_instance"), "fade_out", true);
}

bool EntryView::CostumeIsDecidePlaying(int player) const {
    Lumen::MovieClip* board = costumeBoard_[player];
    if (!board) return false;
    Lumen::MovieClip* icon = board->Find("select_instance/icon_instance_" + std::to_string(costumeDecided_[player] + 1));
    Lumen::MovieClip* blink = icon ? icon->Child("blink_instance") : nullptr;
    return blink && blink->IsPlay();
}

void EntryView::CostumeClose(int player) {
    if (costumeBoard_[player]) Goto(costumeBoard_[player]->Child("select_instance"), "fade_out", true);
    SetDonCostume(player, -1);
}

void EntryView::NameEntryShow(bool visible) {
    if (nameEntryRoot_) nameEntryRoot_->SetVisible(visible);
}

bool EntryView::ModeConsumeOpened() {
    const bool opened = modeOpened_;
    modeOpened_ = false;
    return opened;
}

void EntryView::UpdateMode(float dt) {
    switch (modeState_) {
    case ModeState::StartWait:
        modeWait_ += dt;
        if (modeList_ && !modeList_->IsPlay()) modeStop_ += dt;
        if (modeStop_ > 0.5f || modeWait_ > 0.6f) {
            if (!modeHighlight_.empty()) {
                for (int index : modeHighlight_) {
                    const int kanban = index - modeSelect_ + kCenterKanban;
                    if (kanban >= 0 && kanban < 8) Goto(Board(kanban), "inside", true);
                }
                modeState_ = ModeState::HighLight;
            } else {
                modeState_ = ModeState::StartWaitCount;
            }
        }
        break;
    case ModeState::HighLight: {
        modeWait_ += dt;
        bool playing = false;
        for (int index : modeHighlight_) {
            const int kanban = index - modeSelect_ + kCenterKanban;
            if (kanban >= 0 && kanban < 8 && Board(kanban) && Board(kanban)->IsPlay()) playing = true;
        }
        if (!playing) modeState_ = ModeState::StartWaitCount;
        break;
    }
    case ModeState::StartWaitCount:
        modeWait_ += dt;
        if (modeWait_ > 1.5f) modeState_ = ModeState::Main;
        break;
    case ModeState::MenuMove:
        if (modeList_ && !modeList_->IsPlay()) {
            modeList_->GotoAndStop("wait");
            SetAllBoards();
            Goto(Board(kCenterKanban), "select_on", true);
            modeState_ = ModeState::BoardOpenWait;
        }
        break;
    case ModeState::BoardOpenWait:
        if (!ModeIsPlayBoard()) {
            modeOpened_ = true;
            modeState_ = ModeState::Main;
        }
        break;
    case ModeState::ChangeList:
        if (modeList_ && !modeList_->IsPlay()) {
            modeHighlight_.clear();
            for (size_t i = 0; i < modeNextMenu_.size(); ++i) {
                if (std::find(modeMenu_.begin(), modeMenu_.end(), modeNextMenu_[i]) == modeMenu_.end()) {
                    modeHighlight_.push_back(int(i));
                }
            }
            modeMenu_ = modeNextMenu_;
            modeSelect_ = modeNextSelect_;
            SetAllBoards();
            Goto(Board(kCenterKanban), "in", true);
            Goto(modeList_, "inside", true);
            modeWait_ = 0.0f;
            modeStop_ = 0.0f;
            modeState_ = ModeState::StartWait;
        }
        break;
    default:
        break;
    }
}
