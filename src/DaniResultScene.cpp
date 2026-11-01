#include "DaniResultScene.hpp"

#include <algorithm>
#include <cmath>
#include <memory>

#include "CommonParts.hpp"
#include "EnsoScene.hpp"
#include "EntryScene.hpp"
#include "GameFont.hpp"
#include "PlayData.hpp"
#include "PlayRecord.hpp"
#include "SceneManager.hpp"
#include "SongDatabase.hpp"
#include "SoundManager.hpp"
#include "TaikoInput.hpp"
#include "raymath.h"

using namespace GuminTaiko;

namespace {

constexpr float kFrame = 1.0f / 60.0f;
constexpr const char* kDir = "lumen/000_default/enso_dani/";

constexpr const char* kBankBgm = "bgm_daniresult_v12e";
constexpr const char* kBankSe = "se_daniresult_v12e";
constexpr const char* kBankVoice = "voice_daniresult_v12e";
constexpr const char* kBankCommon = "se_common_v12a";
constexpr const char* kBankResult = "se_result_v12a";
constexpr int kSlotBgm = 0;
constexpr int kSlotLoop = 1;                 // 数え上げの音

// lua の定数
constexpr int kWaitTime = 30;                // 数え終えてから入力を受け付けるまで（0.5 秒）
constexpr int kWaitDetail = 12;              // お題を1つ見せたあとの待ち（0.2 秒）
constexpr int kWaitEndTime = 30 * 60;        // 入力がなくても進むまで（30 秒）
constexpr int kGaugeSpeed = 2;               // 魂ゲージが 1% 進む間隔（フレーム、この値より大きくなったら進む）
constexpr int kDetailGaugeSpeed = 1;         // お題の棒が 1 進む間隔
constexpr int kNumInWait = 60;               // お題の数が出てからの待ち
constexpr int kWaitShodan = 30 * 60;
constexpr int kWaitCongrats = 180;
constexpr int kWaitOshimaiTime = 7;          // ゲームオーバーの「また遊んでね」（秒）
constexpr int kWaitCopyrightTime = 3;

const char* const kCourseLabels[] = {"easy", "normal", "hard", "oni", "ura"};
const char* const kSongLabels[] = {"1st", "2nd", "3rd"};

void Goto(Lumen::MovieClip* clip, const std::string& label, bool play = false) {
    if (!clip) return;
    if (play) clip->GotoAndPlay(label);
    else clip->GotoAndStop(label);
}

Lumen::MovieClip* Sub(Lumen::MovieClip* root, const std::string& path) { return root ? root->Find(path) : nullptr; }

void Visible(Lumen::MovieClip* clip, bool visible) {
    if (clip) clip->SetVisible(visible);
}

// 数字（lua: DaniResultSongScore）。桁数のラベル（digitN）にして、一の位から digit1, digit2 …。
// 上の桁の 0 は出さない（none）。maxDigits が 0 なら値の桁数ちょうどにする
void SetCounter(Lumen::MovieClip* clip, int maxDigits, int value) {
    if (!clip) return;
    const std::string digits = std::to_string(std::max(0, value));
    if (maxDigits <= 0) maxDigits = int(digits.size());
    clip->GotoAndStop("digit" + std::to_string(maxDigits));
    for (int d = 1; d <= maxDigits; ++d) {
        const int index = int(digits.size()) - d;
        Goto(clip->Child("digit" + std::to_string(d)), index >= 0 ? "num" + std::string(1, digits[size_t(index)]) : "none");
    }
}

// 段位の文字（lua: SetShodanText。w_/g_ の番号）
std::string ShoudanLeft(int level) {
    if (level <= 5) return TextFormat("%02d", 6 - level);       // 五級〜一級: 五〜一
    if (level == 6) return "11";                                 // 初
    if (level <= 15) return TextFormat("%02d", level - 5);      // 二〜十
    return TextFormat("%02d", level - 2);                        // 玄人・名人・超人・達人
}
std::string ShoudanRight(int level) { return level <= 5 ? "12" : level <= 15 ? "13" : "18"; }   // 級・段・人

} // namespace

