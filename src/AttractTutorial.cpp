#include "AttractTutorial.hpp"

#include <cstdio>

#include "SoundManager.hpp"
#include "raymath.h"
#include "rlgl.h"

namespace {

constexpr const char* kMovie = "lumen/000_default/tutorial/tutorial";
constexpr const char* kScore = "lumen/000_default/enso_normal/enso/information/score";
constexpr const char* kKusudama = "lumen/000_default/enso_normal/enso/onpu/action_kusudama";
constexpr const char* kBankBgm = "bgm_howtoplay_v12a";
constexpr const char* kBankSe = "se_howtoplay_v12a";
constexpr const char* kBankEnso = "se_enso_v12a";
constexpr const char* kBankCommon = "se_common_v12a";
constexpr const char* kBankVoice = "voice_howtoplay_v12a";
constexpr int kSlotBgm = 0;
constexpr int kAddScoreMax = 4;
constexpr int kBgmEndLimit = 60 * 30;   // BGM が終わらない（ループする）ときの待ちの上限

// lua の "normal" は don_normal だが、このアニメーションはまだ正しく読めないので演奏中と同じ norm_loop で代える
constexpr const char* kDonNormal = "norm_loop";

void Visible(Lumen::MovieClip* clip, bool visible) {
    if (clip) clip->SetVisible(visible);
}

Lumen::MovieClip* Child(Lumen::MovieClip* clip, const std::string& name) { return clip ? clip->Find(name) : nullptr; }

} // namespace

bool AttractTutorial::Start() {
    // アトラクトの2周目以降のために、前回の状態を消しておく
    main_ = scene_ = don1p_ = fadeLane_ = nullptr;
    for (Lumen::MovieClip*& digit : scoreDigit_) digit = nullptr;
    currentScore_ = 0;
    for (AddScore& add : addScore_) add = AddScore();
    addScoreCurrent_ = 0;
    addScoreList_.clear();
    kusudamaActive_ = false;
    kusudamaFrame_ = 0;
    kusudamaRoot_ = kusudamaHit_ = kusudamaRendasText_ = kusudamaSuccessHigh_ = kusuDigit1_ = nullptr;
    fadeOut_ = false;
    don_ = DonAnimator();
    stage_ = Lumen::Stage();

    loaded_ = stage_.Load(kMovie);
    if (!loaded_) return false;
    for (const char* bank : {kBankBgm, kBankSe, kBankEnso, kBankCommon, kBankVoice}) SoundManager::Get().Preload(bank);

    // どんちゃん（左上の don1p の差し込み枠に描く）
    don3d_.Load();
    donTexture_ = LoadRenderTexture(1920, 1080);
    SetTextureFilter(donTexture_.texture, TEXTURE_FILTER_BILINEAR);
    Lumen::SetExternalTexture("don1p", &donTexture_.texture, true);
    don_.SetLoopAnimation(kDonNormal, false);

    state_ = "Begin";
    count_ = 0;
    return true;
}

void AttractTutorial::Finish() {
    SoundManager::Get().StopSlot(kSlotBgm);
    if (donTexture_.id != 0) UnloadRenderTexture(donTexture_);
    donTexture_ = RenderTexture2D{};
    don3d_.Unload();
    Lumen::ClearExternalTextures();
}

void AttractTutorial::SetState(const std::string& state) {
    state_ = state;
    count_ = 0;
}

void AttractTutorial::PlayBgm() {
    const std::vector<std::string> tones = SoundManager::Get().Tones(kBankBgm);
    if (!tones.empty()) SoundManager::Get().PlaySlot(kBankBgm, tones.front(), kSlotBgm);
}

