#include "ResultScene.hpp"

#include <algorithm>
#include <cmath>
#include <memory>

#include "CommonParts.hpp"
#include "EnsoScene.hpp"
#include "EntryScene.hpp"
#include "LoadingScene.hpp"
#include "SceneManager.hpp"
#include "SongDatabase.hpp"
#include "SoundManager.hpp"
#include "TaikoInput.hpp"
#include "WordList.hpp"
#include "raymath.h"

using namespace GuminTaiko;

namespace {

constexpr float kFrame = 1.0f / 60.0f;
constexpr const char* kRoot = "lumen/000_default/";

// lua: Main の定数
constexpr int kWaitOshimaiTime = 7;        // ゲームオーバーの「また遊んでね」での待機時間（秒）
constexpr int kWaitCopyrightTime = 3;      // ゲームオーバー後のコピーライトでの待機時間（秒）
constexpr int kWaitEffectEndTime = 500;    // 全演出が終了してから、自動で次へ進む準備をするまでの待機時間
constexpr int kEarlyNextGuard = 15;        // 全部出し終えたあと、この間（フレーム）はドンで次へ進まない（演出を飛ばした叩きがそのまま次へ進まないように）
constexpr int kAutoNextTime = 1200;        // 何も叩かなくても次へ進むまで（フレーム。60fps で 20 秒）
constexpr int kGageSpeed = 7;              // 魂ゲージが１メモリ進むのに必要な時間
constexpr int kMaxGage = 50;

// ---- サウンド ----
constexpr const char* kBankSe = "se_common_v12a";
constexpr const char* kBankSeResult = "se_result_v12a";
constexpr const char* kBankVoiceResult = "voice_result_v12a";
constexpr const char* kBankVoice = "voice_common_v12a";
constexpr const char* kBankBgm = "bgm_result_v12a";
constexpr const char* kBankBgmCommon = "bgm_common_v12a";
constexpr int kSlotBgm = 0;
constexpr int kSlotCountUp = 1;            // 魂ゲージが伸びる音（2人目は +1）

void Goto(Lumen::MovieClip* clip, const std::string& label, bool play = false) {
    if (!clip) return;
    if (play) clip->GotoAndPlay(label);
    else clip->GotoAndStop(label);
}

Lumen::MovieClip* Sub(Lumen::MovieClip* root, const std::string& path) {
    return root ? root->Find(path) : nullptr;
}

void Visible(Lumen::MovieClip* clip, bool visible) {
    if (clip) clip->SetVisible(visible);
}

} // namespace

