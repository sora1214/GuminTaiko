#include "DaniSelectScene.hpp"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <memory>

#include "CommonParts.hpp"
#include "EntryScene.hpp"
#include "GameSettings.hpp"
#include "LoadingScene.hpp"
#include "PlayData.hpp"
#include "PlayRecord.hpp"
#include "SceneManager.hpp"
#include "SongDatabase.hpp"
#include "SoundManager.hpp"
#include "TaikoInput.hpp"
#include "TestMenu.hpp"
#include "WordList.hpp"
#include "raymath.h"

using namespace GuminTaiko;

namespace {

constexpr float kFrame = 1.0f / 60.0f;
constexpr const char* kDir = "lumen/000_default/enso_dani/dani_select/";

constexpr const char* kBankSe = "se_daniodai_v12e";
constexpr const char* kBankVoice = "voice_daniodai_v12e";
constexpr const char* kBankBgm = "bgm_daniodai_v12e";
constexpr const char* kBankCommon = "se_common_v12a";
constexpr int kSlotBgm = 0;

constexpr int kIntroSeFrame = 40;         // 導入の音を鳴らす演出のフレーム（in は 5。10 フレーム遅らせると文字と音が合う）
constexpr int kFudaSeInterval = 3;       // 段位の札が落ちてくる音の間隔（lua: wait_se_cnt 0.05 秒）
constexpr int kSlideInWait = 60;          // 合格印が出てからお題の板が出るまで（lua: wait_slidein_cnt 1 秒）
constexpr int kInputWait = 6;             // ふちを叩いてから次を受け付けるまで（lua: wait_input_cnt 0.1 秒）
constexpr int kTimerRedLimit = 9;
constexpr int kOpenAlways = 15;           // 五級〜十段は最初から選べる。玄人から上は1つ下に合格すると選べる

// 合格印（lua: tbl_DaniKanbanStampLabel。rank + 1 番目）
const char* const kStampLabels[] = {"none", "none", "stamp_red_01", "stamp_red_02", "stamp_red_03", "stamp_gold_01", "stamp_gold_02", "stamp_gold_03"};
const char* const kCourseIcons[] = {"easy", "normal", "hard", "oni", "ura"};

void Goto(Lumen::MovieClip* clip, const std::string& label, bool play = false) {
    if (!clip) return;
    if (play) clip->GotoAndPlay(label);
    else clip->GotoAndStop(label);
}

Lumen::MovieClip* Sub(Lumen::MovieClip* root, const std::string& path) { return root ? root->Find(path) : nullptr; }

void TextPath(Lumen::MovieClip* root, const std::string& path, const std::string& textName, const std::string& key) {
    if (Lumen::MovieClip* clip = Sub(root, path)) clip->SetText(textName, key);
}

void Visible(Lumen::MovieClip* clip, bool visible) {
    if (clip) clip->SetVisible(visible);
}

int JoinedPlayer() {
    for (int p = 0; p < 2; ++p) {
        if (PlayDataManager::Get().Player(p).userType != UserType::None) return p;
    }
    return 0;
}

} // namespace