// scene_NN へ（lua の scene_0N の終わりの処理）
void AttractTutorial::EnterScene(int number, const std::string& voice) {
    const std::string name = TextFormat("scene_%02d", number);
    main_->GotoAndPlay(name);
    scene_ = stage_.GetMovieClip(name + "_instance");
    if (!scene_) return;
    if (Lumen::MovieClip* window = Child(scene_, "scene_window_tx_instance")) {
        window->SetText("tx_window_instance", TextFormat("tutorial_%02d_001", number));
    }
    if (Lumen::MovieClip* clear = Child(scene_, "clear_text_instance")) clear->SetText("text", "tutorial_99_002");
    if (number == 10) {
        if (Lumen::MovieClip* clear = Child(scene_, "scene_clear_tx_instance")) clear->SetText("tx_clear", "tutorial_99_003");
    }
    if (number == 8) KusudamaInit();
    if (!voice.empty()) SoundManager::Get().Play(kBankVoice, voice);
    scene_->GotoAndPlay(0);
}

void AttractTutorial::Step() {
    if (!loaded_) {
        state_ = "End";
        return;
    }
    ++count_;
    const int c = count_;

    if (state_ == "Begin") {
        main_ = stage_.Root();
        don1p_ = stage_.GetMovieClip("don1p");
        if (Lumen::MovieClip* skip = stage_.GetMovieClip("skip_message_instance/skip_message_tx_instance")) {
            skip->SetText("tx_skip_instance", "tutorial_99_001");
        }
        fadeLane_ = stage_.GetMovieClip("fade_lane_instance");
        if (Lumen::MovieClip* clear = Child(fadeLane_, "clear_text_instance")) clear->SetText("text", "tutorial_99_002");

        for (int i = 1; i <= 4; ++i) stage_.LoadMovie(kScore, TextFormat("dummy_score_instance_%d", i));
        stage_.LoadMovie(kKusudama, "dummy_kusudama_instance");
        SetState("Loading");
    } else if (state_ == "Loading") {
        // メインのスコア
        Lumen::MovieClip* scoreMain = stage_.GetMovieClip("dummy_score_instance_1");
        Lumen::MovieClip* score = Child(scoreMain, "score");
        Visible(Child(score, "kirakira"), false);
        Visible(Child(score, "high_score_bg"), false);
        Visible(Child(scoreMain, "high_score_anim"), false);
        for (int i = 0; i < 7; ++i) {
            scoreDigit_[i] = Child(score, TextFormat("digit%d", i + 1));
            Visible(Child(scoreDigit_[i], "light"), false);
        }
        ScoreUpdate();
        // メイン以外のスコアは加点の表示だけに使う
        for (int i = 2; i <= 4; ++i) {
            Lumen::MovieClip* other = stage_.GetMovieClip(TextFormat("dummy_score_instance_%d", i));
            Lumen::MovieClip* otherScore = Child(other, "score");
            Visible(Child(otherScore, "high_score_bg"), false);
            Visible(Child(otherScore, "kirakira"), false);
            Visible(otherScore, false);
            Visible(Child(other, "base"), false);
            Visible(Child(other, "high_score_anim"), false);
        }
        // 加点の表示（add_score_CreateLoop）
        for (int i = 0; i < kAddScoreMax; ++i) {
            Lumen::MovieClip* root = stage_.GetMovieClip(TextFormat("dummy_score_instance_%d", i + 1));
            if (Lumen::MovieClip* l = Child(root, "add_score_l_mc")) l->GotoAndStop(0);
            if (Lumen::MovieClip* r = Child(root, "add_score_r_1p_mc")) r->GotoAndStop(0);
            addScore_[i].mc = Child(root, "add_score_l_mc");
            for (int d = 0; d < 6; ++d) addScore_[i].digit[d] = Child(addScore_[i].mc, TextFormat("digit%d", d + 1));
            if (addScore_[i].digit[0]) addScore_[i].digit[0]->GotoAndStop(TextFormat("number_%d", i));
        }

        PlayBgm();
        SoundManager::Get().Play(kBankVoice, "howtoplay_01");
        main_->GotoAndPlay("fade_in");
        SetState("fade_in");
    } else if (state_ == "fade_in") {
        if (!main_->IsPlay()) {
            SetState("BGM_start_wait");
            main_->GotoAndPlay("scene_01");
            scene_ = stage_.GetMovieClip("scene_01_instance");
            if (scene_) {
                scene_->GotoAndStop(0);
                if (Lumen::MovieClip* window = Child(scene_, "scene_window_tx_instance")) window->SetText("tx_window_instance", "tutorial_01_001");
                if (Lumen::MovieClip* clear = Child(scene_, "clear_text_instance")) clear->SetText("text", "tutorial_99_002");
            }
        }
    } else if (state_ == "BGM_start_wait") {
        // BGM が始まってから2秒
        if (c >= 2 * 60) {
            SoundManager::Get().Play(kBankVoice, "howtoplay_02");
            SetState("scene_01");
            if (scene_) scene_->GotoAndPlay(0);
        }
    } else if (state_.rfind("scene_", 0) == 0) {
        const int number = std::atoi(state_.c_str() + 6);
        switch (number) {
        case 2: Scene2(c); break;
        case 3: Scene3(c); break;
        case 4: Scene4(c); break;
        case 5: Scene5(c); break;
        case 6: Scene6(c); break;
        case 7: Scene7(c); break;
        case 8: Scene8(c); KusudamaUpdate(c); break;
        case 9: Scene9(c); break;
        case 10: Scene10(c); break;
        default: break;
        }
        // シーンの再生が止まったら次へ
        if (!scene_ || !scene_->IsPlay()) {
            if (number < 10) {
                EnterScene(number + 1, TextFormat("howtoplay_%02d", number + 2));
                SetState(TextFormat("scene_%02d", number + 1));
            } else {
                if (fadeLane_) fadeLane_->GotoAndPlay("fade_out");
                main_->GotoAndStop("fade_out");
                SetState("BGM_end_wait");
            }
        }
    } else if (state_ == "BGM_end_wait") {
        if (!SoundManager::Get().IsSlotPlaying(kSlotBgm) || c > kBgmEndLimit) {
            fadeOut_ = true;
            main_->GotoAndPlay("fade_out");
            SetState("fade_out");
        }
    } else if (state_ == "fade_out") {
        if (!main_->IsPlay()) SetState("EndWait");
    } else if (state_ == "EndWait") {
        SetState("End");
    }

    ScoreListUpdate();
}

