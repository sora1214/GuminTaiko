#include "PlayOptionBoard.hpp"

#include <algorithm>
#include <cstdio>

#include "SoundManager.hpp"

using namespace GuminTaiko;

namespace {

constexpr int kSpeedWaitFrames = 60;       // はやさ: 板が出てから入力を受け付けるまで（lua: Wait の Common.FPS * 1）
constexpr int kNeiroStartFrames = 12;      // 音色: 選んでから最初のドンまで（lua: 0.2 * Common.FPS）
constexpr int kNeiroIntervalFrames = 30;   // 音色: ドンとカッを交互に鳴らす間隔（lua: 0.5 * Common.FPS）
constexpr int kNeiroSlotBase = 4;          // 音色の試し打ちを鳴らすスロット（1P: 4、2P: 5）

// ---- 文字の上下の位置（ピクセル。小さくすると上へ、大きくすると下へ。0 が元のデータの位置）----
//   左右の位置は、元のデータの文字の枠の座標で決まっていて、ここでは変えられない
constexpr float kTitleOffsetY = 0.0f;       // 「演奏オプション」（板の上の題）
constexpr float kItemNameOffsetY = -5.0f;    // 項目の名前（はやさ・ドロン・あべこべ…）
constexpr float kItemValueOffsetY = -5.0f;   // 項目の値（1.0・しない・なし・太鼓…）
constexpr float kPositionTextOffsetY = 0.0f;   // 音符位置調整の窓の文字

const char* const kItemNames[PlayOptionBoard::kItemCount] = {"option_speed", "option_doron", "option_abekobe", "option_random",
                                                              "option_skip", "option_position", "option_voice", "option_neiro"};
const char* const kNeiroLabels[PlayOptions::kNeiroCount] = {
    "neiro_taiko",   "neiro_maturi",  "neiro_inuneko", "neiro_wonderfultaiko", "neiro_drum",      "neiro_tambourine", "neiro_wadadon",
    "neiro_clapping", "neiro_conga",  "neiro_8bittaiko", "neiro_soya",         "neiro_mekadon",   "neiro_funassyi",   "neiro_wrap",
    "neiro_isogai",  "neiro_akemi",   "neiro_synthdrum", "neiro_shuriken",     "neiro_puchipuchi", "neiro_electric guitar"};

void Goto(Lumen::MovieClip* clip, const std::string& label, bool play = false) {
    if (!clip) return;
    if (play) clip->GotoAndPlay(label);
    else clip->GotoAndStop(label);
}

void Visible(Lumen::MovieClip* clip, bool visible) {
    if (clip) clip->SetVisible(visible);
}

Lumen::MovieClip* Sub(Lumen::MovieClip* root, const std::string& path) { return root ? root->Find(path) : nullptr; }

std::string NeiroBank(int neiro) {
    char bank[32];
    std::snprintf(bank, sizeof(bank), "se_neiro_%02d_v12a", std::clamp(neiro, 0, PlayOptions::kNeiroCount - 1));
    return bank;
}

} // namespace