// ===========================================================================
// 読み込み（lua: DaniSelectAllMain "Begin" 〜 "SetUp"、DaniSelectDaniMain "Loading"）
// ===========================================================================
void DaniSelectScene::Initialize() {
    DaniDatabase::Get().Reload();   // 作成アプリで変えたお題を読み直す
    const int player = JoinedPlayer();
    owner_ = PlayRecords::Owner(player);
    nowDani_ = PlayRecords::Get().NowDani(owner_);
    for (int level = 1; level <= kDaniLevelCount; ++level) {
        const DaniCourse* course = DaniDatabase::Get().Course(level);
        rank_[size_t(level)] = PlayRecords::Get().Dani(owner_, level).rank;
        // お題があって3曲とも譜面があり、玄人から上は1つ下に合格している。外伝は最初から選べる
        open_[size_t(level)] = course && course->Playable() && (level <= kOpenAlways || level == kDaniGaiden || nowDani_ >= level - 1);
    }
    // 最初は今の段位の1つ上（なければ近い選べる段位）（lua: SetDefaultCurrentDani）
    current_ = std::clamp(nowDani_ + 1, 1, kDaniMaxRank);   // 最初に選ぶのは次の段位（外伝にはしない）
    if (!IsOpen(current_)) {
        int best = -1;
        for (int level = 1; level <= kDaniLevelCount; ++level) {
            if (IsOpen(level) && (best < 0 || std::abs(level - current_) < std::abs(best - current_))) best = level;
        }
        current_ = std::max(1, best);
    }

    for (const char* bank : {kBankSe, kBankVoice, kBankBgm, kBankCommon}) SoundManager::Get().Preload(bank);
    stage_.SetTextFace(FontFace::Large);
    if (!stage_.Load(std::string(kDir) + "dani_select")) {
        TraceLog(LOG_WARNING, "DaniSelectScene: 段位選択画面を読み込めません");
        return;
    }
    stage_.LoadMovie(std::string(kDir) + "dani_select_window", "window_instance");
    stage_.LoadMovie("lumen/000_default/enso_dani/loading_dani/loading_dani_intro", "introduction_instance");
    stage_.LoadMovie("lumen/000_default/common/timer", "timer_instance");
    stage_.LoadMovie("lumen/000_default/common/name_plate", "plate_1p_instance");
    main_ = stage_.GetMovieClip("main");
    boards_ = stage_.GetMovieClip("main/board_all/normal");
    intro_ = stage_.GetMovieClip("introduction_instance/main");
    window_ = stage_.GetMovieClip("window_instance/main");
    timeCount_ = stage_.GetMovieClip("timer_instance/timer_main_instance/time_count_instance");
    loaded_ = main_ && boards_;
    if (!loaded_) return;
    for (const char* name : {"option_instance", "dummy_option_icon_1p", "qricon_instance"}) Visible(stage_.GetMovieClip(name), false);
    Visible(window_, false);

    // ネームプレート・どんちゃん（lua: InitNamePlate / InitDon3D）
    CommonParts::SetNamePlate(stage_.GetMovieClip("plate_1p_instance"), player);
    Visible(stage_.GetMovieClip("plate_1p_instance"), false);
    const PlayerData& data = PlayDataManager::Get().Player(player);
    don3d_.SetCostume(0, DonModel::FromEntry(data.costume, data.kigurumi, data.dress));
    don3d_.Load();
    donTexture_ = LoadRenderTexture(1920, 1080);
    SetTextureFilter(donTexture_.texture, TEXTURE_FILTER_BILINEAR);
    Lumen::SetExternalTexture("don1p", &donTexture_.texture, true);
    Visible(stage_.GetMovieClip("main/don_1p"), false);

    // タイマー（選曲画面と同じく、テストモードで切っていれば止めたまま出す）
    timerEnabled_ = GameSettings::Get().Value(TestMenu::kSongSelectTimerItem) != 0;
    CommonParts::SetTimerCount(timeCount_, int(timer_), kTimerRedLimit);

    // 導入の演出（lua: DaniSelectIntroductionMain:PlayIntroduction）
    // 音は演出の文字（段・位・道・場）に合わせて少し遅らせて鳴らす（Update）
    Goto(intro_, "in", true);
    SetState(State::Intro);
}

void DaniSelectScene::Finalize() {
    SoundManager::Get().StopAll();
    if (donTexture_.id != 0) UnloadRenderTexture(donTexture_);
    donTexture_ = RenderTexture2D{};
    don3d_.Unload();
    Lumen::ClearExternalTextures();
}

bool DaniSelectScene::IsOpen(int level) const { return level >= 1 && level <= kDaniLevelCount && open_[size_t(level)]; }

const char* DaniSelectScene::StampLabel(int level) const { return kStampLabels[std::clamp(rank_[size_t(level)], 0, 7)]; }

