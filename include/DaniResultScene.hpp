#pragma once
#include <array>
#include <string>

#include "DaniData.hpp"
#include "DonModel.hpp"
#include "LumenPlayer.hpp"
#include "Scene.hpp"
#include "raylib.h"

// 段位道場のリザルト画面（lua: dani_result/DaniResult / DaniResultMain / DaniResultSongMain / DaniResultTotalMain /
// DaniResultDetailBase / DaniResultReward）
//   各曲の成績（3枚の板）→ 総合（魂ゲージ・スコア・良可不可など）→ お題ごとの結果 → 合否の印 → 昇段 → ゲームオーバー
//   成績は PlayDataManager::Dani()（EnsoScene が3曲ぶん残したもの）。合否を PlayRecords に記録する
// 移植していないもの: 昇段のきせかえ（段位のきぐるみ）、ごほうび、QR コード、段位フォルダ追加のお知らせ、演奏オプションのアイコン
class DaniResultScene : public Scene {
public:
    void Initialize() override;
    void Update(float deltaTime) override;
    void Draw() override;
    void Finalize() override;

private:
    enum class State {
        Songs, SongsWait, Total, TotalGauge, TotalGaugeNum, TotalWait, Detail, DetailGauge, DetailNum, DetailWait,
        Stamp, StampWait, Shoudan, ShoudanWait, Congrats, GameOver, End
    };

    void Step();
    void SetState(State state);
    void SetupSongs();
    void SetupTotal();
    void SetupDetail(int index);
    // お題の棒の色（lua: GaugeColorChange / ScoreColorChange）
    void SetDetailColor(int index, int slot, int gauge, bool max);
    void SetupShoudan();
    void RenderDon();
    void StartGameOver();
    bool Reached(Lumen::MovieClip* clip, const char* label) const;

    bool loaded_ = false;
    Lumen::Stage stage_;
    Lumen::MovieClip* main_ = nullptr;
    Lumen::MovieClip* gauge_ = nullptr;           // total_mc/dummy_tamashii_gauge/gauge_mc
    Lumen::MovieClip* shoudan_ = nullptr;
    Lumen::MovieClip* gameOverCurtain_ = nullptr;

    const GuminTaiko::DaniCourse* course_ = nullptr;
    GuminTaiko::DaniRun run_;
    int level_ = 0;
    int result_ = 0;                              // lua: g_odaiResult_（0: 不合格 1〜3: 赤 4〜6: 金。+1 が記録の rank）
    int reach_ = 0;                               // 到達した曲数
    int gaugeValue_ = 0;                          // 魂ゲージ（%）
    int prevNowDani_ = 0;                         // 挑戦前の段位
    bool shoudanFlag_ = false;                    // 昇段の演出を出す
    bool congrats_ = false;                       // 最高段位（達人）に合格した
    std::array<int, GuminTaiko::kDaniExamCount> examOrder_{};   // お題（種類のあるもの）の並び
    int examCount_ = 0;

    State state_ = State::Songs;
    int frame_ = 0;                               // いまの状態に入ってからのフレーム
    float accumulator_ = 0.0f;
    int detail_ = 0;                              // 見せているお題（0〜）
    int gaugeShown_ = 0;                          // 数え上げ中の魂ゲージ（%）
    std::array<int, 3> detailGauge_{};            // 数え上げ中のお題の棒（曲ごと）
    std::array<int, 3> detailTarget_{};
    int plateSe_ = 0;                             // 板が出る音を鳴らした数
    bool hit_ = false;
    bool skipGauge_ = false;   // 総合の途中で叩いた（魂ゲージをすぐに数え終える）
    float gameOverTime_ = 0.0f;
    int gameOverStep_ = 0;

    DonAnimator don_;
    DonModel don3d_;
    RenderTexture2D donTexture_{};
};