void AttractTutorial::Advance() {
    stage_.Update(1.0f / 60.0f);
    don_.Update(1.0f / 60.0f);
}

// ===========================================================================
// スコア
// ===========================================================================
void AttractTutorial::ScoreUpdate() {
    const std::string s = std::to_string(currentScore_);
    for (int j = 0; j < 7; ++j) {
        if (!scoreDigit_[j]) continue;
        if (j < int(s.size())) scoreDigit_[j]->GotoAndPlay(std::string("number_") + s[s.size() - 1 - size_t(j)]);
        else scoreDigit_[j]->GotoAndPlay("none");
    }
}

void AttractTutorial::ScoreListUpdate() {
    for (size_t i = 0; i < addScoreList_.size();) {
        PendingScore& s = addScoreList_[i];
        ++s.counter;
        if (s.counter > 32) {
            // スコアの値を加算して跳ねる
            currentScore_ += s.plus;
            ScoreUpdate();
            addScoreList_.erase(addScoreList_.begin() + long(i));
        } else {
            ++i;
        }
    }
}

void AttractTutorial::ScorePlus(int num) {
    addScoreList_.push_back(PendingScore{0, num});
    AddScore& add = addScore_[addScoreCurrent_];
    const std::string s = std::to_string(num);
    for (int j = 0; j < 6; ++j) {
        if (!add.digit[j]) continue;
        if (j < int(s.size())) add.digit[j]->GotoAndPlay(std::string("number_") + s[s.size() - 1 - size_t(j)]);
        else add.digit[j]->GotoAndPlay("none");
    }
    if (add.mc) add.mc->GotoAndPlay(0);
    addScoreCurrent_ = (addScoreCurrent_ + 1) % kAddScoreMax;
}