// ===========================================================================
// 読み込み（lua: DaniResult "Init"、DaniResultMain "Begin" 〜 "SetUp"）
// ===========================================================================
void DaniResultScene::Initialize() {
    PlayDataManager& pd = PlayDataManager::Get();
    run_ = pd.Dani();
    level_ = run_.level;
    course_ = DaniDatabase::Get().Course(level_);
    int player = 0;
    for (int p = 0; p < 2; ++p) {
        if (pd.Player(p).userType != UserType::None) {
            player = p;
            break;
        }
    }
    const std::string owner = PlayRecords::Owner(player);

    for (const char* bank : {kBankBgm, kBankSe, kBankVoice, kBankCommon, kBankResult, "bgm_common_v12a", "voice_common_v12a"}) {
        SoundManager::Get().Preload(bank);
    }

    if (!course_ || !stage_.Load(std::string(kDir) + "result/dani_result")) {
        TraceLog(LOG_WARNING, "DaniResultScene: 段位道場のリザルト画面を読み込めません");
        return;
    }
    stage_.SetTextFace(FontFace::Large);

    // ---- 成績（lua: SetMaxOdaiNum / SetMaxReachNum / SetOdaiResult） ----
    reach_ = std::clamp(run_.arrival, 0, kDaniSongCount);
    gaugeValue_ = std::clamp(int(run_.gauge * 100.0 + 1e-6), 0, 100);
    for (int i = 0; i < kDaniExamCount; ++i) {
        if (course_->exams[size_t(i)].type != DaniExamType::None) examOrder_[size_t(examCount_++)] = i;
    }
    int ok = 0, good = 0;
    // 魂ゲージ
    const int gaugeCheck = gaugeValue_ >= course_->gaugeRed ? (gaugeValue_ >= course_->gaugeGold ? 2 : 1) : 0;
    int grades[kDaniExamCount + 1] = {};
    grades[0] = gaugeCheck;
    for (int k = 0; k < examCount_; ++k) {
        const DaniExam& exam = course_->exams[size_t(examOrder_[size_t(k)])];
        int grade = 2;
        if (reach_ < kDaniSongCount || run_.failed) grade = 0;   // 3曲たどり着けなかったら不合格
        for (int s = 0; s < (exam.total ? 1 : kDaniSongCount) && grade > 0; ++s) {
            grade = std::min(grade, DaniExamGrade(exam, DaniExamValue(exam, run_, s), s));
        }
        grades[k + 1] = grade;
    }
    for (int k = 0; k <= examCount_; ++k) {
        if (grades[k] == 1) ++ok;
        else if (grades[k] == 2) ++good;
    }
    const int check = good == examCount_ + 1 ? 2 : ok + good == examCount_ + 1 ? 1 : 0;
    int okNum = 0, badNum = 0;
    for (const DaniSongResult& r : run_.songs) {
        okNum += r.ok;
        badNum += r.bad;
    }
    const int combo = badNum == 0 ? (okNum == 0 ? 2 : 1) : 0;   // 0: なし 1: フルコンボ 2: ドンダフル
    result_ = check == 0 ? 0 : (check == 2 ? 4 : 1) + combo;

    // ---- 記録（カードだけ。オートでは残さない）と昇段（lua: CheckReward） ----
    const DaniRecord before = PlayRecords::Get().Dani(owner, level_);
    prevNowDani_ = PlayRecords::Get().NowDani(owner);
    // 外伝は腕前の段位ではないので、合格しても昇段の演出はない
    shoudanFlag_ = result_ > 0 && before.rank < result_ + 1 && level_ <= kDaniMaxRank;
    congrats_ = shoudanFlag_ && level_ == kDaniMaxRank;
    if (!EnsoScene::autoUsed) {
        DaniRecord record;
        record.rank = result_ + 1;
        record.gauge = gaugeValue_;
        record.arrival = reach_;
        record.songs = run_.songs;
        PlayRecords::Get().AddDani(owner, level_, record);
    }

    // ---- 画面 ----
    stage_.LoadMovie("lumen/000_default/gameover/GameOver", "dummy_gameover");
    stage_.LoadMovie(std::string(kDir) + "result/dani_shoudan", "dummy_shoudan");
    stage_.LoadMovie(std::string(kDir) + "result/dani_result_congrats", "dummy_congrats");
    stage_.LoadMovie(std::string(kDir) + "enso/tamashiigauge/tamashii_gauge", "total_mc/dummy_tamashii_gauge");
    for (int k = 0; k < examCount_; ++k) {
        stage_.LoadMovie(std::string(kDir) + "result/dani_result_detail", TextFormat("total_detail_0%d_mc/dummy_detail", k + 1));
    }
    stage_.LoadMovie("lumen/000_default/common/name_plate", "plate_1p_instance");
    stage_.LoadMovie("lumen/000_default/common/name_plate", "dummy_shoudan/nameplate_instance_1");

    main_ = stage_.GetMovieClip("main_mc");
    if (!main_) return;
    loaded_ = true;
    main_->GotoAndStop("init");
    for (const char* name : {"dummy_folder", "dummy_option_icon_1p", "dummy_qrcode_image_window", "dummy_qrcode_image_timer"}) {
        Visible(main_->Find(name), false);
    }
    for (int k = examCount_; k < kDaniExamCount; ++k) Visible(main_->Find(TextFormat("total_detail_0%d_mc", k + 1)), false);
    shoudan_ = main_->Find("dummy_shoudan");
    Goto(shoudan_, "shoudan_start");
    Visible(shoudan_, false);
    Goto(main_->Find("dummy_congrats"), "start");
    Visible(main_->Find("dummy_congrats"), false);
    if (Lumen::MovieClip* gameOver = main_->Find("dummy_gameover")) {
        Goto(gameOver->Child("main"), "init");
        gameOverCurtain_ = Sub(gameOver, "main/end_curtain_mc");
        Goto(gameOverCurtain_, "oshimai_init");
    }
    Goto(main_->Find("save_mc"), "off");
    Goto(main_->Find("com_dani_mc"), DaniLabel(level_));
    for (const char* name : {"stamp_anm_gold_03_mc", "stamp_anm_gold_02_mc", "stamp_anm_gold_01_mc", "stamp_anm_red_03_mc",
                             "stamp_anm_red_02_mc", "stamp_anm_red_01_mc", "stamp_anm_fail_mc"}) {
        Goto(main_->Find(name), "init");
    }

    CommonParts::SetNamePlate(main_->Find("plate_1p_instance"), player);
    CommonParts::SetNamePlate(Sub(shoudan_, "nameplate_instance_1"), player);

    SetupSongs();
    SetupTotal();
    for (int k = 0; k < examCount_; ++k) SetupDetail(k);
    SetupShoudan();

    // どんちゃん
    const PlayerData& data = pd.Player(player);
    don3d_.SetCostume(0, DonModel::FromEntry(data.costume, data.kigurumi, data.dress));
    don3d_.Load();
    donTexture_ = LoadRenderTexture(1920, 1080);
    SetTextureFilter(donTexture_.texture, TEXTURE_FILTER_BILINEAR);
    Lumen::SetExternalTexture("don1p", &donTexture_.texture, true);
    don_.SetLoopAnimation("result_clear_loop");
    Goto(main_->Find("don_1p"), "framein", true);

    // lua: StartWait → SongResult
    SoundManager::Get().PlaySlot(kBankBgm, "primal_loop", kSlotBgm);
    SoundManager::Get().Play(kBankVoice, "announce");
    SetState(State::Songs);
    main_->GotoAndPlay("dani");
    SoundManager::Get().Play(kBankSe, "partial_intro");
}