// lua: SongSelectOptionMain "Loading"（板と項目の部品を取り、項目の名前を入れる）
void PlayOptionBoard::Setup(Lumen::MovieClip* board, int player, bool right, bool twoPlayers) {
    board_ = board;
    player_ = player;
    right_ = right;
    twoPlayers_ = twoPlayers;
    if (!board_) return;

    static const int kCounts[kItemCount] = {PlayOptions::kSpeedCount, 2, 2, 3, 2, 2, 2, PlayOptions::kNeiroCount};
    for (int i = 0; i < kItemCount; ++i) {
        Selector& s = selectors_[size_t(i)];
        s.mc = Sub(board_, "board/selector_" + std::to_string(i + 1));
        s.arrowLeft = Sub(s.mc, "arrow_left");
        s.arrowRight = Sub(s.mc, "arrow_right");
        s.count = kCounts[i];
        if (s.mc) {
            s.mc->SetText("text_option_name", "text_option_name", kItemNames[i]);
            // 色と縁取りは元のまま、上下の位置だけ変える
            Lumen::MovieClip::TextStyle name, value;
            name.colors = value.colors = false;
            name.offsetY = kItemNameOffsetY;
            value.offsetY = kItemValueOffsetY;
            s.mc->SetTextStyle("text_option_name", name);
            s.mc->SetTextStyle("text_item_name", value);
        }
    }
    const char* side = right ? "r" : "l";
    positionWindow_ = Sub(board_, std::string("board/onp_position_") + side + "_mc");
    positionSelect_ = Sub(positionWindow_, "onp_position_select");
    if (Lumen::MovieClip* text = Sub(positionWindow_, "close_text")) text->SetText("close_text", "option_position_window");
    skipWindow_ = Sub(board_, std::string("board/enso_skip_") + side + "_mc");
    if (skipWindow_) skipWindow_->SetText("enso_skip_text", "enso_skip_text", "option_enso_skip_window");
    // 2人のときは演奏スキップを選べない
    if (twoPlayers_) Goto(selectors_[kSkip].mc, "grayout");
    // 右の板のプレイヤーのアイコン（1人で右の太鼓なら 1P と出す）
    if (right_) {
        Goto(Sub(board_, "board/player_icon_base"), "2p");
        Goto(Sub(board_, "board/player_icon"), twoPlayers_ ? "2p" : "1p");
    }
    if (Lumen::MovieClip* inner = Sub(board_, "board")) {
        inner->SetText("text_option_title", "text_option_title", "option_title");
        Lumen::MovieClip::TextStyle title;
        title.colors = false;
        title.offsetY = kTitleOffsetY;
        inner->SetTextStyle("text_option_title", title);
    }
    Reset();
}

// lua: PlayerOptionInit
void PlayOptionBoard::Reset() {
    for (int i = 0; i < kItemCount; ++i) SetCursor(i, false);
    positionOpen_ = false;
    item_ = 0;
    SetCursor(item_, true);
    fadeOut_ = false;
    open_ = false;
    Goto(board_, "in");
    for (const char* name : {"skip_right", "position_right", "skip_left", "position_left", "enso_skip_r_mc", "enso_skip_l_mc",
                             "onp_position_r_mc", "onp_position_l_mc"}) {
        Visible(Sub(board_, std::string("board/") + name), false);
    }
}

void PlayOptionBoard::Open(const PlayOptions& options) {
    if (!board_) return;
    // lua: SetPlayerOptionParamSelector
    selectors_[kSpeed].current = std::clamp(options.speed, 0, PlayOptions::kSpeedCount - 1);
    selectors_[kDoron].current = options.doron ? 1 : 0;
    selectors_[kAbekobe].current = options.abekobe ? 1 : 0;
    selectors_[kRandom].current = std::clamp(options.random, 0, 2);
    selectors_[kSkip].current = options.ensoSkip && !twoPlayers_ ? 1 : 0;
    selectors_[kPosition].current = options.notePosition != 0 ? 1 : 0;
    position_ = std::clamp(options.notePosition, -5, 5);
    selectors_[kVoice].current = options.voice ? 0 : 1;
    selectors_[kNeiro].current = std::clamp(options.neiro, 0, PlayOptions::kNeiroCount - 1);
    Reset();
    for (int i = 0; i < kItemCount; ++i) UpdateText(i, false, 0);

    // lua: Tween_SlideIn
    fadeIn_ = true;
    open_ = true;
    closed_ = false;
    Goto(board_, "in", true);
    StartCursor(0);
}

void PlayOptionBoard::ForceClose() {
    if (!open_) return;
    SoundManager::Get().StopSlot(kNeiroSlotBase + player_);
    Reset();
    closed_ = true;
}

bool PlayOptionBoard::TakeClosed() {
    const bool closed = closed_;
    closed_ = false;
    return closed;
}

PlayOptions PlayOptionBoard::Options() const {
    PlayOptions o;
    o.speed = selectors_[kSpeed].current;
    o.doron = selectors_[kDoron].current != 0;
    o.abekobe = selectors_[kAbekobe].current != 0;
    o.random = selectors_[kRandom].current;
    o.ensoSkip = selectors_[kSkip].current != 0;
    o.notePosition = selectors_[kPosition].current != 0 ? position_ : 0;
    o.voice = selectors_[kVoice].current == 0;
    o.neiro = selectors_[kNeiro].current;
    return o;
}