// ===========================================================================
// お題の板（lua: DaniDispData）
// ===========================================================================
void DaniSelectScene::SetDetail(Lumen::MovieClip* board, int level) {
    const DaniCourse* course = DaniDatabase::Get().Course(level);
    Lumen::MovieClip* normal = Sub(board, "normal");
    if (!normal) return;
    Goto(normal, DaniLabel(level));
    const DaniRecord record = PlayRecords::Get().Dani(owner_, level);
    // 板ごとに文言のキーを分ける（2枚の板が別の段位を出すことがある）
    const std::string tag = "dani_" + board->Name() + "_";

    // ---- 課題曲 ----
    for (int s = 0; s < kDaniSongCount; ++s) {
        const std::string set = "set_song_" + std::to_string(s + 1);
        Goto(Sub(normal, set + "/label"), "song_no_" + std::to_string(s + 1));
        const DaniSong* song = course ? &course->songs[size_t(s)] : nullptr;
        const SongInfo* info = song && song->uniqueId >= 0 ? SongDatabase::Get().FindSong(song->uniqueId) : nullptr;
        const bool secret = song && song->hidden && record.arrival <= s;
        TextPath(normal, set + "/txt_song_name", "txt_song_name", secret ? "dani_select_song_secret" : info ? "song_" + info->id : "");
        // 曲名の上の小さい文字（作曲者などのサブタイトル）は出さない（本家のお題一覧は曲名だけ）
        Visible(Sub(normal, set + "/txt_song_ruby_name"), false);
        const int star = info && song ? info->stars[size_t(song->course)] : 0;
        Goto(Sub(normal, set + "/song_diff"), star >= 1 && star <= 10 ? "diff_" + std::to_string(star) : "none");
        Goto(Sub(normal, set + "/song_diff_icon"), kCourseIcons[song ? std::clamp(song->course, 0, 4) : 3]);
    }

    // ---- 合格条件 ----
    TextPath(normal, "txt_clear_label", "txt_clear_label", "dani_select_clear_requirement");
    TextPath(normal, "set_gauge/txt_name_gauge", "txt_name_gauge", "clear_theme_soul_gauge");
    char text[64];
    std::snprintf(text, sizeof(text), "%d ％以上", course ? course->gaugeRed : 0);
    WordList::Get().Set(tag + "gauge", text);
    TextPath(normal, "set_gauge/txt_num_border_gauge", "txt_num_border_gauge", tag + "gauge");
    for (int e = 0; e < kDaniExamCount; ++e) {
        const std::string set = "set_score_" + std::to_string(e + 1);
        const DaniExam exam = course ? course->exams[size_t(e)] : DaniExam();
        if (exam.type == DaniExamType::None) {
            Goto(Sub(normal, set), "none");
            continue;
        }
        TextPath(normal, set + "/txt_theme_name", "txt_theme_name", DaniExamTextKey(exam.type));
        if (exam.total) {
            Goto(Sub(normal, set), "song_no_1");
            Goto(Sub(normal, set + "/set_theme_1/theme_label"), "song_total");
        } else {
            Goto(Sub(normal, set), "song_no_3");
            for (int s = 0; s < kDaniSongCount; ++s) {
                Goto(Sub(normal, set + "/set_theme_" + std::to_string(s + 1) + "/theme_label"), "song_no_" + std::to_string(s + 1));
            }
        }
        for (int s = 0; s < (exam.total ? 1 : kDaniSongCount); ++s) {
            const std::string theme = set + "/set_theme_" + std::to_string(s + 1);
            std::snprintf(text, sizeof(text), exam.LessThan() ? "%d 未満" : "%d 以上", exam.red[size_t(s)]);
            const std::string key = tag + std::to_string(e) + "_" + std::to_string(s);
            WordList::Get().Set(key, text);
            TextPath(normal, theme + "/txt_need_score", "txt_need_score", key);
            // 自己ベスト（挑戦したことがあれば出す）
            if (record.rank > 0) {
                const int best = exam.total ? [&] {
                    DaniRun run;
                    run.songs = record.songs;
                    return DaniExamValue(exam, run, 0);
                }() : record.songs[size_t(s)].Value(exam.type);
                WordList::Get().Set(key + "_best", std::to_string(best));
                TextPath(normal, theme + "/txt_name_bestscore", "txt_name_bestscore", "requirement_best_score");
                TextPath(normal, theme + "/txt_num_bestscore", "txt_num_bestscore", key + "_best");
                Goto(Sub(normal, theme), "bestscore_on", true);
            } else {
                Goto(Sub(normal, theme), "init");
            }
        }
    }
    if (record.rank > 0) {
        std::snprintf(text, sizeof(text), "%d ％", record.gauge);
        WordList::Get().Set(tag + "gauge_best", text);
        TextPath(normal, "set_gauge/txt_bestscore_name", "txt_bestscore_name", "requirement_best_score");
        TextPath(normal, "set_gauge/txt_bestscore_num", "txt_bestscore_num", tag + "gauge_best");
        Goto(Sub(normal, "set_gauge"), "bestscore_on", true);
    } else {
        Goto(Sub(normal, "set_gauge"), "init");
    }
}