// 各曲の板（lua: DaniResultSongBase:SetUp / InitSongData / InitScoreData）
void DaniResultScene::SetupSongs() {
    for (int i = 0; i < kDaniSongCount; ++i) {
        Lumen::MovieClip* board = main_->Find(TextFormat("song_board_0%d_mc", i + 1));
        if (!board) continue;
        const DaniSong& ds = course_->songs[size_t(i)];
        const SongInfo* info = SongDatabase::Get().FindSong(ds.uniqueId);
        const bool unreach = i >= reach_;
        const bool hidden = unreach && ds.hidden;
        const std::string id = info && !hidden ? info->id : "";
        if (Lumen::MovieClip* c = board->Find("song_board_name_tx_mc")) c->SetText("tx_songname", hidden ? "？？？" : "song_" + id);
        // 曲名の上の小さい文字（作曲者などのサブタイトル）は出さない（本家の段位リザルトは曲名だけ）
        if (Lumen::MovieClip* c = board->Find("txt_song_ruby_name")) c->SetVisible(false);
        if (Lumen::MovieClip* c = board->Find("song_board_unreach_tx_mc")) c->SetText("tx_unreach", "dani_result_unreach");
        Goto(board->Find("song_board_label_mc"), kSongLabels[i]);
        Goto(board->Find("song_board_base_mc"), kSongLabels[i]);
        const int course = std::clamp(ds.course, 0, 4);
        Goto(board->Find("song_board_diff_mc"), kCourseLabels[course]);
        const int stars = info ? std::clamp(info->stars[size_t(course)], 1, 11) : 1;
        Goto(board->Find("song_board_diff_num_mc"), "diff_" + std::to_string(stars));
        const DaniSongResult& r = run_.songs[size_t(i)];
        SetCounter(board->Find("count_ryo"), 4, unreach ? 0 : r.good);
        SetCounter(board->Find("count_ka"), 4, unreach ? 0 : r.ok);
        SetCounter(board->Find("count_fuka"), 4, unreach ? 0 : r.bad);
        SetCounter(board->Find("count_renda"), 4, unreach ? 0 : r.roll);
        // 未到達（lua: UnreachSkip）
        Goto(board, unreach ? "end_unreach" : "init");
    }
}

