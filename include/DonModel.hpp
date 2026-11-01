#pragma once
#include <array>
#include <string>
#include <vector>

#include "DonCostume.hpp"
#include "Ssbh.hpp"
#include "raylib.h"

// 3D のどんちゃん（Data/x64/model の SSBH モデル）
//   body_* … 太鼓の胴・手足と、顔・お尻の円盤（マスク画像の R/G/B に色を乗せる）と、着せかえの飾り（画像をそのまま貼る）
//   head_* … 顔の前の板（model/face の表情画像を貼る）と、頭の飾り
//   cos_*  … きぐるみ（体と頭をまるごと置き換える）
// 1P と 2P で別々の着せかえにできる（SetCostume）。姿勢は共通
// 姿勢は Data/x64/animation のアニメーションから作り、CPU でスキニングする。
class DonModel {
public:
    struct Colors {
        Vector3 r;   // マスクの R の部分
        Vector3 g;   // G の部分
        Vector3 b;   // B の部分
    };

    // 着せかえ（中身は DonCostume.hpp）
    using Costume = DonCostume;
    // エントリーの「きせかえ」の組（0: いつもの 1: クール 2: キュート 3: ジョーク）。中身は Data/x64/don_presets.ini で変えられる
    static Costume Preset(int index);
    static constexpr int kPresetCount = 4;
    static constexpr int kCostumeRandom = kDonCostumeRandom;   // おまかせ
    static constexpr int kCostumeCustom = kDonCostumeCustom;   // じぶんで選んだ着せかえ（すべてのパーツから）
    // おまかせ: きぐるみ（Data/x64/model/cos にあるもの）から1つ選ぶ。番号を返す
    static int RandomKigurumi();
    // エントリーで決めたきせかえ（costume: 0〜3 は組、4 はおまかせで kigurumi を着る、5 は custom をそのまま着る）
    static Costume FromEntry(int costume, int kigurumi, const Costume& custom = Costume());

    bool Load();
    void Unload();
    bool IsLoaded() const { return loaded_; }
    // side（0: 1P / 1: 2P）の着せかえを変える（同じなら何もしない）。Load の前でも後でもよい
    void SetCostume(int side, const Costume& costume);

    // アニメーション（例: "don_select_loop"）の frame の時点の姿勢にする
    bool SetPose(const std::string& animation, float frame = 0.0f);
    // 繰り返すアニメーションを、再生を始めてから seconds 秒の時点の姿勢にする
    bool PlayLoop(const std::string& animation, float seconds);
    // 今の姿勢のアニメーションが指定する表情の番号（FaceAnim。指定がなければ 0）
    int Expression() const { return expression_; }

    // BeginMode3D の中で呼ぶ。side 0: どんちゃん / 1: かっちゃん。expression は表情の番号（0〜11）
    void Draw(int side, int expression, Matrix transform) const;

    static Colors DefaultColors(int side);

    void SetOutline(bool enabled) { outline_ = enabled; }

private:
    using Mat4 = std::array<float, 16>;

    struct Part {
        Mesh mesh{};
        Texture2D texture{};
        bool face = false;
        bool plain = false;   // 色を乗せず画像をそのまま貼る（taikoEffect。着せかえの飾り）
        int skeleton = -1;
        std::vector<float> bindPositions;
        std::vector<float> bindNormals;
        std::vector<std::array<int, 4>> joints;
        std::vector<std::array<float, 4>> weights;
    };

    // 1人分の見た目
    struct Set {
        std::vector<Part> parts;
        const std::vector<Texture2D>* faces = nullptr;
        Costume costume;
        bool built = false;
    };

    bool LoadPart(Set& set, const std::string& name);
    bool BuildSet(int side);
    void ReapplyPose();
    void ApplyPose(const std::vector<std::pair<std::string, Ssbh::BonePose>>& pose);

    bool loaded_ = false;
    std::array<Set, 2> sets_;
    std::vector<Ssbh::Skeleton> skeletons_;
    std::vector<std::vector<Mat4>> inverseBind_;
    Shader shader_{};
    Shader outlineShader_{};
    int outlineWidthLoc_ = -1;
    bool outlineCullFront_ = true;
    bool outline_ = true;   // 面の向き（頂点の並び）によって捨てる側が変わる
    int modeLoc_ = -1;
    int colorLoc_[3] = {-1, -1, -1};
    std::string poseName_;
    float poseFrame_ = -1.0f;
    int expression_ = 0;
};

// どんちゃん1人分のアニメーションの進み（lua の Don.SetLoopAnimation / Don.SetNonLoopAnimation と同じ使い方）
//   名前は lua と同じ（"normal", "kusu_in_p1", "result_failure_p2" など）で、ファイル名（don_*.nuanmb）に読み替える。
//   ループしないアニメーションは1回流したあと、最後に指定したループのアニメーションに戻る。
// モデルは1つを使い回すので、描く直前に Apply で姿勢を当てる
class DonAnimator {
public:
    // restart: 同じアニメーションが指定されていても頭から流し直す（lua の第3引数）
    void SetLoopAnimation(const std::string& name, bool restart = true);
    void SetNonLoopAnimation(const std::string& name, bool restart = true);
    // ループのアニメーションを流す速さ（1 でデータどおり）。ループしないアニメーションには効かない
    //   （演奏中は、曲のいまの BPM に合わせてどんちゃんが踊るように EnsoScene が決める）
    void SetLoopRate(float rate) { loopRate_ = rate; }
    void Update(float deltaTime) { time_ += deltaTime * (once_.empty() ? loopRate_ : 1.0f); }
    void Apply(DonModel& model);
    // ループしないアニメーションを流している最中か
    bool IsPlayingNonLoop() const;

    static std::string FileName(const std::string& luaName);
    // アニメーションのファイルを先に読み込んでおく（初めて流すときにファイルを読んで、1フレームが止まらないように）
    static void Preload(const std::string& luaName);

private:
    std::string loop_ = "don_normal";
    std::string once_;
    float time_ = 0.0f;       // いま流しているアニメーションの経過時間（秒。ループは loopRate_ 倍の速さで進む）
    float loopRate_ = 1.0f;
};
