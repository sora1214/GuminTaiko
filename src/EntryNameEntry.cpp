#include "EntryNameEntry.hpp"

#include <map>
#include <vector>

#include "SoundManager.hpp"

namespace {

// ---- リングの構成（lua: NameEntry.ring1_list_ / ring2_list_ / ring3_list_。番号は 1 始まり） ----
struct RingItem {
    const char* code;
    int count;   // 次のリングの枠数（0 なら次のリングはない）
};

const std::vector<RingItem> kRing1 = {
    {"a", 6}, {"k", 6}, {"s", 6}, {"t", 6}, {"n", 6}, {"h", 6}, {"m", 6},
    {"y", 4}, {"r", 6}, {"w", 6}, {"sp", 5}, {"back", 0}, {"end", 0},
};

const std::vector<std::vector<RingItem>> kRing2 = {
    {{"a", 3}, {"i", 3}, {"u", 3}, {"e", 3}, {"o", 3}, {"back", 0}},
    {{"ka", 3}, {"ki", 3}, {"ku", 3}, {"ke", 3}, {"ko", 3}, {"back", 0}},
    {{"sa", 3}, {"si", 3}, {"su", 3}, {"se", 3}, {"so", 3}, {"back", 0}},
    {{"ta", 3}, {"ti", 3}, {"tu", 4}, {"te", 3}, {"to", 3}, {"back", 0}},
    {{"na", 0}, {"ni", 0}, {"nu", 0}, {"ne", 0}, {"no", 0}, {"back", 0}},
    {{"ha", 4}, {"hi", 4}, {"hu", 4}, {"he", 4}, {"ho", 4}, {"back", 0}},
    {{"ma", 0}, {"mi", 0}, {"mu", 0}, {"me", 0}, {"mo", 0}, {"back", 0}},
    {{"ya", 3}, {"yu", 3}, {"yo", 3}, {"back", 0}},
    {{"ra", 0}, {"ri", 0}, {"ru", 0}, {"re", 0}, {"ro", 0}, {"back", 0}},
    {{"wa", 3}, {"wi", 0}, {"we", 0}, {"wo", 0}, {"nn", 0}, {"back", 0}},
    {{"sp1", 0}, {"sp2", 0}, {"sp3", 0}, {"sp4", 0}, {"back", 0}},
};

const std::vector<std::vector<std::vector<const char*>>> kRing3 = {
    {{"a", "xa", "back"}, {"i", "xi", "back"}, {"u", "xu", "back"}, {"e", "xe", "back"}, {"o", "xo", "back"}},
    {{"ka", "ga", "back"}, {"ki", "gi", "back"}, {"ku", "gu", "back"}, {"ke", "ge", "back"}, {"ko", "go", "back"}},
    {{"sa", "za", "back"}, {"si", "zi", "back"}, {"su", "zu", "back"}, {"se", "ze", "back"}, {"so", "zo", "back"}},
    {{"ta", "da", "back"}, {"ti", "di", "back"}, {"tu", "du", "xtu", "back"}, {"te", "de", "back"}, {"to", "do", "back"}},
    {},
    {{"ha", "ba", "pa", "back"}, {"hi", "bi", "pi", "back"}, {"hu", "bu", "pu", "back"}, {"he", "be", "pe", "back"}, {"ho", "bo", "po", "back"}},
    {},
    {{"ya", "xya", "back"}, {"yu", "xyu", "back"}, {"yo", "xyo", "back"}},
    {},
    {{"wa", "xwa", "back"}},
};

const RingItem& Ring1(int index) { return kRing1[size_t(index - 1)]; }
const std::vector<RingItem>& Ring2List(int ring1) { return kRing2[size_t(ring1 - 1)]; }
const RingItem& Ring2(int ring1, int index) { return Ring2List(ring1)[size_t(index - 1)]; }
const std::vector<const char*>& Ring3List(int ring1, int ring2) { return kRing3[size_t(ring1 - 1)][size_t(ring2 - 1)]; }

// ローマ字コード → ひらがな
const char* Kana(const std::string& code) {
    static const std::map<std::string, const char*> kKana = {
        {"a", "あ"}, {"i", "い"}, {"u", "う"}, {"e", "え"}, {"o", "お"},
        {"xa", "ぁ"}, {"xi", "ぃ"}, {"xu", "ぅ"}, {"xe", "ぇ"}, {"xo", "ぉ"},
        {"ka", "か"}, {"ki", "き"}, {"ku", "く"}, {"ke", "け"}, {"ko", "こ"},
        {"ga", "が"}, {"gi", "ぎ"}, {"gu", "ぐ"}, {"ge", "げ"}, {"go", "ご"},
        {"sa", "さ"}, {"si", "し"}, {"su", "す"}, {"se", "せ"}, {"so", "そ"},
        {"za", "ざ"}, {"zi", "じ"}, {"zu", "ず"}, {"ze", "ぜ"}, {"zo", "ぞ"},
        {"ta", "た"}, {"ti", "ち"}, {"tu", "つ"}, {"te", "て"}, {"to", "と"},
        {"da", "だ"}, {"di", "ぢ"}, {"du", "づ"}, {"de", "で"}, {"do", "ど"}, {"xtu", "っ"},
        {"na", "な"}, {"ni", "に"}, {"nu", "ぬ"}, {"ne", "ね"}, {"no", "の"},
        {"ha", "は"}, {"hi", "ひ"}, {"hu", "ふ"}, {"he", "へ"}, {"ho", "ほ"},
        {"ba", "ば"}, {"bi", "び"}, {"bu", "ぶ"}, {"be", "べ"}, {"bo", "ぼ"},
        {"pa", "ぱ"}, {"pi", "ぴ"}, {"pu", "ぷ"}, {"pe", "ぺ"}, {"po", "ぽ"},
        {"ma", "ま"}, {"mi", "み"}, {"mu", "む"}, {"me", "め"}, {"mo", "も"},
        {"ya", "や"}, {"yu", "ゆ"}, {"yo", "よ"}, {"xya", "ゃ"}, {"xyu", "ゅ"}, {"xyo", "ょ"},
        {"ra", "ら"}, {"ri", "り"}, {"ru", "る"}, {"re", "れ"}, {"ro", "ろ"},
        {"wa", "わ"}, {"wi", "ゐ"}, {"we", "ゑ"}, {"wo", "を"}, {"nn", "ん"}, {"xwa", "ゎ"},
        {"sp1", "～"}, {"sp2", "ー"}, {"sp3", "？"}, {"sp4", "！"},
    };
    auto found = kKana.find(code);
    return found != kKana.end() ? found->second : "";
}

Lumen::MovieClip* Child(Lumen::MovieClip* clip, const std::string& name) {
    return clip ? clip->Child(name) : nullptr;
}

void Visible(Lumen::MovieClip* clip, bool visible) {
    if (clip) clip->SetVisible(visible);
}

void Stop(Lumen::MovieClip* clip, const std::string& label) {
    if (clip) clip->GotoAndStop(label);
}

void Play(Lumen::MovieClip* clip, const std::string& label) {
    if (clip) clip->GotoAndPlay(label);
}

bool IsPlay(Lumen::MovieClip* clip) {
    return clip && clip->IsPlay();
}

// 文字の部品を、指定した枠の位置に動かす
void MoveTo(Lumen::MovieClip* parent, const std::string& moji, const std::string& plate) {
    Lumen::MovieClip* m = Child(parent, moji);
    Lumen::MovieClip* p = Child(parent, plate);
    if (m && p) m->SetPosition(p->Position());
}

} // namespace