// 総合（lua: DaniResultTotalBase:SetUp / InitGauge / InitScore）
void DaniResultScene::SetupTotal() {
    Lumen::MovieClip* total = main_->Find("total_mc");
    if (!total) return;
    int score = 0, good = 0, ok = 0, bad = 0, roll = 0, combo = 0;
    for (int i = 0; i < kDaniSongCount; ++i) {
        const DaniSongResult& r = run_.songs[size_t(i)];
        score += r.score;
        good += r.good;
        ok += r.ok;
        bad += r.bad;
        roll += r.roll;
        combo = std::max(combo, r.combo);
    }
    if (Lumen::MovieClip* c = total->Find("txt_theme_name")) c->SetText("tx_detail_label", "clear_theme_soul_gauge");
    if (Lumen::MovieClip* c = total->Find("total_score_mc")) c->SetText("tx_score_label", "clear_theme_score");
    Goto(total->Find("total_score_mc/best_score_mc"), "init");
    SetCounter(total->Find("total_score_mc/total_score_front_mc"), 7, score);
    SetCounter(total->Find("total_score_mc/total_score_back_mc"), 7, score);
    SetCounter(total->Find("total_count_01_mc/total_ryo"), 4, good);
    SetCounter(total->Find("total_count_01_mc/total_ka"), 4, ok);
    SetCounter(total->Find("total_count_01_mc/total_fuka"), 4, bad);
    SetCounter(total->Find("total_count_02_mc/total_renda"), 4, roll);
    SetCounter(total->Find("total_count_02_mc/total_combo"), 4, combo);
    SetCounter(total->Find("total_count_02_mc/total_hit"), 4, good + ok + roll);

    // 魂ゲージ（段位リザルト用の見た目にし、0 から数え上げる）
    Lumen::MovieClip* root = total->Find("dummy_tamashii_gauge");
    Goto(root, "dani_result");
    gauge_ = Sub(root, "gauge_mc");
    Goto(gauge_, "border_" + std::to_string(std::clamp(course_->gaugeRed, 0, 100) / 2));
    Goto(Sub(gauge_, "tamashii_mc"), "not_clear");
    Goto(Sub(gauge_, "gauge_border"), "dani_result");
    if (Lumen::MovieClip* border = Sub(gauge_, "gauge_border")) border->SetText("tx_border", std::to_string(course_->gaugeRed) + "%以上");
    Goto(Sub(gauge_, "gauge_lamp_mc"), "gage_0");
    Goto(Sub(gauge_, "gauge_bg"), "bg_1p");
    Goto(Sub(gauge_, "gauge_lamp_mc/lamp"), "lamp_1p");
    Goto(Sub(gauge_, "gauge_lamp_mc/gauge_result_num_mc"), "init");
    for (const char* layer : {"gauge_result_add_mc", "gauge_result_front_mc", "gauge_result_back_mc"}) {
        SetCounter(Sub(gauge_, std::string("gauge_lamp_mc/gauge_result_num_mc/gauge_result_num_set_mc/") + layer), 3, gaugeValue_);
    }
}

// お題の結果（lua: DaniResultDetailBase:Init / InitDetailAll / InitDetail）
void DaniResultScene::SetupDetail(int index) {
    const DaniExam& exam = course_->exams[size_t(examOrder_[size_t(index)])];
    Lumen::MovieClip* detail = main_->Find(TextFormat("total_detail_0%d_mc/dummy_detail/detail_mc", index + 1));
    if (!detail) return;
    if (Lumen::MovieClip* c = detail->Find("txt_theme_name")) c->SetText("tx_detail_label", DaniExamTextKey(exam.type));
    const bool down = exam.LessThan();
    const int songs = exam.total ? 1 : std::max(1, reach_);
    detail->GotoAndStop(exam.total ? "all" : kSongLabels[songs - 1]);
    for (int s = 0; s < songs; ++s) {
        const int value = DaniExamValue(exam, run_, s);
        const int red = exam.red[size_t(s)];
        int gauge = red == 0 ? 100 * value : int(int64_t(100) * value / red);
        if (!down && red == 0) gauge = 100;
        gauge = std::min(gauge, 100);
        if (down) gauge = std::max(0, 100 - gauge);
        detailTarget_[size_t(s)] = gauge;
        detailGauge_[size_t(s)] = down ? 100 : 0;

        const std::string prefix = exam.total ? "score_all_mc" : TextFormat("score_0%d_mc", s + 1);
        const std::string size = exam.total ? "l" : "m";
        Lumen::MovieClip* score = detail->Find(prefix);
        if (!score) continue;
        score->GotoAndStop("wait");
        score->SetText("tx_border", std::to_string(red) + (down ? " 未満" : " 以上"));
        Lumen::MovieClip* bar = score->Find("score_" + size + "_gauge_bar_mc");
        Goto(Sub(bar, "score_com_gauge_bar_type_mc"), down ? "type_down" : "type_up");
        Goto(Sub(bar, down ? "score_com_gauge_bar_type_mc/score_com_gauge_bar_down_mc" : "score_com_gauge_bar_type_mc/score_com_gauge_bar_up_mc"),
             down ? "gauge_100" : "gauge_0");
        Goto(bar, down ? "down_100" : "init");
        Lumen::MovieClip* num = score->Find("score_" + size + "_gauge_num_mc");
        Goto(num, down ? "down_100" : "empty");
        const int shown = down ? std::max(0, red - value) : value;   // 未満は赤合格までの残り
        for (const char* layer : {"back", "front", "add"}) SetCounter(Sub(num, "score_" + size + "_" + layer + "_mc"), 0, shown);
        // 数え上げの前は棒も数も出さない（lua: init で数が隠れている）
        score->GotoAndStop("init");
    }
}