void AttractTutorial::ScorePlusSound(int num, const char* bank, const char* tone) {
    SoundManager::Get().Play(bank, tone);
    ScorePlus(num);
}

// ===========================================================================
// シーンごとのタイミング（lua の tutorial_score_plus_sceneN / tutorial_se_sceneN）
// ===========================================================================
void AttractTutorial::Scene2(int f) {
    if (f == 300) SoundManager::Get().Play(kBankCommon, "don_c");
    if (f == 361) ScorePlus(5000);
}

void AttractTutorial::Scene3(int f) {
    if (f == 125 || f == 149 || f == 174) SoundManager::Get().Play(kBankSe, "hit_side");
    if (f == 191) SoundManager::Get().Play(kBankCommon, "caution_buzzer");
}

void AttractTutorial::Scene4(int f) {
    if (f == 300) ScorePlusSound(5000, kBankCommon, "don_c");
}

void AttractTutorial::Scene5(int f) {
    if (f == 300) ScorePlusSound(5000, kBankCommon, "katsu_c");
}

void AttractTutorial::Scene6(int f) {
    if (f == 300) ScorePlusSound(5000, kBankCommon, "don_c");
}

void AttractTutorial::Scene7(int f) {
    // 連打: 300〜370 フレームに5フレームおき
    if (f >= 300 && f <= 370 && (f - 300) % 5 == 0) ScorePlusSound(100, kBankCommon, "don_c");
}

void AttractTutorial::Scene8(int f) {
    // 風船
    if (f == 301) Visible(don1p_, false);
    if (f == 395) Visible(don1p_, true);
    if (f == 301) don_.SetLoopAnimation("balloon_loop", false);
    if (f >= 311 && f <= 351 && (f - 311) % 10 == 0) don_.SetNonLoopAnimation("balloon_nobeat", false);
    if (f == 361) don_.SetNonLoopAnimation("balloon_success", true);
    if (f == 390) don_.SetLoopAnimation(kDonNormal, false);
    if (f >= 301 && f <= 361 && (f - 301) % 10 == 0) ScorePlusSound(100, kBankCommon, "don_c");
    if (f == 361) SoundManager::Get().Play(kBankEnso, "balloon_success_c");

    // くす玉
    if (f == 752) Visible(don1p_, false);
    if (f == 910) Visible(don1p_, true);
    if (f == 752) don_.SetNonLoopAnimation("kusu_in_p1", false);
    if (f == 771) don_.SetLoopAnimation("kusu_nobeat_p1", false);
    if (f >= 781 && f <= 851 && (f - 781) % 10 == 0) don_.SetNonLoopAnimation("kusu_loop_p1", false);
    if (f == 861) don_.SetNonLoopAnimation("kusu_success02_p1", true);
    if (f == 910) don_.SetLoopAnimation(kDonNormal, false);
    if (f >= 771 && f <= 861 && (f - 771) % 10 == 0) ScorePlusSound(100, kBankCommon, "don_c");
    if (f == 861) SoundManager::Get().Play(kBankEnso, "kusudama_success");
}

void AttractTutorial::Scene9(int f) {
    if (f == 200 || f == 220 || f == 260 || f == 280 || f == 400 || f == 440) ScorePlusSound(5000, kBankCommon, "don_c");
    if (f == 321) ScorePlusSound(5000, kBankCommon, "katsu_c");
}

void AttractTutorial::Scene10(int f) {
    if (f == 154) SoundManager::Get().Play(kBankSe, "achieve_clear");     // クリアライン
    if (f == 360) SoundManager::Get().Play(kBankSe, "achieve_tamashii");  // 魂ゲージ
}