// ===========================================================================
// NetWindow
// ===========================================================================
void NetWindow::Setup(Lumen::MovieClip* root) {
    root_ = root;
    for (const char* name : {"loading_instance", "success_instance", "error_instance"}) {
        Stop(Child(root_, name), "wait");
    }
}

void NetWindow::Open(const char* rootLabel, const char* instance) {
    if (!root_) return;
    for (const char* name : {"loading_instance", "success_instance", "error_instance"}) {
        if (std::string(name) != instance) Stop(Child(root_, name), "wait");
    }
    root_->SetVisible(true);
    Play(root_, rootLabel);
    current_ = Child(root_, instance);
    Play(current_, "in");
}

void NetWindow::Loading(const char* titleKey) {
    if (Lumen::MovieClip* title = Child(Child(root_, "loading_instance"), "text_title_instance")) {
        title->SetText("text_title", titleKey);
    }
    Open("loading", "loading_instance");
}

void NetWindow::Success(const char* titleKey, const char* subKey) {
    if (Lumen::MovieClip* text = Child(Child(root_, "success_instance"), "text_instance")) {
        text->SetText("text_title", titleKey);
        text->SetText("text_sub", subKey);
    }
    Open("success", "success_instance");
}

void NetWindow::Error(const char* titleKey, const char* subKey) {
    if (Lumen::MovieClip* text = Child(Child(root_, "error_instance"), "text_instance")) {
        text->SetText("text_title", titleKey);
        text->SetText("text_sub", subKey);
    }
    Open("error", "error_instance");
}