// お題の棒と数の色（lua: GaugeColorChange / ScoreColorChange）
void DaniResultScene::SetDetailColor(int index, int slot, int gauge, bool max) {
    const DaniExam& exam = course_->exams[size_t(examOrder_[size_t(index)])];
    Lumen::MovieClip* detail = main_->Find(TextFormat("total_detail_0%d_mc/dummy_detail/detail_mc", index + 1));
    const std::string prefix = exam.total ? "score_all_mc" : TextFormat("score_0%d_mc", slot + 1);
    const std::string size = exam.total ? "l" : "m";
    Lumen::MovieClip* score = Sub(detail, prefix);
    Lumen::MovieClip* bar = Sub(score, "score_" + size + "_gauge_bar_mc");
    Lumen::MovieClip* num = Sub(score, "score_" + size + "_gauge_num_mc");
    Goto(Sub(bar, exam.LessThan() ? "score_com_gauge_bar_type_mc/score_com_gauge_bar_down_mc" : "score_com_gauge_bar_type_mc/score_com_gauge_bar_up_mc"),
         "gauge_" + std::to_string(gauge));
    if (max) {
        if (bar && bar->CurrentFrame() < bar->LabelFrame("max_start")) Goto(bar, "max_start", true);
        Goto(num, "max");
        return;
    }
    std::string label;
    if (!exam.LessThan()) {
        label = gauge == 0 ? "empty" : gauge <= 50 ? "up_50" : gauge <= 95 ? "up_80" : "up_100";
    } else {
        const int red = std::max(1, exam.red[size_t(exam.total ? 0 : slot)]);
        const int goodGauge = 100 - exam.gold[size_t(exam.total ? 0 : slot)] * 100 / red;
        label = gauge == 0 ? "empty" : gauge < 30 ? "down_80" : gauge <= goodGauge ? "up_80" : "down_100";
    }
    Goto(bar, label);
    Goto(num, label);
}

// 昇段（lua: DaniResultReward:SetShodanText）
void DaniResultScene::SetupShoudan() {
    if (!shoudan_) return;
    const bool gold = result_ > 3;
    const std::string color = gold ? "text_gold" : "text_white";
    const std::string inner = gold ? "text_Gold_mc" : "text_White_mc";
    const std::string prefix = gold ? "g_" : "w_";
    const std::pair<const char*, std::string> parts[] = {{"LL", ShoudanLeft(level_)}, {"LR", ShoudanRight(level_)}, {"RL", "19"}, {"RR", "20"}};
    for (const auto& part : parts) {
        for (const char* efc : {"", "_Efc"}) {
            Lumen::MovieClip* text = shoudan_->Find(std::string("dani_shoudan_text_") + part.first + efc + "_mc");
            Goto(text, color);
            Goto(Sub(text, inner), prefix + part.second);
        }
    }
    Visible(shoudan_->Find("gaiji_text_01_instance"), false);
    Visible(shoudan_->Find("reward_choice_panel"), false);
}

void DaniResultScene::Finalize() {
    SoundManager::Get().StopAll();
    if (donTexture_.id != 0) UnloadRenderTexture(donTexture_);
    donTexture_ = RenderTexture2D{};
    don3d_.Unload();
    Lumen::ClearExternalTextures();
    PlayDataManager::Get().Dani().active = false;
}