// ===========================================================================
// くす玉（lua: tutorial_kusudama_*）
// ===========================================================================
void AttractTutorial::KusudamaInit() {
    kusudamaActive_ = false;
    Lumen::MovieClip* holder = Child(scene_, "dummy_kusudama_instance");
    kusudamaRoot_ = Child(holder, "main");
    if (!kusudamaRoot_) return;
    kusudamaRoot_->GotoAndStop(0);
    kusudamaHit_ = Child(kusudamaRoot_, "kusudama_hit");
    kusudamaRendasText_ = Child(kusudamaRoot_, "rendas_text");
    Lumen::MovieClip* counter = Child(kusudamaRoot_, "renda_counter");
    kusudamaSuccessHigh_ = Child(kusudamaRoot_, "kusudama_success_high");
    Lumen::MovieClip* successLow = Child(kusudamaRoot_, "kusudama_success_low");
    Lumen::MovieClip* miss = Child(kusudamaRoot_, "kusudama_miss");

    kusuDigit1_ = Child(counter, "digit1_1");
    Visible(kusuDigit1_, false);
    if (Lumen::MovieClip* d = Child(counter, "digit10_1")) d->GotoAndPlay("number_0");
    if (Lumen::MovieClip* d = Child(counter, "digit10_2")) d->GotoAndPlay("number_1");
    for (const char* name : {"digit100_1", "digit100_2", "digit100_3"}) Visible(Child(counter, name), false);

    // 2P を消す
    for (Lumen::MovieClip* clip : {kusudamaRoot_, kusudamaSuccessHigh_, successLow, miss}) {
        if (clip) Visible(clip->Child("don_player2") ? clip->Child("don_player2") : Child(clip, "don_player2"), false);
    }
}

void AttractTutorial::KusudamaStart() {
    kusudamaFrame_ = 0;
    kusudamaActive_ = true;
    if (kusudamaRoot_) kusudamaRoot_->GotoAndPlay("start");
    if (kusudamaHit_) kusudamaHit_->GotoAndPlay("geki_05");
}

void AttractTutorial::KusudamaUpdate(int f) {
    if (kusudamaActive_) {
        ++kusudamaFrame_;
        if (kusudamaFrame_ == 26 && kusudamaRendasText_) kusudamaRendasText_->GotoAndPlay("init");

        Lumen::MovieClip* counter = Child(kusudamaRoot_, "renda_counter");
        if (f == 771) {
            Visible(kusuDigit1_, true);
            if (kusuDigit1_) kusuDigit1_->GotoAndPlay("number_9");
            Visible(Child(counter, "digit10_1"), false);
            Visible(Child(counter, "digit10_2"), false);
        }
        // 残り 9 → 1 を 10 フレームごとに。20 フレームごとに割れ具合（geki_04 → geki_00）
        static const struct { int frame; int number; const char* geki; } kSteps[] = {
            {771, 9, "geki_04"}, {781, 8, nullptr}, {791, 7, "geki_03"}, {801, 6, nullptr}, {811, 5, "geki_02"},
            {821, 4, nullptr}, {831, 3, "geki_01"}, {841, 2, nullptr}, {851, 1, "geki_00"},
        };
        for (const auto& step : kSteps) {
            if (f != step.frame) continue;
            if (kusuDigit1_) kusuDigit1_->GotoAndPlay(TextFormat("number_%d", step.number));
            if (step.geki && kusudamaHit_) kusudamaHit_->GotoAndPlay(step.geki);
        }
        if (f == 861) {
            Visible(kusudamaHit_, false);
            if (kusudamaSuccessHigh_) kusudamaSuccessHigh_->GotoAndPlay("start");
            if (kusudamaRoot_) kusudamaRoot_->GotoAndPlay("success_high");
        }
        if (f == 926) Visible(kusudamaRoot_, false);
    }
    if (f == 752) KusudamaStart();
}

// ===========================================================================
// 描画
// ===========================================================================
void AttractTutorial::RenderDon() {
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

void AttractTutorial::Draw() {
    if (!loaded_) return;
    RenderDon();
    stage_.Draw();
}