void NetWindow::Close() {
    Play(current_, "out");
    Play(root_, "out");
}

bool NetWindow::IsPlay() const {
    return ::IsPlay(current_) || ::IsPlay(root_);
}

// ===========================================================================
// NameEntryPanel
// ===========================================================================
void NameEntryPanel::Setup(Lumen::MovieClip* root, Lumen::MovieClip* guide, int player, NetWindow* net) {
    mc_ = root;
    guide_ = guide;
    player_ = player;
    net_ = net;
    if (!mc_) return;

    const std::string color = player_ == 0 ? "color_1p" : "color_2p";
    mc_->Stop();
    if (guide_) guide_->Stop();

    for (std::string& c : name_) c = " ";
    bigplateCursor_ = 1;
    ring1Index_ = ring2Index_ = ring3Index_ = 1;
    nameDecideBlank_ = false;
    acceptCursor_ = 1;

    nameInput_ = Child(mc_, "nameinput_instance");
    if (nameInput_) nameInput_->SetText("text_title", "name_entry");

    // 名前の確認ウィンドウ
    acceptBase_ = Child(nameInput_, "accept_instance");
    accept_ = Child(acceptBase_, "accept_main_mc");
    if (accept_) {
        Stop(Child(accept_, "button_no_instance"), "color_2p");
        Stop(Child(accept_, "button_yes_instance"), "color_1p");
        Stop(Child(accept_, "plate_instance"), color);
        accept_->SetText("text_message", "name_entry_accept");
        accept_->SetText("text_yes", "result_yes");
        accept_->SetText("text_no", "result_no");
        if (Lumen::MovieClip* notice = Child(accept_, "text_notice_instance")) notice->SetText("text_notice", "name_entry_notice");
        if (Lumen::MovieClip* g = Child(accept_, "guide_instance")) {
            if (Lumen::MovieClip* s = Child(g, "select_instance")) s->SetText("text_guide_instance", "text_guide", "select");
            if (Lumen::MovieClip* d = Child(g, "decide_instance")) d->SetText("text_guide_instance", "text_guide", "decide");
            Stop(Child(g, "base_instance"), "inwindow");
            Stop(g, "fade_in_end");
        }
    }
    Visible(acceptBase_, false);

    // 名前が NG だったときのウィンドウ（NG チェックはしないので使わない）
    Visible(Child(nameInput_, "ng_instance"), false);

    // 名前のプレート
    Lumen::MovieClip* plateBig = Child(nameInput_, "plate_big_instance");
    Stop(plateBig, color);
    for (int i = 0; i < 5; ++i) {
        dispNameChar_[i] = Child(plateBig, "plate_big_" + std::to_string(i + 1));
        Stop(dispNameChar_[i], color);
    }

    // 操作ガイド
    if (guide_) {
        if (Lumen::MovieClip* s = Child(guide_, "select_instance")) s->SetText("text_guide_instance", "text_guide", "select");
        if (Lumen::MovieClip* d = Child(guide_, "decide_instance")) d->SetText("text_guide_instance", "text_guide", "decide");
        Stop(Child(guide_, "base_instance"), "outwindow");
    }

    // 中央の文字
    center_ = Child(nameInput_, "center");
    Stop(Child(center_, "plate"), color);

    // リング
    ring1_ = Child(nameInput_, "ring_1");
    ring2_ = Child(nameInput_, "ring_2");
    ring3_ = Child(nameInput_, "ring_3");
    for (int i = 1; i <= 13; ++i) Stop(Child(ring1_, "plate_" + std::to_string(i)), color);
    const char* ring2Rows[3] = {"row4", "row5", "row6"};
    for (int r = 0; r < 3; ++r) {
        ring2Row_[r] = Child(ring2_, ring2Rows[r]);
        for (int i = 1; i <= 4 + r; ++i) Stop(Child(ring2Row_[r], "plate_" + std::to_string(i)), color);
    }
    const char* ring3Rows[2] = {"row3", "row4"};
    for (int r = 0; r < 2; ++r) {
        ring3Row_[r] = Child(ring3_, ring3Rows[r]);
        for (int i = 1; i <= 3 + r; ++i) Stop(Child(ring3Row_[r], "plate_" + std::to_string(i)), color);
    }
    ring2Disp_ = ring2Row_[2];
    ring3Disp_ = ring3Row_[0];

    SetBigplateCursor(bigplateCursor_);
    SetNameBigplate();
    SetDispModeRing1();
    state_ = State::StartWait;
    result_ = Result::Finish;
}