// ===========================================================================
// 進行（60fps で1フレームずつ）
// ===========================================================================
void DaniResultScene::Update(float deltaTime) {
    if (!loaded_) {
        SceneManager::GetInstance().ChangeScene(std::make_unique<EntryScene>());
        return;
    }
    hit_ = hit_ || TaikoInput::AnyDon();
    don_.Update(deltaTime);
    accumulator_ = std::min(accumulator_ + deltaTime, kFrame * 4.0f);
    while (accumulator_ >= kFrame) {
        accumulator_ -= kFrame;
        Step();
        hit_ = false;
        stage_.Update(kFrame);
    }
    if (state_ == State::GameOver) {
        gameOverTime_ += deltaTime;
        if (gameOverStep_ == 0 && gameOverTime_ >= float(kWaitOshimaiTime)) {
            gameOverStep_ = 1;
            Goto(gameOverCurtain_, "copyright_start", true);
        } else if (gameOverStep_ == 1 && gameOverTime_ >= float(kWaitOshimaiTime + kWaitCopyrightTime)) {
            gameOverStep_ = 2;
            Goto(gameOverCurtain_, "end");
            SetState(State::End);
            SceneManager::GetInstance().ChangeScene(std::make_unique<EntryScene>());
        }
    }
}

void DaniResultScene::SetState(State state) {
    state_ = state;
    frame_ = 0;
}

bool DaniResultScene::Reached(Lumen::MovieClip* clip, const char* label) const {
    if (!clip) return true;
    const int frame = clip->LabelFrame(label);
    return frame < 0 || clip->CurrentFrame() >= frame;
}