// ===========================================================================
// 読み込み（lua: Main "Begin" 〜 "Loading"）
// ===========================================================================
void ResultScene::Initialize() {
    PlayDataManager& pd = PlayDataManager::Get();
    isLastSong_ = pd.IsLastSong();
    const bool joined[2] = {pd.Result(0).valid, pd.Result(1).valid};
    entryType_ = joined[0] && joined[1] ? 2 : joined[1] ? 1 : 0;

    for (const char* bank : {kBankSe, kBankSeResult, kBankVoiceResult, kBankVoice, kBankBgm, kBankBgmCommon}) {
        SoundManager::Get().Preload(bank);
    }

    if (!stage_.Load(std::string(kRoot) + "result/result")) {
        TraceLog(LOG_WARNING, "ResultScene: リザルト画面を読み込めません");
        return;
    }
    // 別の lumen の読み込み（ごほうび・QR・演奏オプションなどは使わない）
    stage_.LoadMovie(std::string(kRoot) + "result/result_bg", "bg_mc");
    stage_.LoadMovie(std::string(kRoot) + "gameover/GameOver", "game_over_mc");
    stage_.LoadMovie(std::string(kRoot) + "enso_normal/song_select/song_select_number_of_songs", "song_number_info_mc");
    stage_.LoadMovie(std::string(kRoot) + "enso_normal/enso/tamashiigage/tamashii_gage", "tamashii_gage_L");
    stage_.LoadMovie(std::string(kRoot) + "enso_normal/enso/tamashiigage/tamashii_gage", "tamashii_gage_R");
    stage_.LoadMovie(std::string(kRoot) + "result/result_board_donback", "dummy_donback_l");
    stage_.LoadMovie(std::string(kRoot) + "result/result_board_donback", "dummy_donback_r");
    stage_.LoadMovie(std::string(kRoot) + "common/name_plate", "name_plate_L");
    stage_.LoadMovie(std::string(kRoot) + "common/name_plate", "name_plate_R");

    main_ = stage_.GetMovieClip("main");
    if (!main_) return;
    loaded_ = true;

    // 曲名
    if (const SongInfo* song = SongDatabase::Get().FindSong(pd.SelectedSong())) main_->SetText("song_name_center", "song_" + song->id);

    // プレイヤー（エントリー）の種類ごとの見た目
    static const char* const kMainLabels[] = {"use_left", "use_right", "duet"};
    main_->GotoAndStop(kMainLabels[entryType_]);
    if (entryType_ != 1) {
        boards_[0].active = true;
        boards_[0].player = 0;
    }
    if (entryType_ != 0) {
        boards_[1].active = true;
        boards_[1].player = 1;
    }
    for (int side = 0; side < 2; ++side) {
        if (boards_[side].active) SetupBoard(boards_[side], side == 1);
        else Visible(main_->Child(side == 0 ? "score_base_L" : "score_base_R"), false);
    }
    // どんちゃん: 左の枠には 1P、右の枠には 2P を差し込む（使わない方は消す）
    if (Lumen::MovieClip* don = main_->Child("don_L")) {
        Visible(don->Child("don2p"), false);
        Visible(don, boards_[0].active);
        Goto(don, "start", true);
    }
    if (Lumen::MovieClip* don = main_->Child("don_R")) {
        Visible(don->Child("don1p"), false);
        Visible(don, boards_[1].active);
        Goto(don, "start", true);
    }
    for (Board& board : boards_) {
        if (board.active) board.don.SetLoopAnimation("result_loop");
        if (board.active && board.result.resultType != 0) allFailure_ = false;
    }

    // 背景（lua: ResultBg:SetPlayerInfo）
    if (Lumen::MovieClip* bgMain = Sub(stage_.GetMovieClip("bg_mc"), "main_mc")) {
        static const char* const kBgLabels[] = {"1p_l", "1p_r", "2p"};
        static const char* const kBgClips[] = {"bg_1p_l", "bg_1p_r", "bg_2p"};
        bgMain->GotoAndStop(kBgLabels[entryType_]);
        bg_ = bgMain->Child(kBgClips[entryType_]);
        Goto(bg_, "init");
    }

    // ゲームオーバーの幕
    if (Lumen::MovieClip* gameOver = main_->Child("game_over_mc")) {
        gameOverMain_ = gameOver->Child("main");
        gameOverCurtain_ = Sub(gameOverMain_, "end_curtain_mc");
        Goto(gameOverMain_, "init");
        Goto(gameOverCurtain_, "oshimai_init");
    }

    // 何曲目か
    WordList::Get().Set("attract_numberofsong", std::to_string(pd.PlaySongCount()) + "曲目");
    WordList::Get().Set("attract_numberofstage", std::to_string(PlayDataManager::Get().StageCount()) + "曲");
    if (Lumen::MovieClip* number = main_->Child("song_number_info_mc")) {
        if (Lumen::MovieClip* songs = Sub(number, "main/number_of_songs")) {
            songs->SetText("text_total_songs", "attract_numberofstage");
            songs->SetText("text_current_songs", "attract_numberofsong");
        }
    }

    // スコアボードの下の背景
    Goto(Sub(main_->Child("dummy_donback_l"), "donback"), "1p");
    Goto(Sub(main_->Child("dummy_donback_r"), "donback"), "2p");
    Visible(main_->Child("dummy_donback_l"), boards_[0].active);
    Visible(main_->Child("dummy_donback_r"), boards_[1].active);

    // ネームプレート（lua: SetUserName）
    for (int side = 0; side < 2; ++side) {
        Lumen::MovieClip* plate = main_->Child(side == 0 ? "name_plate_L" : "name_plate_R");
        Visible(plate, boards_[side].active);
        if (boards_[side].active) CommonParts::SetNamePlate(plate, boards_[side].player);
    }

    // 使わない部品
    for (const char* name : {"dummy_reward", "control_guide_L", "control_guide_R", "option_icon_L", "option_icon_R",
                             "event_token_bg_L", "event_token_bg_R", "dummy_message_event_l", "dummy_message_event_r",
                             "dummy_qrcode_image_L", "dummy_qrcode_image_R", "qr_title_mc_L", "qr_title_mc_R",
                             "guide_s_taiko_side_mc_L", "guide_s_taiko_side_mc_R", "wait_notice_L", "wait_notice_R"}) {
        Visible(main_->Child(name), false);
    }
    Goto(main_->Child("msg_L_mc"), "init");
    Goto(main_->Child("msg_R_mc"), "init");

    // どんちゃん（差し込み枠）
    // それぞれのプレイヤーがエントリーで選んだきせかえ
    for (int p = 0; p < 2; ++p) {
        const PlayerData& data = PlayDataManager::Get().Player(p);
        don3d_.SetCostume(p, DonModel::FromEntry(data.costume, data.kigurumi, data.dress));
    }
    don3d_.Load();
    for (int p = 0; p < 2; ++p) {
        donTexture_[p] = LoadRenderTexture(1920, 1080);
        SetTextureFilter(donTexture_[p].texture, TEXTURE_FILTER_BILINEAR);
        Lumen::SetExternalTexture(p == 0 ? "don1p" : "don2p", &donTexture_[p].texture, true);
    }

    SetState(State::Fadein);
}

