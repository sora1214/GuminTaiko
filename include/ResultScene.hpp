#pragma once
#include <string>

#include "DonModel.hpp"
#include "LumenPlayer.hpp"
#include "PlayData.hpp"
#include "Scene.hpp"
#include "raylib.h"

// リザルト画面（Data/x64/lua/result/ResultMain.lua・ScoreBase.lua・ResultBg.lua を移植したもの）
//   魂ゲージが1目盛りずつ伸びる → 良・可・不可・連打数・最大コンボ数・スコアの順に出る → スコアランク → 王冠
//   → どんちゃんの動き・背景・セリフ → 次の曲へ（最後の曲ならゲームオーバーの幕からエントリー画面へ）
// 移植していないもの: ごほうび・どんメダル・イベントトークン・QR・コラボキャラ・演奏オプションのアイコン
class ResultScene : public Scene {
public:
    void Initialize() override;
    void Update(float deltaTime) override;
    void Draw() override;
    void Finalize() override;

private:
    enum class State {
        Fadein, WaitUpdateTamashiiGage, UpdateTamashiiGage, WaitUpdateScore, UpdateScore, ScoreRank, Crown,
        WaitEffectEnd, WaitNextScene, GameOver, End,
    };

    // 1人分のスコアの板（lua: ScoreBase）
    struct Board {
        bool active = false;
        int player = 0;              // PlayData のプレイヤー番号（0: 左 1: 右）
        bool right = false;          // 右側に出す
        GuminTaiko::PlayDataManager::EnsoResult result;
        Lumen::MovieClip* mc = nullptr;
        Lumen::MovieClip* gauge = nullptr;     // 魂ゲージ（result_xxx_1p など）
        Lumen::MovieClip* message = nullptr;   // セリフ（msg_L_mc / msg_R_mc）
        int shownGauge = 0;
        int scoreIndex = 0;          // 次に出す数値（0: 良 〜 4: 最大コンボ、5: スコア）
        int scoreTimer = 0;
        bool scoreStarted = false, scoreEnded = false;
        bool rankShown = false, crownShown = false;
        bool newRecord = false;
        bool failureMotion = false;  // 失敗のどんちゃんの動きを流している
        DonAnimator don;
    };

    void Step();                     // 1フレーム分（60fps）
    void SetState(State state);
    void SetupBoard(Board& board, bool right);
    void SetCounter(Lumen::MovieClip* numMc, int digits, int value);   // lua: ScoreCounter:SkipCounter
    void UpdateTamashiiGage();
    void UpdateScoreDisplay(Board& board);
    void DisplayHiscoreEffect(Board& board);
    void StartScoreRankDisplay(Board& board);
    void StartCrownDisplay(Board& board);
    void MoveResultAction();
    void DisplayMessage(Board& board);
    void EraseMessage(Board& board);
    void StartGameOver();
    void GoNextScene();               // 次へ（まだ曲が遊べるなら選曲へ暗転、最後の曲ならゲームオーバー）
    std::string MessageType(const Board& board) const;
    std::string Side(const Board& board) const;
    void RenderDons();

    Lumen::Stage stage_;
    bool loaded_ = false;
    Lumen::MovieClip* main_ = nullptr;
    Lumen::MovieClip* bg_ = nullptr;          // 背景の動く部分（bg_1p_l など）
    Lumen::MovieClip* gameOverMain_ = nullptr;
    Lumen::MovieClip* gameOverCurtain_ = nullptr;
    Board boards_[2];                          // [0] 左 [1] 右
    int entryType_ = 0;                        // 0: 左で1人 1: 右で1人 2: 2人

    State state_ = State::Fadein;
    int timer_ = 0;
    int gaugeTimer_ = 0;
    float accumulator_ = 0.0f;
    bool enableSkip_ = false;
    bool effectSkip_ = false;
    bool allFailure_ = true;
    bool isLastSong_ = false;
    bool hitInput_ = false;                    // 次に進むフレームまで覚えておく面の入力
    float gameOverTime_ = 0.0f;
    int gameOverStep_ = 0;

    DonModel don3d_;
    RenderTexture2D donTexture_[2] = {};
};