void DaniSelectScene::SetDetailStamp(const char* name, int level) { Goto(Sub(main_, name), StampLabel(level)); }

// ===========================================================================
// 進行
// ===========================================================================
void DaniSelectScene::Update(float deltaTime) {
    if (!loaded_) {
        if (TaikoInput::AnyDon() || TaikoInput::IsBackPressed()) {
            SceneManager::GetInstance().ChangeScene(std::make_unique<EntryScene>());
        }
        return;
    }
    CommonParts::ToggleAutoPlay();   // F3: オートプレイの入り切り
    const int p = JoinedPlayer();
    input_.don = input_.don || TaikoInput::IsDon(p);
    input_.kaLeft = input_.kaLeft || TaikoInput::IsKaLeft(p);
    input_.kaRight = input_.kaRight || TaikoInput::IsKaRight(p);
    input_.back = input_.back || TaikoInput::IsBackPressed();
    accumulator_ = std::min(accumulator_ + deltaTime, kFrame * 4.0f);
    bool first = true;
    while (accumulator_ >= kFrame) {
        accumulator_ -= kFrame;
        if (first) {
            Step();
            input_ = Input();
        }
        first = false;
        stage_.Update(kFrame);
        // 導入の音: 太鼓の音（0.95・1.45・1.95・2.4 秒）が文字の出きる時に合うよう、演出の in から数えて鳴らす
        if (!introSePlayed_ && intro_ && intro_->CurrentFrame() >= kIntroSeFrame) {
            introSePlayed_ = true;
            SoundManager::Get().Play(kBankSe, "intro");
        }
    }
}

void DaniSelectScene::SetState(State state) {
    state_ = state;
    stateFrame_ = 0;
}