void DaniResultScene::Step() {
    ++frame_;
    SoundManager& sound = SoundManager::Get();
    switch (state_) {
    // ---- 各曲の板（lua: DaniResultSongMain） ----
    case State::Songs: {
        static const char* const kPlates[] = {"song_01", "song_02", "song_03", "end_song"};
        while (plateSe_ < 4 && Reached(main_, kPlates[plateSe_])) {
            ++plateSe_;
            sound.Play(kBankSe, "partial_plate");
        }
        if (hit_ || Reached(main_, "end_song")) {
            main_->GotoAndStop("end_song");
            plateSe_ = 4;
            SetState(State::SongsWait);
        }
        break;
    }
    case State::SongsWait:
        if (frame_ >= kWaitTime && (hit_ || frame_ >= kWaitEndTime)) {
            main_->GotoAndPlay("total");
            sound.Play(kBankSe, "total_intro");
            SetState(State::Total);
        }
        break;

    // ---- 総合（lua: DaniResultTotalMain / DaniResultTotalBase） ----
    case State::Total:
        if (hit_ || Reached(main_, "end_total")) {
            main_->GotoAndStop("end_total");
            gaugeShown_ = 0;
            skipGauge_ = hit_;
            if (gaugeValue_ > 0 && !skipGauge_) sound.PlaySlot(kBankCommon, "count_up_loop_c", kSlotLoop);
            SetState(State::TotalGauge);
        }
        break;
    case State::TotalGauge: {
        // 叩いたら（総合の途中で叩いたときも）すぐに数え終える
        const bool skip = hit_ || skipGauge_;
        if (gaugeShown_ < gaugeValue_ && (skip || frame_ % (kGaugeSpeed + 1) == 0)) {
            gaugeShown_ = skip ? gaugeValue_ : gaugeShown_ + 1;
            Goto(Sub(gauge_, "gauge_lamp_mc"), "gage_" + std::to_string(gaugeShown_ / 2));
            const bool full = gaugeShown_ >= 100;
            const bool clear = gaugeShown_ >= course_->gaugeRed;
            Goto(Sub(gauge_, "gauge_lamp_mc/lamp"), clear || full ? "lamp_clear" : "lamp_1p");
            Goto(Sub(gauge_, "tamashii_mc"), full ? "fever_start" : clear ? "clear" : "not_clear", full);
            Goto(Sub(gauge_, "gauge_lamp_mc/gauge_result_num_mc/gauge_result_num_set_mc"),
                 full ? "max" : clear ? "clear" : gaugeShown_ > 0 ? "noclear_1p" : "empty");
            if (Lumen::MovieClip* glow = Sub(gauge_, "glow_" + std::to_string(gaugeShown_ / 2))) {
                Goto(glow, "start", true);
                Goto(glow->Child("gauge_lamp_glow_type_mc"), clear || full ? "lamp_clear" : "lamp_1p", true);
            }
        }
        if (gaugeShown_ >= gaugeValue_) {
            sound.StopSlot(kSlotLoop);
            if (gaugeValue_ >= 100) sound.Play(kBankResult, "achieve_tamashii_c");
            Goto(Sub(gauge_, "gauge_lamp_mc/gauge_result_num_mc"), skip ? "wait" : "num_in", !skip);
            SetState(State::TotalGaugeNum);
        }
        break;
    }
    case State::TotalGaugeNum: {
        // 数が出きったら（wait）次へ。数が出る途中で叩いたら出しきる。数が止まって出てこないときも先へ進む
        Lumen::MovieClip* num = Sub(gauge_, "gauge_lamp_mc/gauge_result_num_mc");
        if (hit_ && num && !Reached(num, "wait")) num->GotoAndStop("wait");
        if ((!num || Reached(num, "wait") || !num->IsPlay()) && frame_ >= kWaitTime) {
            detail_ = 0;
            SetState(State::TotalWait);
        }
        break;
    }
    case State::TotalWait:
        if (frame_ >= kWaitDetail) {
            if (examCount_ > 0) {
                main_->GotoAndPlay("detail_in_01");
                SetState(State::Detail);
            } else {
                main_->GotoAndStop("stamp");
                SetState(State::DetailWait);
            }
        }
        break;

    // ---- お題ごとの結果（lua: DaniResultDetailBase） ----
    case State::Detail: {
        const std::string end = TextFormat("end_detail_0%d", detail_ + 1);
        if (Reached(main_, end.c_str())) {
            main_->GotoAndStop(end);
            const DaniExam& exam = course_->exams[size_t(examOrder_[size_t(detail_)])];
            sound.PlaySlot(kBankSe, exam.LessThan() ? "gauge_down_loop" : "gauge_up_loop", kSlotLoop);
            SetState(State::DetailGauge);
        }
        break;
    }
    case State::DetailGauge: {
        const DaniExam& exam = course_->exams[size_t(examOrder_[size_t(detail_)])];
        const int songs = exam.total ? 1 : std::max(1, reach_);
        bool done = true;
        for (int s = 0; s < songs; ++s) {
            int& current = detailGauge_[size_t(s)];
            const int target = detailTarget_[size_t(s)];
            if (current == target) continue;
            done = false;
            if (hit_) current = target;
            else if (frame_ % (kDetailGaugeSpeed + 1) == 0) current += target > current ? 1 : -1;
            SetDetailColor(detail_, s, current, false);
        }
        if (done) {
            sound.StopSlot(kSlotLoop);
            // 数を出す（lua: UpdateNumIn）。金合格の値なら虹色
            Lumen::MovieClip* detail = main_->Find(TextFormat("total_detail_0%d_mc/dummy_detail/detail_mc", detail_ + 1));
            for (int s = 0; s < songs; ++s) {
                const int value = DaniExamValue(exam, run_, s);
                const int gold = exam.gold[size_t(exam.total ? 0 : s)];
                const bool max = exam.LessThan() ? value < gold : value >= gold;
                SetDetailColor(detail_, s, detailGauge_[size_t(s)], max && s < reach_ && reach_ >= (exam.total ? kDaniSongCount : 1));
                Goto(Sub(detail, exam.total ? std::string("score_all_mc") : std::string(TextFormat("score_0%d_mc", s + 1))), "num_in", true);
            }
            sound.Play(kBankSe, "gauge_judgement");
            SetState(State::DetailNum);
        }
        break;
    }
    case State::DetailNum:
        if (frame_ >= kNumInWait || (hit_ && frame_ > 1)) {
            ++detail_;
            if (detail_ >= examCount_) {
                SetState(State::DetailWait);
            } else {
                main_->GotoAndPlay(TextFormat("detail_in_0%d", detail_ + 1));
                SetState(State::Detail);
            }
        }
        break;

    // ---- 合否の印（lua: DaniResultTotalMain "stamp"） ----
    case State::DetailWait:
        if (frame_ >= kWaitTime) {
            main_->GotoAndPlay("stamp");
            static const char* const kStamps[] = {"stamp_anm_fail_mc", "stamp_anm_red_01_mc", "stamp_anm_red_02_mc", "stamp_anm_red_03_mc",
                                                  "stamp_anm_gold_01_mc", "stamp_anm_gold_02_mc", "stamp_anm_gold_03_mc"};
            static const char* const kBgs[] = {"bg_fail", "bg_red_01", "bg_red_02", "bg_red_03", "bg_gold_01", "bg_gold_02", "bg_gold_03"};
            Goto(main_->Find("result_bg_mc"), kBgs[result_]);
            Goto(main_->Find(kStamps[result_]), "stamp_anm", true);
            sound.Play(kBankSe, result_ == 0 ? "notclear" : result_ <= 3 ? "clear_normal" : "clear_upper");
            SetState(State::Stamp);
        }
        break;
    case State::Stamp:
        if (frame_ >= kWaitTime && Reached(main_, "end_stamp")) {
            main_->GotoAndStop("end_stamp");
            if (result_ == 0) {
                sound.Play(kBankVoice, "notclear");
                don_.SetNonLoopAnimation("result_failure", false);
                don_.SetLoopAnimation("result_failure_loop");
            } else {
                sound.Play(kBankSe, "atmos_clear_c");
                sound.Play(kBankVoice, result_ <= 3 ? "clear_normal" : "clear_upper");
                don_.SetNonLoopAnimation(result_ <= 3 ? "result_clear" : "result_full", false);
                don_.SetLoopAnimation(result_ <= 3 ? "result_clear_loop" : "result_full_loop");
            }
            SetState(State::StampWait);
        }
        break;
    case State::StampWait:
        if (hit_ || frame_ >= kWaitEndTime) {
            if (shoudanFlag_) {
                // 昇段（lua: DaniResultReward "Shodan"）
                main_->GotoAndStop("shoudan");
                Visible(shoudan_, true);
                Goto(shoudan_, "shoudan_start", true);
                Goto(Sub(shoudan_, "don_1p"), "framein", true);
                static const char* const kBgs[] = {"dani_shoudan_bg_W_instance", "dani_shoudan_bg_G_instance", "dani_shoudan_bg_R_instance"};
                Goto(Sub(shoudan_, kBgs[(result_ - 1) % 3]), "start", true);
                if (level_ > prevNowDani_) sound.Play(kBankVoice, "advance");
                sound.Play(kBankSe, "advance_intro");
                don_.SetLoopAnimation("result_clear_loop");
                SetState(State::Shoudan);
            } else {
                StartGameOver();
            }
        }
        break;
    case State::Shoudan:
        // 段位のきせかえは移植していないので、きせかえの手前で止めて待つ
        if (Reached(shoudan_, "dress_change_start")) {
            shoudan_->GotoAndStop("dress_change_start");
            SetState(State::ShoudanWait);
        }
        break;
    case State::ShoudanWait:
        if (frame_ >= kWaitTime && (hit_ || frame_ >= kWaitShodan)) {
            if (congrats_) {
                Lumen::MovieClip* congrats = main_->Find("dummy_congrats");
                Visible(congrats, true);
                Goto(congrats, "start", true);
                sound.Play("voice_common_v12a", "glad_c");
                sound.Play(kBankSe, "popup_superlative");
                SetState(State::Congrats);
            } else {
                StartGameOver();
            }
        }
        break;
    case State::Congrats:
        if (Reached(main_->Find("dummy_congrats"), "end") && frame_ >= kWaitCongrats) StartGameOver();
        break;
    case State::GameOver:
    case State::End:
        break;
    }
}

