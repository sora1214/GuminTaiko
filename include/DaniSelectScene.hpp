#pragma once
#include <array>
#include <string>

#include "DaniData.hpp"
#include "DonModel.hpp"
#include "LumenPlayer.hpp"
#include "Scene.hpp"
#include "raylib.h"

// 段位道場の段位選択画面（lua: dani_select_all / dani_select_dani_main / dani_select_theme_disp_data /
// dani_select_confirmation_main / dani_select_introduction_main）
//   導入の演出 → 段位の札が落ちてくる → お題の板が出る → ふちで段位を選ぶ → 面で「挑戦するのカッ？」 → 演奏へ
//   お題は Dani/*.json（DaniDatabase）。五級〜十段は最初から、玄人から上は1つ下に合格すると選べる（本家と同じ）。
//   お題のない段位は選べない
// 移植していないもの: 段位道場の演奏オプション、QR コード（外伝は 20 枚目の板として、ほかの段位と同じように選ぶ）
class DaniSelectScene : public Scene {
public:
    void Initialize() override;
    void Update(float deltaTime) override;
    void Draw() override;
    void Finalize() override;

private:
    enum class State { Intro, BoardIn, SlideInWait, SlideIn, Main, ConfirmIn, Confirm, ConfirmOut, Decided, End };

    void Step();
    void SetState(State state);
    void MoveCursor(int direction);
    void SetDetail(Lumen::MovieClip* board, int level);   // お題の板（lua: DaniDispData:AdaptationDaniData）
    void SetDetailStamp(const char* name, int level);
    void OpenConfirm();
    void CloseConfirm(bool decide);
    void Decide();
    void RenderDon();
    bool IsOpen(int level) const;
    const char* StampLabel(int level) const;

    bool loaded_ = false;
    Lumen::Stage stage_;
    Lumen::MovieClip* main_ = nullptr;
    Lumen::MovieClip* boards_ = nullptr;          // main/board_all/normal
    Lumen::MovieClip* intro_ = nullptr;           // introduction_instance/main
    bool introSePlayed_ = false;                  // 導入の音を鳴らした
    Lumen::MovieClip* window_ = nullptr;          // window_instance/main
    Lumen::MovieClip* timeCount_ = nullptr;

    State state_ = State::Intro;
    int stateFrame_ = 0;
    float accumulator_ = 0.0f;
    int current_ = 1;                             // 選んでいる段位
    std::array<bool, GuminTaiko::kDaniLevelCount + 1> open_{};
    std::array<int, GuminTaiko::kDaniLevelCount + 1> rank_{};   // 合格の段階（PlayRecords の DaniRecord::rank）
    int nowDani_ = 0;
    std::string owner_;
    int inputWait_ = 0;
    int confirmCursor_ = 0;                       // 0: 挑戦する 1: 挑戦しない

    float timer_ = 100.0f;
    bool timerRunning_ = false;
    int timerShown_ = -1;
    bool timerEnabled_ = true;

    DonModel don3d_;
    RenderTexture2D donTexture_{};
    struct Input {
        bool don = false, kaLeft = false, kaRight = false, back = false;
    } input_;
};