void DaniSelectScene::Step() {
    // タイマー（段位を選んでいる間と確認の間だけ進める）
    if (timerEnabled_ && timerRunning_ && timer_ > 0.0f) {
        timer_ = std::max(0.0f, timer_ - kFrame);
        if (timer_ <= 0.0f) SoundManager::Get().Play(kBankCommon, "don_big");
    }
    const int shown = int(std::ceil(timer_));
    if (shown != timerShown_) {
        timerShown_ = shown;
        CommonParts::SetTimerCount(timeCount_, shown, kTimerRedLimit);
    }
    if (timeCount_) Visible(timeCount_->Child("shadow"), !timerRunning_ || !timerEnabled_);
    const bool timeUp = timerEnabled_ && timer_ <= 0.0f;

    switch (state_) {
    case State::Intro:
        // 導入の演出（lua: Is_EndAnimation）
        if (stateFrame_ > 0 && (!intro_ || !intro_->IsPlay())) {
            Goto(intro_, "out", true);
            // 段位の札を落とす（lua: DaniSelectDaniMain "Loading"）
            SetDetail(stage_.GetMovieClip("main/board_detail_2"), current_);
            SetDetailStamp("stamp_detail_2", current_);
            for (int level = 1; level <= 20; ++level) {
                Goto(Sub(boards_, "board_" + std::to_string(level)), IsOpen(level) ? "init" : "lock");
            }
            for (int level = 1; level <= kDaniLevelCount; ++level) {
                const std::string stamp = "stamp_" + std::to_string(level);
                Goto(Sub(boards_, stamp + "/middle_stamp_anime_1"), StampLabel(level));
                Goto(Sub(boards_, stamp + "/middle_stamp_anime_2"), StampLabel(level));
                Goto(Sub(boards_, stamp), "in_stamp", true);
            }
            Goto(main_, "in", true);
            Goto(boards_, "in_board", true);
            SetState(State::BoardIn);
            return;
        }
        break;

    case State::BoardIn:
        if (stateFrame_ % kFudaSeInterval == 0) SoundManager::Get().Play(kBankSe, "fuda");
        if (stateFrame_ > 0 && !boards_->IsPlay()) {
            bool anyStamp = false;
            for (int level = 1; level <= kDaniLevelCount; ++level) anyStamp = anyStamp || rank_[size_t(level)] >= 2;
            if (anyStamp) SoundManager::Get().Play(kBankSe, "stamp");
            SetState(anyStamp ? State::SlideInWait : State::SlideIn);
            return;
        }
        break;

    case State::SlideInWait:
        if (stateFrame_ >= kSlideInWait) {
            SetState(State::SlideIn);
            return;
        }
        break;

    case State::SlideIn:
        if (stateFrame_ == 0) {
            // お題の板とどんちゃんが出てくる（lua: "SlideInWait"）
            Goto(main_, "in_left", true);
            SoundManager::Get().Play(kBankSe, "plate");
            Lumen::MovieClip* don = stage_.GetMovieClip("main/don_1p");
            Visible(don, true);
            Goto(don, "framein", true);
            SoundManager::Get().Play(kBankVoice, "odai_choose");
            Visible(stage_.GetMovieClip("plate_1p_instance"), true);
            timerRunning_ = true;
        } else if (!main_->IsPlay()) {
            SoundManager::Get().PlaySlot(kBankBgm, "primal_loop", kSlotBgm);
            Goto(boards_, DaniLabel(current_), true);
            SetState(State::Main);
            return;
        }
        break;

    case State::Main:
        if (inputWait_ > 0) --inputWait_;
        if (input_.back) {
            // ESC: エントリー画面へ戻る
            SoundManager::Get().Play(kBankCommon, "primal_cancel_c");
            SetState(State::End);
            SceneManager::GetInstance().ChangeScene(
                std::make_unique<LoadingScene>([] { return std::unique_ptr<Scene>(std::make_unique<EntryScene>()); }), true);
            return;
        }
        if ((input_.don || timeUp) && IsOpen(current_)) {
            SoundManager::Get().Play(kBankCommon, "don_c");
            OpenConfirm();
            return;
        }
        if (inputWait_ == 0 && (input_.kaLeft || input_.kaRight)) {
            SoundManager::Get().Play(kBankCommon, "katsu_c");
            MoveCursor(input_.kaLeft ? -1 : 1);
        }
        break;

    case State::ConfirmIn:
        // 出る動きは wait_challenge の手前で止まる（止まったか、ラベルに着いたか、1秒たったら選べるようにする）
        if (!window_ || window_->CurrentFrame() >= window_->LabelFrame("wait_challenge") ||
            (stateFrame_ > 1 && !window_->IsPlay()) || stateFrame_ >= 60) {
            if (!window_) {
                SetState(State::Confirm);
                return;
            }
            window_->GotoAndStop("wait_challenge");
            SetState(State::Confirm);
        }
        break;

    case State::Confirm:
        if (timeUp) {
            confirmCursor_ = 0;
            CloseConfirm(true);
            return;
        }
        if (input_.back) {
            CloseConfirm(false);
            return;
        }
        if (input_.kaLeft || input_.kaRight) {
            confirmCursor_ = input_.kaLeft ? 0 : 1;
            SoundManager::Get().Play(kBankCommon, "katsu_c");
            Goto(Sub(window_, "window/button_select"), confirmCursor_ == 0 ? "left" : "right");
        } else if (input_.don) {
            CloseConfirm(confirmCursor_ == 0);
        }
        break;

    case State::ConfirmOut:
        if (!window_ || !window_->IsPlay() || stateFrame_ > 90) {
            Visible(window_, false);
            SetState(State::Main);
        }
        break;

    case State::Decided:
        if (stateFrame_ >= 90) {
            Decide();
            return;
        }
        break;

    case State::End:
        return;
    }
    ++stateFrame_;
}

// 左右のふち（lua: MoveCursor / MoveDaniKanbanLabel / SetDaniDataAll）。選べない段位は飛ばし、端で反対側へ回る
void DaniSelectScene::MoveCursor(int direction) {
    const int previous = current_;
    int next = current_;
    for (int step = 0; step < kDaniLevelCount; ++step) {
        next = (next - 1 + direction + kDaniLevelCount) % kDaniLevelCount + 1;
        if (IsOpen(next)) break;
    }
    if (next == current_) return;
    current_ = next;
    inputWait_ = kInputWait;
    Goto(main_, direction < 0 ? "move_right" : "move_left", true);
    Goto(boards_, DaniLabel(current_), true);
    SetDetail(stage_.GetMovieClip("main/board_detail_1"), current_);
    SetDetail(stage_.GetMovieClip("main/board_detail_2"), previous);
    SetDetailStamp("stamp_detail_1", current_);
    SetDetailStamp("stamp_detail_2", previous);
}