void NameEntryPanel::Start() {
    Play(mc_, "fade_in");
    Play(guide_, "fade_in");
    result_ = Result::Doing;
}

void NameEntryPanel::StartSelect() {
    SetState(State::Ring1);
}

void NameEntryPanel::SetState(State state) {
    state_ = state;
    stateTime_ = 0.0f;
}

void NameEntryPanel::PlaySe(const char* name) const {
    const char* suffix = playerNum_ == 1 ? "_c" : (player_ == 0 ? "_l" : "_r");
    SoundManager::Get().Play("se_common_v12a", std::string(name) + suffix);
}

std::string NameEntryPanel::NameText() const {
    std::string out;
    for (const std::string& c : name_) {
        if (c != " ") out += Kana(c);
    }
    return out;
}

NameEntryPanel::Result NameEntryPanel::Update(float dt, bool left, bool right, bool don) {
    if (!mc_) return Result::Finish;
    stateTime_ += dt;

    switch (state_) {
    case State::StartWait:
    case State::End:
        break;

    // ---- 1段目（あかさたな…） ----
    case State::ToRing1:
        if (!IsPlay(nameInput_)) {
            SetRingCursor(true);
            SetState(State::Ring1);
        }
        break;
    case State::Ring1: {
        if (don) {
            const std::string code = Ring1(ring1Index_).code;
            if (code == "back") {
                // 1文字もどす
                name_[bigplateCursor_ - 1] = " ";
                if (--bigplateCursor_ <= 0) {
                    bigplateCursor_ = 1;
                    name_[0] = " ";
                }
                PlaySe("primal_cancel");
                SetNameBigplate();
                ring1Index_ = 1;
                SetupToRing1();
            } else if (code == "end") {
                ChangeBlankNameToDefaultName();
                PlaySe("don");
                SetupToAccept();
            } else {
                PlaySe("don");
                ring2Index_ = 1;
                SetupToRing2();
            }
        } else if (left || right) {
            const int count = int(kRing1.size());
            ring1Index_ = left ? (ring1Index_ <= 1 ? count : ring1Index_ - 1) : (ring1Index_ >= count ? 1 : ring1Index_ + 1);
            Visible(Child(ring1_, "cursor_plate"), false);
            Play(ring1_, left ? "left" : "right");
            PlaySe("katsu");
            SetState(State::Ring1Move);
        }
        break;
    }
    case State::Ring1Move:
        SetDispCharPosRing1();
        if (!IsPlay(ring1_)) {
            SetDispRing2(true);
            SetDispCenter(1);
            Visible(Child(ring1_, "cursor_plate"), true);
            SetState(State::Ring1);
        }
        break;

    // ---- 2段目（あいうえお） ----
    case State::ToRing2:
        if (!IsPlay(nameInput_)) {
            SetRingCursor(true);
            SetState(State::Ring2);
        }
        break;
    case State::Ring2: {
        if (don) {
            const RingItem& item = Ring2(ring1Index_, ring2Index_);
            if (std::string(item.code) == "back") {
                PlaySe("primal_cancel");
                ring2Index_ = 1;
                SetupToRing1();
            } else if (item.count == 0) {
                PlaySe("don");
                Play(center_, "pos_" + std::to_string(bigplateCursor_));
                name_[bigplateCursor_ - 1] = item.code;
                SetState(State::CharDecide);
            } else {
                PlaySe("don");
                ring3Index_ = 1;
                SetupToRing3();
            }
        } else if (left || right) {
            const int count = int(Ring2List(ring1Index_).size());
            ring2Index_ = left ? (ring2Index_ <= 1 ? count : ring2Index_ - 1) : (ring2Index_ >= count ? 1 : ring2Index_ + 1);
            Visible(Child(ring2Disp_, "cursor_plate"), false);
            Play(ring2Disp_, left ? "left" : "right");
            PlaySe("katsu");
            SetState(State::Ring2Move);
        }
        break;
    }
    case State::Ring2Move:
        SetDispCharPosRing2();
        if (!IsPlay(ring2Disp_)) {
            SetDispRing3(true);
            SetDispCenter(2);
            Visible(Child(ring2Disp_, "cursor_plate"), true);
            SetState(State::Ring2);
        }
        break;

    // ---- 3段目（濁点・半濁点・小さい文字） ----
    case State::ToRing3:
        if (!IsPlay(nameInput_)) {
            SetRingCursor(true);
            SetState(State::Ring3);
        }
        break;
    case State::Ring3: {
        if (don) {
            const std::string code = Ring3List(ring1Index_, ring2Index_)[size_t(ring3Index_ - 1)];
            if (code == "back") {
                PlaySe("primal_cancel");
                ring3Index_ = 1;
                SetupToRing2();
            } else {
                PlaySe("don");
                Play(center_, "pos_" + std::to_string(bigplateCursor_));
                name_[bigplateCursor_ - 1] = code;
                SetState(State::CharDecide);
            }
        } else if (left || right) {
            const int count = int(Ring3List(ring1Index_, ring2Index_).size());
            ring3Index_ = left ? (ring3Index_ <= 1 ? count : ring3Index_ - 1) : (ring3Index_ >= count ? 1 : ring3Index_ + 1);
            Visible(Child(ring3Disp_, "cursor_plate"), false);
            Play(ring3Disp_, left ? "left" : "right");
            PlaySe("katsu");
            SetState(State::Ring3Move);
        }
        break;
    }
    case State::Ring3Move:
        SetDispCharPosRing3();
        if (!IsPlay(ring3Disp_)) {
            SetDispCenter(3);
            Visible(Child(ring3Disp_, "cursor_plate"), true);
            SetState(State::Ring3);
        }
        break;

    // 文字がプレートへ飛んでいく演出のあと、次の文字へ
    case State::CharDecide:
        if (!IsPlay(center_)) {
            SetNameBigplate();
            if (++bigplateCursor_ > 5) {
                bigplateCursor_ = 5;
                ring1Index_ = int(kRing1.size());   // 「おわり」
            } else {
                ring1Index_ = 1;
            }
            ring2Index_ = ring3Index_ = 1;
            SetupToRing1();
        }
        break;

    // ---- 確認 ----
    case State::ToAccept:
        if (!IsPlay(nameInput_)) {
            SetDispRing1(false);
            Visible(acceptBase_, true);
            SetAcceptWindow(acceptCursor_);
            Play(acceptBase_, "start");
            SetState(State::ToAccept2);
        }
        break;
    case State::ToAccept2:
        if (!IsPlay(acceptBase_)) SetState(State::Accept);
        break;
    case State::Accept:
        if (don) {
            Play(Child(accept_, "selectBorder"), "decide");
            Play(Child(accept_, "blink_instance"), "decide");
            if (acceptCursor_ == 1) {
                result_ = Result::Upload;
                PlaySe("don");
            } else {
                PlaySe("primal_cancel");
            }
            SetState(State::DecideWait);
        } else if (left && acceptCursor_ == 2) {
            PlaySe("katsu");
            acceptCursor_ = 1;
            SetAcceptWindow(acceptCursor_);
        } else if (right && acceptCursor_ == 1) {
            PlaySe("katsu");
            acceptCursor_ = 2;
            SetAcceptWindow(acceptCursor_);
        }
        break;
    case State::DecideWait:
        if (!IsPlay(Child(accept_, "blink_instance"))) {
            if (acceptCursor_ == 1) {
                // 名前を登録する（通信の演出だけ行う）
                if (net_) net_->Loading("now_connectserver");
                SetState(State::Upload);
            } else {
                if (nameDecideBlank_) {
                    bigplateCursor_ = 1;
                    for (std::string& c : name_) c = " ";
                    SetNameBigplate();
                }
                ring1Index_ = 1;
                SetupToRing1();
            }
        }
        break;

    // ---- 登録（通信中 → 成功） ----
    case State::Upload:
        if (stateTime_ >= 1.0f) {
            if (net_) net_->Close();
            SetState(State::ToSuccess);
        }
        break;
    case State::ToSuccess:
        if (!net_ || !net_->IsPlay()) {
            if (net_) net_->Success("connectserver_ok", "connectserver_nameok_sub");
            SoundManager::Get().Play("se_common_v12a", "card_success");
            SetState(State::Success);
        }
        break;
    case State::Success:
        if (stateTime_ >= 2.0f) {
            if (net_) net_->Close();
            SetState(State::SuccessToEnd);
        }
        break;
    case State::SuccessToEnd:
        if (!net_ || !net_->IsPlay()) SetState(State::EndWait);
        break;
    case State::EndWait:
        SetFinish();
        Play(mc_, "fade_out");
        SetState(State::End);
        break;
    }
    return result_;
}