// lua: Update_1P / Update_2P と keyInput_1P / keyInput_2P
void PlayOptionBoard::Step(bool don, bool kaLeft, bool kaRight) {
    if (!open_ || !board_) return;
    if (fadeIn_ && !board_->IsPlay()) fadeIn_ = false;
    if (fadeOut_) {
        if (!board_->IsPlay()) {
            Reset();
            closed_ = true;
        }
        return;
    }
    if (fadeIn_) return;
    // はやさは板が出てからしばらく入力を受け付けない（lua: SongSelectOptionSelector:Wait）
    if (item_ == kSpeed && waitFrames_ < kSpeedWaitFrames) {
        ++waitFrames_;
        return;
    }
    if (item_ == kNeiro) UpdateNeiro();
    if (item_ == kPosition) SetPositionWindow(selectors_[kPosition].current == 0 ? 0 : position_);

    if (don) {
        PlaySe(player_ == 0 ? "don_c" : "don_r");
        Next();
    } else if (kaRight) {
        PlaySe(player_ == 0 ? "katsu_l" : "katsu_r");
        Change(1);
    } else if (kaLeft) {
        PlaySe(player_ == 0 ? "katsu_l" : "katsu_r");
        Change(-1);
    }
}

void PlayOptionBoard::PlaySe(const char* tone) const { SoundManager::Get().Play("se_common_v12a", tone); }

void PlayOptionBoard::SetCursor(int item, bool on) {
    Selector& s = selectors_[size_t(item)];
    Goto(Sub(s.mc, "select_cursor"), on ? "on" : "off");
    Goto(s.arrowLeft, on ? "on" : "off");
    Goto(s.arrowRight, on ? "on" : "off");
}

void PlayOptionBoard::StartCursor(int item) {
    switch (item) {
    case kSpeed: waitFrames_ = 0; break;
    case kSkip:
        // 演奏スキップの説明（lua: StartEnsoSkip）
        Visible(skipWindow_, true);
        Goto(skipWindow_, "skip_on", selectors_[kSkip].current != 0);
        break;
    case kPosition:
        Visible(positionWindow_, true);
        Goto(positionWindow_, "on", true);
        break;
    case kNeiro:
        neiroWait_ = 0;
        neiroTimer_ = 0;
        neiroDon_ = false;
        break;
    default: break;
    }
}

void PlayOptionBoard::EndCursor(int item) {
    switch (item) {
    case kSkip:
        if (selectors_[kSkip].current == 0) Goto(skipWindow_, "skip_on");
        else Goto(skipWindow_, "skip_off", true);
        break;
    case kPosition: Goto(positionWindow_, "on"); break;
    case kNeiro: SoundManager::Get().StopSlot(kNeiroSlotBase + player_); break;
    default: break;
    }
}

// lua: Tween_Left / Tween_Right（端まで行くと反対の端に回る。音符位置調整の窓が開いているときは値を動かす）
void PlayOptionBoard::Change(int direction) {
    Selector& s = selectors_[size_t(item_)];
    if (!positionOpen_) s.current = (s.current + direction + s.count) % s.count;
    Goto(direction < 0 ? s.arrowLeft : s.arrowRight, "select", true);
    UpdateText(item_, true, direction);
    if (item_ == kNeiro) {
        // 選び直したら最初のドンから鳴らし直す
        neiroWait_ = 0;
        neiroTimer_ = 0;
        neiroDon_ = false;
    }
}