// lua: DaniResultMain:StartGameOver
void DaniResultScene::StartGameOver() {
    SetState(State::GameOver);
    gameOverTime_ = 0.0f;
    gameOverStep_ = 0;
    if (Lumen::MovieClip* gameOver = main_->Find("dummy_gameover")) Goto(gameOver->Child("main"), "start");
    Goto(gameOverCurtain_, "oshimai_start", true);
    SoundManager& sound = SoundManager::Get();
    sound.StopSlot(kSlotBgm);
    sound.Play(kBankCommon, "curtain");
    sound.PlaySlot("bgm_common_v12a", "gameover_primal", kSlotBgm);
    sound.Play("voice_common_v12a", "gameover");
}

// ===========================================================================
// 描画
// ===========================================================================
void DaniResultScene::Draw() {
    ClearBackground(BLACK);
    if (!loaded_) return;
    RenderDon();
    stage_.Draw();
    if (EnsoScene::autoUsed) CommonParts::DrawNoRecordNotice();
}

void DaniResultScene::RenderDon() {
    if (!don3d_.IsLoaded() || donTexture_.id == 0) return;
    don_.Apply(don3d_);
    Camera3D camera{};
    camera.target = Vector3{0.0f, 0.14f, 0.0f};
    camera.position = Vector3{0.0f, 0.2f, 1.7f};
    camera.up = Vector3{0.0f, 1.0f, 0.0f};
    camera.fovy = 0.8f;
    camera.projection = CAMERA_ORTHOGRAPHIC;
    BeginTextureMode(donTexture_);
    ClearBackground(Color{0, 0, 0, 0});
    BeginMode3D(camera);
    don3d_.Draw(0, don3d_.Expression(), MatrixRotateY(30.0f * DEG2RAD));
    EndMode3D();
    EndTextureMode();
}