void NameEntryPanel::TimeUp() {
    if (result_ != Result::Doing) return;
    ChangeBlankNameToDefaultName();
    SetBigplateCursor(-1);
    SetRingCursor(false);
    Visible(acceptBase_, false);
    if (net_) net_->Loading("now_connectserver");
    result_ = Result::Upload;
    SetState(State::Upload);
}

// ---------------------------------------------------------------------------
// 表示の調整（lua の同名関数）
// ---------------------------------------------------------------------------
void NameEntryPanel::SetBigplateCursor(int pos) {
    for (int i = 0; i < 5; ++i) {
        const bool on = i + 1 == pos;
        Visible(Child(dispNameChar_[i], "cursor_frame"), on);
        Visible(Child(dispNameChar_[i], "cursor_plate"), on);
    }
}

void NameEntryPanel::SetNameBigplate() {
    for (int i = 0; i < 5; ++i) {
        Lumen::MovieClip* moji = Child(dispNameChar_[i], "moji");
        if (name_[i] == " ") {
            Visible(moji, false);
        } else {
            Visible(moji, true);
            Stop(moji, name_[i]);
        }
    }
}

void NameEntryPanel::SetupToRing1() {
    Visible(acceptBase_, false);
    Visible(guide_, true);
    SetBigplateCursor(bigplateCursor_);
    SetRingCursor(false);
    SetDispModeRing1();
    Play(nameInput_, "ring1");
    SetState(State::ToRing1);
}