// lua: ScoreBase "Loading" / SetTamashiiGage / StartDifficultyDisplay
void ResultScene::SetupBoard(Board& board, bool right) {
    const PlayDataManager& pd = PlayDataManager::Get();
    board.right = right;
    board.result = pd.Result(board.player);
    board.mc = main_->Child(right ? "score_base_R" : "score_base_L");
    Lumen::MovieClip* mc = board.mc;
    if (!mc) return;

    mc->SetText("score_text", "result_score");
    // 背景の色: 2人のときは 1P が赤・2P が青、1人のときは叩いた太鼓の側
    mc->GotoAndStop(right ? "2P" : "1P");
    for (const char* name : {"crown_mc", "score_rank_mc", "score_rank_kiwami_mc", "best_score_mc"}) Visible(mc->Child(name), false);

    // 数値はまだ出さない（digit は none のフレーム）
    for (const char* name : {"good_num_mc", "ok_num_mc", "bad_num_mc", "dramroll_num_mc", "max_combo_num_mc", "total_score_mc",
                             "total_score_back_mc"}) {
        Lumen::MovieClip* num = mc->Child(name);
        for (int d = 1; d <= 7; ++d) Goto(Sub(num, "digit" + std::to_string(d)), "none");
    }

    // ハイスコア更新の演出が必要か
    if (board.result.hiscore != 0 && board.result.score > board.result.hiscore) board.newRecord = true;

    // 難易度（lua: StartDifficultyDisplay）
    const int course = std::clamp(board.result.course, 0, 4);
    if (Lumen::MovieClip* difficulty = mc->Child("difficulty_mc")) {
        difficulty->SetVisible(true);
        difficulty->GotoAndStop("difficulty_" + std::to_string(course));
        static const char* const kCourseKeys[] = {"course_easy", "course_normal", "course_hard", "course_mania", "course_ura"};
        difficulty->SetText("difficulty_text", kCourseKeys[course]);
    }

    // 魂ゲージ（lua: SetTamashiiGage）
    static const char* const kGaugeTypes[] = {"easy", "normal", "normal", "hard", "hard"};
    const std::string label = std::string("result_") + kGaugeTypes[course] + (right ? "_2p" : "_1p");
    if (Lumen::MovieClip* gage = main_->Child(right ? "tamashii_gage_R" : "tamashii_gage_L")) {
        gage->GotoAndStop(label);
        board.gauge = gage->Child(label);
        Goto(board.gauge, "gage_0");
        if (Lumen::MovieClip* clear = Sub(board.gauge, "clear_text")) clear->SetText("text", "clear");
    }
    board.message = main_->Child(right ? "msg_R_mc" : "msg_L_mc");
}

void ResultScene::Finalize() {
    SoundManager::Get().StopAll();
    for (RenderTexture2D& texture : donTexture_) {
        if (texture.id != 0) UnloadRenderTexture(texture);
        texture = RenderTexture2D{};
    }
    don3d_.Unload();
    Lumen::ClearExternalTextures();
}