// lua: TextSet（selecting: 項目を選んでいる最中の操作。窓の開け閉めもする）
void PlayOptionBoard::UpdateText(int item, bool selecting, int direction) {
    Selector& s = selectors_[size_t(item)];
    Goto(Sub(s.mc, "option_select_change_mc"), s.current == 0 ? "default" : "change");
    std::string text;
    switch (item) {
    case kSpeed: {
        char key[32];
        std::snprintf(key, sizeof(key), "option_speed_0%02d", s.current + 1);
        text = key;
        break;
    }
    case kRandom: {
        static const char* const kRandom[] = {"option_no", "option_kimagure", "option_detarame"};
        text = kRandom[std::clamp(s.current, 0, 2)];
        break;
    }
    case kVoice: text = s.current == 0 ? "option_yes" : "option_no"; break;
    case kNeiro: text = kNeiroLabels[std::clamp(s.current, 0, PlayOptions::kNeiroCount - 1)]; break;
    case kPosition:
        if (selecting && positionOpen_) {
            // 窓が開いているあいだは左5〜右5を選ぶ（lua: OnpuPositionSelect）
            position_ = std::clamp(position_ + direction, -5, 5);
            SetPositionWindow(position_);
            Goto(Sub(positionWindow_, direction < 0 ? "option_select_arrow_left" : "option_select_arrow_right"), "select", true);
            return;
        }
        if (!selecting) SetPositionWindow(s.current == 0 ? 0 : position_);
        text = s.current == 0 ? "option_off" : "option_on";
        break;
    default: text = s.current == 0 ? "option_off" : "option_on"; break;
    }
    if (s.mc) s.mc->SetText("text_item_name", "text_item_name", text);

    // 演奏スキップは「する」にすると説明を出す（lua: EnsoSkipSelect）
    if (item == kSkip && selecting) {
        if (s.current == 0) {
            Goto(skipWindow_, "skip_off", true);
        } else {
            Visible(skipWindow_, true);
            Goto(skipWindow_, "skip_on", true);
        }
    }
}

// lua: SetOnpuPositionGotoPlay
//   窓の開くアニメーションは中の目盛り（onp_position_select）を置き直すので、選んでいるあいだは毎フレーム合わせる
void PlayOptionBoard::SetPositionWindow(int position) {
    positionSelect_ = Sub(positionWindow_, "onp_position_select");
    if (!positionSelect_) return;
    const std::string label = position == 0 ? "0" : position < 0 ? "left" + std::to_string(-position) : "right" + std::to_string(position);
    if (positionSelect_->CurrentFrame() != positionSelect_->LabelFrame(label)) Goto(positionSelect_, label);
    char key[32];
    std::snprintf(key, sizeof(key), "option_position_0%02d", 6 + position);
    positionSelect_->SetText("text_onp_position", "text_position", key);
    {
        Lumen::MovieClip::TextStyle style;
        style.colors = false;
        style.offsetY = kPositionTextOffsetY;
        positionSelect_->SetTextStyle("text_onp_position", style);
    }
}

// 面: 次の項目へ（lua: CursorMove）
void PlayOptionBoard::Next() {
    if (item_ == kPosition && selectors_[kPosition].current != 0) {
        if (!positionOpen_) {
            // 音符位置調整の窓を開く
            Goto(positionWindow_, "open", true);
            SetPositionWindow(position_);
            positionOpen_ = true;
            return;
        }
        Goto(positionWindow_, "close", true);
        positionOpen_ = false;
    }

    SetCursor(item_, false);
    EndCursor(item_);
    ++item_;
    if (twoPlayers_ && item_ == kSkip) ++item_;   // 2人のときは演奏スキップを飛ばす
    if (item_ >= kItemCount) {
        // すべての項目を終えたら閉じる（lua: SaveOptionParam → Tween_SlideOut）
        fadeOut_ = true;
        Goto(board_, "out", true);
        return;
    }
    SetCursor(item_, true);
    StartCursor(item_);
}

// 選んでいる音色でドンとカッを交互に鳴らす（lua: NeiroUpdate）
void PlayOptionBoard::UpdateNeiro() {
    const int slot = kNeiroSlotBase + player_;
    const std::string bank = NeiroBank(selectors_[kNeiro].current);
    if (neiroWait_ <= kNeiroStartFrames) {
        if (++neiroWait_ > kNeiroStartFrames) {
            SoundManager::Get().PlaySlot(bank, "don_c", slot);
            neiroDon_ = true;
        }
        return;
    }
    if (++neiroTimer_ > kNeiroIntervalFrames) {
        SoundManager::Get().PlaySlot(bank, neiroDon_ ? "katsu_c" : "don_c", slot);
        neiroDon_ = !neiroDon_;
        neiroTimer_ = 0;
    }
}