void NameEntryPanel::SetupToRing2() {
    SetRingCursor(false);
    SetDispModeRing2();
    Play(nameInput_, "ring2");
    SetState(State::ToRing2);
}

void NameEntryPanel::SetupToRing3() {
    SetRingCursor(false);
    SetDispModeRing3();
    Play(nameInput_, "ring3");
    SetState(State::ToRing3);
}

void NameEntryPanel::SetupToAccept() {
    acceptCursor_ = 2;
    SetBigplateCursor(-1);
    SetRingCursor(false);
    SetDispRing2(false);
    SetDispRing3(false);
    Play(nameInput_, "ring2");
    SetDispCenter(-1);
    Visible(guide_, false);
    SetState(State::ToAccept);
}

void NameEntryPanel::SetRingCursor(bool flag) {
    Visible(Child(nameInput_, "cursor_frame"), flag);
    Visible(Child(nameInput_, "cursor"), flag);
}

void NameEntryPanel::SetDispModeRing1() {
    SetDispCenter(1);
    SetDispRing1(true);
    SetDispRing2(true);
    SetDispRing3(false);
    for (Lumen::MovieClip* row : ring2Row_) Visible(Child(row, "cursor_plate"), false);
}

void NameEntryPanel::SetDispModeRing2() {
    SetDispCenter(2);
    SetDispRing1(false);
    SetDispRing2(true);
    SetDispRing3(true);
    for (Lumen::MovieClip* row : ring2Row_) Visible(Child(row, "cursor_plate"), true);
    for (Lumen::MovieClip* row : ring3Row_) Visible(Child(row, "cursor_plate"), false);
}