// ===========================================================================
// 進行（lua の Proc と同じく 60fps で1フレームずつ）
// ===========================================================================
void ResultScene::Update(float deltaTime) {
    if (!loaded_) {
        SceneManager::GetInstance().ChangeScene(std::make_unique<EntryScene>());
        return;
    }
    hitInput_ = hitInput_ || TaikoInput::AnyDon();
    // ESC: 1つ前の画面（選曲画面）へ暗転して戻る。曲数は進めない（同じ曲目をもう一度選ぶ）
    if (TaikoInput::IsBackPressed() && state_ != State::GameOver && state_ != State::End) {
        SoundManager::Get().Play(kBankSe, "don_c");
        SetState(State::End);
        SceneManager::GetInstance().ChangeScene(std::make_unique<LoadingScene>(LoadingScene::Next::SongSelect, true), true);
        return;
    }
    for (Board& board : boards_) board.don.Update(deltaTime);
    accumulator_ = std::min(accumulator_ + deltaTime, kFrame * 4.0f);
    while (accumulator_ >= kFrame) {
        accumulator_ -= kFrame;
        Step();
        hitInput_ = false;
        stage_.Update(kFrame);
    }
    if (state_ == State::GameOver) {
        gameOverTime_ += deltaTime;
        // lua: UpdateGameOver。「また遊んでね」を見せてからコピーライト、そのあとエントリー画面へ
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

void ResultScene::GoNextScene() {
    if (!isLastSong_) {
        SoundManager::Get().Play(kBankSe, "don_c");
        PlayDataManager::Get().NextSong();
        SetState(State::End);
        SceneManager::GetInstance().ChangeScene(std::make_unique<LoadingScene>(LoadingScene::Next::SongSelect, true), true);   // 暗転でつなぐ
    } else {
        StartGameOver();
    }
}

void ResultScene::SetState(State state) {
    state_ = state;
    timer_ = 0;
}

void ResultScene::Step() {
    // 演出スキップが可能な状態でドンが叩かれたら演出をスキップ
    if (enableSkip_ && hitInput_) effectSkip_ = true;

    for (Board& board : boards_) {
        if (board.active && board.scoreStarted && !board.scoreEnded) UpdateScoreDisplay(board);
    }

    switch (state_) {
    case State::Fadein:
        SoundManager::Get().PlaySlot(kBankBgm, "primal_loop", kSlotBgm);
        SetState(State::WaitUpdateTamashiiGage);
        break;

    case State::WaitUpdateTamashiiGage:
        if (timer_ > 100) {
            if (entryType_ == 0) SoundManager::Get().PlaySlot(kBankSe, "count_up_loop_l", kSlotCountUp);
            else if (entryType_ == 1) SoundManager::Get().PlaySlot(kBankSe, "count_up_loop_r", kSlotCountUp);
            else {
                SoundManager::Get().PlaySlot(kBankSe, "count_up_loop_l", kSlotCountUp);
                SoundManager::Get().PlaySlot(kBankSe, "count_up_loop_r", kSlotCountUp + 1);
            }
            enableSkip_ = true;   // 演出スキップの入力受付を開始する
            SetState(State::UpdateTamashiiGage);
        }
        break;

    case State::UpdateTamashiiGage: {
        UpdateTamashiiGage();
        bool done = true;
        for (const Board& board : boards_) done = done && (!board.active || board.shownGauge == board.result.gauge);
        if (effectSkip_ || done) SetState(State::WaitUpdateScore);
        break;
    }

    case State::WaitUpdateScore:
        if (effectSkip_ || timer_ > 100) {
            for (Board& board : boards_) board.scoreStarted = board.active;
            SetState(State::UpdateScore);
        }
        break;

    case State::UpdateScore:
        if (timer_ > 500 || effectSkip_) SetState(State::ScoreRank);
        break;

    case State::ScoreRank: {
        // スコアランクを獲得していなければ飛ばす
        bool skip = true;
        for (Board& board : boards_) {
            if (!board.active || board.result.scoreRank == 0) continue;
            skip = false;
            StartScoreRankDisplay(board);
        }
        if (skip || timer_ > 150 || effectSkip_) SetState(State::Crown);
        break;
    }

    case State::Crown: {
        bool skip = true;
        for (Board& board : boards_) {
            if (!board.active || board.result.crown == 0) continue;
            skip = false;
            StartCrownDisplay(board);
        }
        if (skip || timer_ > 150 || effectSkip_) {
            MoveResultAction();
            SetState(State::WaitEffectEnd);   // lua: "Medal"（称号はローンチでカット）を経由
        }
        break;
    }

    case State::WaitEffectEnd:
        // 失敗のどんちゃんは、倒れる動きのあと倒れたままの繰り返しにする（lua: CheckDonMotion）
        if (timer_ > 20) {
            for (Board& board : boards_) {
                if (!board.active || !board.failureMotion) continue;
                board.don.SetLoopAnimation(board.right ? "result_failure_loop_p2" : "result_failure_loop_p1");
                board.failureMotion = false;
            }
        }
        // 全部出し終えたら、ドンを叩けばすぐ次へ。叩かなければ、少し待ってから次へ進める状態にする（WaitNextScene）
        if (timer_ > kWaitEffectEndTime || (hitInput_ && timer_ > kEarlyNextGuard)) {
            const bool immediate = timer_ <= kWaitEffectEndTime;
            if (isLastSong_) {
                // 最後の曲ならセリフを消してから次へ（コインユーザーなのでごほうびはない）
                for (Board& board : boards_) {
                    if (!board.active) continue;
                    EraseMessage(board);
                    board.don.SetLoopAnimation("result_loop");
                }
            } else if (allFailure_ && !immediate) {
                // 全員クリアに失敗、かつ最後の曲でなければ「まだ1曲遊べるドン！」
                SoundManager::Get().Play(kBankVoiceResult, "continue");
            }
            SetState(State::WaitNextScene);
            if (immediate) GoNextScene();
        }
        break;

    case State::WaitNextScene:
        // ドンを叩けばすぐ次へ。叩かなくても、しばらく見せてから進む
        if (hitInput_ || timer_ > kAutoNextTime) GoNextScene();
        break;

    case State::GameOver:
    case State::End:
        break;
    }
    ++timer_;
}

// 数値を表示する（lua: ScoreCounter:SkipCounter）。上の桁の 0 は出さない
void ResultScene::SetCounter(Lumen::MovieClip* numMc, int digits, int value) {
    if (!numMc) return;
    int rest = std::max(0, value);
    for (int d = 0; d < digits; ++d) {
        Lumen::MovieClip* digit = numMc->Child("digit" + std::to_string(d + 1));
        if (d != 0 && rest == 0) break;
        Goto(digit, "num" + std::to_string(rest % 10), true);
        rest /= 10;
    }
}

// 魂ゲージを1目盛りずつ伸ばす（lua: UpdateTamashiiGage）
void ResultScene::UpdateTamashiiGage() {
    ++gaugeTimer_;
    for (int side = 0; side < 2; ++side) {
        Board& board = boards_[side];
        if (!board.active) continue;
        const int target = std::clamp(board.result.gauge, 0, kMaxGage);
        const int slot = kSlotCountUp + (entryType_ == 2 ? side : 0);
        if (effectSkip_) {
            board.shownGauge = target;
            Goto(board.gauge, "gage_" + std::to_string(target));
            SoundManager::Get().StopSlot(slot);
            if (target == kMaxGage) {
                Goto(Sub(board.gauge, "rainbow"), "fever_start", true);
                Goto(Sub(board.gauge, "fire"), "fever_start", true);
            }
        } else if (board.shownGauge < target && gaugeTimer_ > kGageSpeed * board.shownGauge) {
            ++board.shownGauge;
            Goto(board.gauge, "gage_" + std::to_string(board.shownGauge));
            if (board.shownGauge == kMaxGage) {
                Goto(Sub(board.gauge, "rainbow"), "fever_start", true);
                Goto(Sub(board.gauge, "fire"), "fever_start", true);
                SoundManager::Get().Play(kBankSeResult, board.right ? "achieve_tamashii_r" : "achieve_tamashii_l");
            }
        }
        if (board.shownGauge == target) SoundManager::Get().StopSlot(slot);
    }
}

// 良・可・不可・連打数・最大コンボ数を 50 フレームずつずらして出し、最後にためてからスコア（lua: UpdateScoreDisplay）
void ResultScene::UpdateScoreDisplay(Board& board) {
    const PlayDataManager::EnsoResult& r = board.result;
    const char* const kNames[] = {"good_num_mc", "ok_num_mc", "bad_num_mc", "dramroll_num_mc", "max_combo_num_mc"};
    const int values[] = {r.good, r.ok, r.bad, r.drumroll, r.maxCombo};
    const bool first = board.player == boards_[entryType_ == 1 ? 1 : 0].player;   // 音は 1P 側だけ
    auto showScore = [&]() {
        SetCounter(board.mc->Child("total_score_mc"), 7, r.score);
        SetCounter(board.mc->Child("total_score_back_mc"), 7, r.score);
        if (first) SoundManager::Get().Play(kBankSe, "don_big");
        DisplayHiscoreEffect(board);
        board.scoreEnded = true;
    };
    if (effectSkip_) {
        for (int i = 0; i < 5; ++i) SetCounter(board.mc->Child(kNames[i]), 4, values[i]);
        showScore();
        return;
    }
    ++board.scoreTimer;
    if (board.scoreTimer > 50 && board.scoreIndex < 5) {
        board.scoreTimer = 0;
        SetCounter(board.mc->Child(kNames[board.scoreIndex]), 4, values[board.scoreIndex]);
        ++board.scoreIndex;
        if (first) SoundManager::Get().Play(kBankSe, "count_stop_c");
    } else if (board.scoreTimer > 100 && board.scoreIndex == 5) {
        showScore();
    }
}

// ベストスコア更新の演出（lua: DisplayHiscoreEffect）
void ResultScene::DisplayHiscoreEffect(Board& board) {
    if (!board.newRecord) return;
    Lumen::MovieClip* best = board.mc->Child("best_score_mc");
    if (!best) return;
    best->SetVisible(true);
    if (Lumen::MovieClip* text = best->Child("best_score_text")) text->SetText("text", "result_bestscore");
    SetCounter(best->Child("best_score_num"), 7, board.result.score - board.result.hiscore);
    best->GotoAndPlay("start");
    SoundManager::Get().Play(kBankVoiceResult, board.right ? "bestscore_r" : "bestscore_l");
}

std::string ResultScene::Side(const Board& board) const {
    if (entryType_ != 2) return "_c";
    return board.right ? "_r" : "_l";
}

// スコアランク（lua: StartScoreRankDisplay）
void ResultScene::StartScoreRankDisplay(Board& board) {
    if (board.rankShown || board.result.scoreRank == 0) return;
    board.rankShown = true;
    const int rank = board.result.scoreRank;
    if (rank == 7) {   // 極
        Lumen::MovieClip* kiwami = board.mc->Child("score_rank_kiwami_mc");
        Visible(kiwami, true);
        Goto(kiwami, effectSkip_ ? "end" : "start", !effectSkip_);
    } else {
        const std::string label = "rank_" + std::to_string(rank);
        Lumen::MovieClip* mc = board.mc->Child("score_rank_mc");
        Visible(mc, true);
        Goto(Sub(mc, "score_rank"), label);
        Goto(Sub(mc, "score_rank_effect"), label);
        Goto(Sub(mc, "score_rank_loop"), label);
        Goto(mc, effectSkip_ ? "end" : "start", !effectSkip_);
    }
    if (!effectSkip_) {
        // lua: PlayScoreRankSE（スコアランク + 1 の番号の音）
        const int number = rank + 1;
        const std::string tone = std::string("scorerank_") + (number < 10 ? "0" : "") + std::to_string(number) + Side(board);
        SoundManager::Get().Play(kBankSeResult, tone);
    }
}

// 王冠（lua: StartCrownDisplay）
void ResultScene::StartCrownDisplay(Board& board) {
    if (board.crownShown || board.result.crown == 0) return;
    board.crownShown = true;
    static const char* const kCrowns[] = {"non", "silver", "gold", "rainbow"};
    const std::string crown = kCrowns[std::clamp(board.result.crown, 0, 3)];
    Lumen::MovieClip* mc = board.mc->Child("crown_mc");
    Visible(mc, true);
    Goto(mc, effectSkip_ ? "end" : "start", !effectSkip_);
    Goto(Sub(mc, "crown"), crown);
    Goto(Sub(mc, "crown_loop"), crown);
    if (!effectSkip_) SoundManager::Get().Play(kBankSeResult, "crown_" + crown + Side(board));
}

// 演出が終わったら、結果に合わせてどんちゃん・背景・セリフを動かす（lua: MoveResultAction）
void ResultScene::MoveResultAction() {
    std::string bgLabel = "success_";
    bool anySuccess = false;
    for (Board& board : boards_) {
        if (!board.active) continue;
        Lumen::MovieClip* don = main_->Child(board.right ? "don_R" : "don_L");
        if (board.result.resultType == 0) {
            // クリア失敗: 倒れる
            board.don.SetNonLoopAnimation(board.right ? "result_failure_p2" : "result_failure_p1");
            board.failureMotion = true;
            SoundManager::Get().Play(kBankVoice, board.right ? "sad_r" : "sad_l");
        } else {
            board.don.SetLoopAnimation("result_clear");
            SoundManager::Get().Play(kBankSeResult, "atmos_clear" + Side(board));
            SoundManager::Get().Play(kBankVoice, "glad" + Side(board));
            Goto(Sub(don, "sakura_effect"), "start", true);
            anySuccess = true;
            bgLabel += board.right && entryType_ == 2 ? "2p" : entryType_ == 2 ? "1p" : "";
        }
        DisplayMessage(board);
    }
    // 背景（lua: ResultBg:StartSuccessEffect）
    if (anySuccess && bg_) Goto(bg_, entryType_ == 2 ? bgLabel : "success", true);
}

// 魂ゲージの値からセリフの種類を決める（0〜3割未満、3割〜未クリア、クリア、満タン）
std::string ResultScene::MessageType(const Board& board) const {
    if (board.result.gauge == kMaxGage) return "perfect";
    if (board.result.resultType != 0) return "success";
    if (board.result.gauge > int(kMaxGage * 0.3f)) return "near";
    return "miss";
}

void ResultScene::DisplayMessage(Board& board) {
    if (!board.message) return;
    const std::string type = MessageType(board);
    board.message->GotoAndPlay(type);
    if (Lumen::MovieClip* text = board.message->Child("message_text")) {
        text->SetText("text_msg", "result_message_" + type + "_" + std::to_string(GetRandomValue(1, 3)));
    }
}

void ResultScene::EraseMessage(Board& board) {
    if (board.message) board.message->GotoAndPlay(MessageType(board) + "_end");
}

// ゲームオーバーの幕（lua: StartGameOver）
void ResultScene::StartGameOver() {
    SetState(State::GameOver);
    gameOverTime_ = 0.0f;
    gameOverStep_ = 0;
    Goto(gameOverMain_, "start");
    Goto(gameOverCurtain_, "oshimai_start", true);
    SoundManager::Get().StopSlot(kSlotBgm);
    SoundManager::Get().Play(kBankSe, "curtain");
    SoundManager::Get().PlaySlot(kBankBgmCommon, "gameover_primal", kSlotBgm);
    SoundManager::Get().Play(kBankVoice, "gameover");
}

// ===========================================================================
// 描画
// ===========================================================================
void ResultScene::Draw() {
    ClearBackground(BLACK);
    if (!loaded_) return;
    RenderDons();
    stage_.Draw();
    if (EnsoScene::autoUsed) CommonParts::DrawNoRecordNotice();
}

// どんちゃんを差し込み枠用のテクスチャに描く（1P は右向き、2P は左向き。lua: Don.CameraReverse）
void ResultScene::RenderDons() {
    if (!don3d_.IsLoaded()) return;
    Camera3D camera{};
    camera.target = Vector3{0.0f, 0.14f, 0.0f};
    camera.position = Vector3{0.0f, 0.2f, 1.7f};
    camera.up = Vector3{0.0f, 1.0f, 0.0f};
    camera.fovy = 0.8f;
    camera.projection = CAMERA_ORTHOGRAPHIC;
    for (int side = 0; side < 2; ++side) {
        Board& board = boards_[side];
        if (!board.active || donTexture_[side].id == 0) continue;
        board.don.Apply(don3d_);
        BeginTextureMode(donTexture_[side]);
        ClearBackground(Color{0, 0, 0, 0});
        BeginMode3D(camera);
        don3d_.Draw(board.player, don3d_.Expression(), MatrixRotateY((side == 0 ? 30.0f : -30.0f) * DEG2RAD));
        EndMode3D();
        EndTextureMode();
    }
}
