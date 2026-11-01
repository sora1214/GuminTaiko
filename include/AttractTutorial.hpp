#pragma once
#include <string>
#include <vector>

#include "DonModel.hpp"
#include "LumenPlayer.hpp"
#include "raylib.h"

// あそびかた説明（Data/x64/lua/attract/tutorial.lua を移植したもの）
//   lumen/000_default/tutorial/tutorial のルートを fade_in → scene_01 〜 scene_10 → fade_out と進め、
//   シーンごとに説明の文言・ボイス・効果音・スコアの加算・どんちゃんの動き（風船・くす玉）を lua と同じフレームで出す。
//   スコアは enso の score を4つ読み込み、加点の表示を順に使い回す（加点の 32 フレーム後にスコアが跳ねて増える）。
// lua の「フチを5回叩くと説明がおわる」は、エントリーしたプレイヤーがいるときだけ（アトラクトでは誰もいないので効かない）。
class AttractTutorial {
public:
    bool Start();
    void Step();                 // lua の Proc（60fps で1回）
    void Advance();              // Lumen を1フレーム進める
    void Draw();
    void Finish();
    bool IsFinished() const { return state_ == "End"; }

private:
    struct AddScore {
        Lumen::MovieClip* mc = nullptr;
        Lumen::MovieClip* digit[6] = {};
    };
    struct PendingScore {
        int counter = 0;
        int plus = 0;
    };

    void SetState(const std::string& state);
    void EnterScene(int number, const std::string& voice);
    void ScorePlus(int num);
    void ScorePlusSound(int num, const char* bank, const char* tone);
    void ScoreUpdate();
    void ScoreListUpdate();
    void Scene2(int frame);
    void Scene3(int frame);
    void Scene4(int frame);
    void Scene5(int frame);
    void Scene6(int frame);
    void Scene7(int frame);
    void Scene8(int frame);
    void Scene9(int frame);
    void Scene10(int frame);
    void KusudamaInit();
    void KusudamaStart();
    void KusudamaUpdate(int frame);
    void PlayBgm();
    void RenderDon();

    Lumen::Stage stage_;
    bool loaded_ = false;
    std::string state_ = "Begin";
    int count_ = 0;

    Lumen::MovieClip* main_ = nullptr;
    Lumen::MovieClip* scene_ = nullptr;
    Lumen::MovieClip* don1p_ = nullptr;
    Lumen::MovieClip* fadeLane_ = nullptr;

    // スコア
    Lumen::MovieClip* scoreDigit_[7] = {};
    int currentScore_ = 0;
    AddScore addScore_[4];
    int addScoreCurrent_ = 0;
    std::vector<PendingScore> addScoreList_;

    // くす玉
    bool kusudamaActive_ = false;
    int kusudamaFrame_ = 0;
    Lumen::MovieClip* kusudamaRoot_ = nullptr;
    Lumen::MovieClip* kusudamaHit_ = nullptr;
    Lumen::MovieClip* kusudamaRendasText_ = nullptr;
    Lumen::MovieClip* kusudamaSuccessHigh_ = nullptr;
    Lumen::MovieClip* kusuDigit1_ = nullptr;

    bool fadeOut_ = false;
    int bgmWait_ = 0;   // BGM の終わりを待つ上限（フレーム）

    DonModel don3d_;
    DonAnimator don_;
    RenderTexture2D donTexture_{};
};