// 「このお題に挑戦するのカッ？」（lua: DaniSelectConfirmationMain "Loading"）
void DaniSelectScene::OpenConfirm() {
    if (!window_) {
        Decide();
        return;
    }
    Visible(window_, true);
    TextPath(window_, "window/text_challenge_info", "text_challenge_info", "dani_select_confirmation");
    TextPath(window_, "window/button_select/text_cursor_left", "text_cursor", "dani_select_confirmation_decide");
    TextPath(window_, "window/button_select/text_cursor_right", "text_cursor", "dani_select_confirmation_cancel");
    Visible(Sub(window_, "window/button_option"), false);   // 段位道場の演奏オプションは移植していない
    Goto(Sub(window_, "window/caution_info"), "off");
    confirmCursor_ = 0;
    Goto(Sub(window_, "window/button_select"), "left");
    window_->GotoAndPlay("in_challenge");
    // 残りが 30 秒より少なければ 30 秒にする（lua: timer_:SetCount(30)）
    if (timer_ < 30.0f) timer_ = 30.0f;
    SoundManager::Get().Play(kBankVoice, "select");
    SetState(State::ConfirmIn);
}

void DaniSelectScene::CloseConfirm(bool decide) {
    if (decide) {
        SoundManager::Get().Play(kBankCommon, "don_c");
        SoundManager::Get().Play(kBankVoice, "decide");
        SoundManager::Get().Play(kBankSe, rank_[size_t(current_)] >= 2 ? "select_memorable" : "select_unmemolable");
        Goto(Sub(window_, "window/button_select/cursor"), "decide", true);
        Goto(Sub(window_, "window/button_select/blink"), "decide", true);
        window_->GotoAndPlay("out_challenge");
        timerRunning_ = false;
        SetState(State::Decided);
    } else {
        SoundManager::Get().Play(kBankCommon, "primal_cancel_c");
        window_->GotoAndPlay("cancel_challenge");
        SetState(State::ConfirmOut);
    }
}

// 挑戦を始める（lua: "End" → nextMode = kEnsoGame）。1曲目の譜面で演奏へ
void DaniSelectScene::Decide() {
    const DaniCourse* course = DaniDatabase::Get().Course(current_);
    if (!course || !course->Playable()) {
        SetState(State::Main);
        return;
    }
    PlayDataManager& pd = PlayDataManager::Get();
    DaniRun& run = pd.Dani();
    run = DaniRun();
    run.active = true;
    run.level = current_;
    pd.SetSelectedSong(course->songs[0].uniqueId, "dani");
    for (int p = 0; p < 2; ++p) pd.SetSelectedCourse(p, course->songs[0].course);
    SoundManager::Get().StopSlot(kSlotBgm);
    SetState(State::End);
    SceneManager::GetInstance().ChangeScene(std::make_unique<LoadingScene>(LoadingScene::Next::Enso), true);
}

// ===========================================================================
// 描画
// ===========================================================================
void DaniSelectScene::Draw() {
    ClearBackground(BLACK);
    if (!loaded_) {
        DrawText("dani select: failed to load", 40, 40, 40, RAYWHITE);
        return;
    }
    RenderDon();
    stage_.Draw();
    CommonParts::DrawAutoBadge(117.0f, 1023.0f, 1.0f);   // 選曲画面で演奏オプションのアイコンが並ぶところ（左下）
}

void DaniSelectScene::RenderDon() {
    if (!don3d_.IsLoaded() || donTexture_.id == 0) return;
    don3d_.PlayLoop("don_result_clear_loop", float(GetTime()));
    Camera3D camera{};
    camera.target = Vector3{0.0f, 0.14f, 0.0f};
    camera.position = Vector3{0.0f, 0.2f, 1.7f};
    camera.up = Vector3{0.0f, 1.0f, 0.0f};
    camera.fovy = 2.0f * 1.7f * std::tan(11.0f * DEG2RAD);
    camera.projection = CAMERA_ORTHOGRAPHIC;
    BeginTextureMode(donTexture_);
    ClearBackground(Color{0, 0, 0, 0});
    BeginMode3D(camera);
    don3d_.Draw(0, don3d_.Expression(), MatrixRotateY(30.0f * DEG2RAD));
    EndMode3D();
    EndTextureMode();
}