void NameEntryPanel::SetDispModeRing3() {
    SetDispCenter(3);
    SetDispRing1(false);
    SetDispRing2(false);
    SetDispRing3(true);
    for (Lumen::MovieClip* row : ring3Row_) Visible(Child(row, "cursor_plate"), true);
}

void NameEntryPanel::SetDispRing1(bool flag) {
    Visible(ring1_, flag);
    if (flag) SetDispCharPosRing1();
}

void NameEntryPanel::SetDispRing2(bool flag) {
    Visible(ring2_, flag);
    if (!flag) return;

    const RingItem& item = Ring1(ring1Index_);
    if (item.count == 4) {
        // や行は4枠（やゆよ＋もどる）
        Visible(ring2Row_[0], true);
        Visible(ring2Row_[1], false);
        Visible(ring2Row_[2], false);
        ring2Disp_ = ring2Row_[0];
    } else if (item.count == 5) {
        // 記号は5枠（～ー？！＋もどる）
        Visible(ring2Row_[0], false);
        Visible(ring2Row_[1], true);
        Visible(ring2Row_[2], false);
        ring2Disp_ = ring2Row_[1];
    } else if (item.count == 0) {
        // もどる・おわりは次がない
        for (Lumen::MovieClip* row : ring2Row_) Visible(row, false);
    } else {
        // それ以外は6枠（母音5つ＋もどる）
        Visible(ring2Row_[0], false);
        Visible(ring2Row_[1], false);
        Visible(ring2Row_[2], true);
        ring2Disp_ = ring2Row_[2];
        static const char* const kPre[] = {"a", "k", "s", "t", "n", "h", "m", "r", "w"};
        static const char* const kPost[] = {"1_ins", "2_ins", "3_ins", "4_ins", "5_ins"};
        SetDispRingChar(ring2Row_[2], item.code, kPre, 9, kPost, 5);
    }
    SetDispCharPosRing2();
}

void NameEntryPanel::SetDispRing3(bool flag) {
    Visible(ring3_, flag);
    if (!flag) return;

    const RingItem& item = Ring2(ring1Index_, ring2Index_);
    if (item.count == 3) {
        Visible(ring3Row_[0], true);
        Visible(ring3Row_[1], false);
        ring3Disp_ = ring3Row_[0];
        static const char* const kPre[] = {"a", "i", "u", "e", "o", "ka", "ki", "ku", "ke", "ko", "sa", "si",
                                           "su", "se", "so", "ta", "ti", "te", "to", "ya", "yu", "yo", "wa"};
        static const char* const kPost[] = {"1_ins", "2_ins"};
        SetDispRingChar(ring3Row_[0], item.code, kPre, 23, kPost, 2);
    } else if (item.count == 4) {
        Visible(ring3Row_[0], false);
        Visible(ring3Row_[1], true);
        ring3Disp_ = ring3Row_[1];
        static const char* const kPre[] = {"tu", "ha", "hi", "hu", "he", "ho"};
        static const char* const kPost[] = {"1_ins", "2_ins", "3_ins"};
        SetDispRingChar(ring3Row_[1], item.code, kPre, 6, kPost, 3);
    } else {
        Visible(ring3Row_[0], false);
        Visible(ring3Row_[1], false);
    }
    SetDispCharPosRing3();
}

// 対象の行の文字だけを表示する
void NameEntryPanel::SetDispRingChar(Lumen::MovieClip* target, const std::string& code, const char* const* pre,
                                     int preCount, const char* const* post, int postCount) {
    for (int i = 0; i < preCount; ++i) {
        for (int j = 0; j < postCount; ++j) {
            Visible(Child(target, std::string(pre[i]) + post[j]), code == pre[i]);
        }
    }
}

void NameEntryPanel::SetDispCenter(int ring) {
    std::string code;
    int count = 0;
    if (ring == 1) {
        code = Ring1(ring1Index_).code;
        count = Ring1(ring1Index_).count;
    } else if (ring == 2) {
        code = Ring2(ring1Index_, ring2Index_).code;
        count = Ring2(ring1Index_, ring2Index_).count;
    } else if (ring == 3) {
        code = Ring3List(ring1Index_, ring2Index_)[size_t(ring3Index_ - 1)];
    } else {
        Visible(center_, false);
        return;
    }

    Visible(center_, true);
    Stop(center_, "head_1");
    Lumen::MovieClip* plate = Child(center_, "plate");
    if (count == 0) {
        Visible(Child(plate, "cursor_plate"), true);
        Visible(Child(plate, "moji"), true);
        Stop(Child(plate, "moji"), code);
    } else {
        Visible(Child(plate, "cursor_plate"), false);
        Visible(Child(plate, "moji"), false);
    }
}

// リングの回転に合わせて、選択中の文字が手前の枠に来るよう文字の部品を並べる
void NameEntryPanel::SetDispCharPosRing1() {
    const int count = int(kRing1.size());
    for (int i = 1; i <= count; ++i) {
        const int moji = (i + ring1Index_ - 2) % count + 1;
        MoveTo(ring1_, "moji_" + std::to_string(moji), "plate_" + std::to_string(i));
    }
}

void NameEntryPanel::SetDispCharPosRing2() {
    const RingItem& ring1 = Ring1(ring1Index_);
    if (ring1.count == 0 || !ring2Disp_) return;
    for (int i = 1; i <= ring1.count; ++i) {
        const int moji = (i + ring2Index_ - 2) % ring1.count + 1;
        std::string name = "moji_" + std::to_string(moji);
        if (moji != ring1.count && ring1.count == 6) name = std::string(ring1.code) + std::to_string(moji) + "_ins";
        MoveTo(ring2Disp_, name, "plate_" + std::to_string(i));
    }
}

void NameEntryPanel::SetDispCharPosRing3() {
    const RingItem& ring2 = Ring2(ring1Index_, ring2Index_);
    if (ring2.count == 0 || !ring3Disp_) return;
    for (int i = 1; i <= ring2.count; ++i) {
        const int moji = (i + ring3Index_ - 2) % ring2.count + 1;
        std::string name = "moji_" + std::to_string(moji);
        if (moji != ring2.count) name = std::string(ring2.code) + std::to_string(moji) + "_ins";
        MoveTo(ring3Disp_, name, "plate_" + std::to_string(i));
    }
}

void NameEntryPanel::SetAcceptWindow(int cursor) {
    if (!accept_) return;
    accept_->GotoAndStop(cursor == 1 ? "yes" : "no");
    Stop(Child(accept_, "button_no_instance"), cursor == 1 ? "color_2p" : "color_1p");
    Stop(Child(accept_, "button_yes_instance"), cursor == 1 ? "color_1p" : "color_2p");
}

// 空欄のままなら「どんちゃん」にする
void NameEntryPanel::ChangeBlankNameToDefaultName() {
    bool blank = true;
    for (const std::string& c : name_) blank &= c == " ";
    nameDecideBlank_ = blank;
    if (blank) {
        const char* kDefault[5] = {"do", "nn", "ti", "xya", "nn"};
        for (int i = 0; i < 5; ++i) name_[i] = kDefault[i];
        SetNameBigplate();
    }
}
