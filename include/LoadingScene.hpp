#pragma once
#include <functional>
#include <memory>

#include "LumenPlayer.hpp"
#include "Scene.hpp"
#include "SongDatabase.hpp"

// 曲選択と演奏ゲームのあいだのロード画面（lumen/000_default/loading/loading_song）
// 元のゲームでは C++ 側が出している画面なので lua はない。ラベルは in → stop（止まる）→ out → end。
// 幕の絵なので、in では前の画面の上に幕が閉じ、out では幕が開いて次の画面が見える。
//   前の画面は SceneManager に残しておいてもらい（ChangeScene の keep）、幕が閉じきるまで後ろに描く
//   幕が閉じたら前の画面を片付けて次の画面を準備し、out のあいだ後ろに描いてから引き渡す
class LoadingScene : public Scene {
public:
    // Result は演奏ゲームのあとの黒いフェード（loading_kuro_result）で、幕の絵は使わない
    enum class Next { Enso, SongSelect, Result, Other };
    // fade: 幕の代わりに黒いフェードでつなぐ（リザルト → 曲選択）
    explicit LoadingScene(Next next = Next::Enso, bool fade = false) : next_(next), fade_(fade || next == Next::Result) {}
    // 任意の画面へ暗転（黒いフェード）でつなぐ（テストモードの出入り、アトラクト → エントリーなど）
    explicit LoadingScene(std::function<std::unique_ptr<Scene>()> make) : next_(Next::Other), fade_(true), make_(std::move(make)) {}
    ~LoadingScene() override { --activeCount_; }

    // 画面の切り替えの途中か（テストスイッチを続けて押したときに切り替えを重ねない）
    static bool IsActive() { return activeCount_ > 0; }

    void Initialize() override;
    void Update(float deltaTime) override;
    void Draw() override;
    void Finalize() override;

private:
    std::unique_ptr<Scene> MakeNext() const;
    void UpdateDani(Lumen::MovieClip* root);
    void SetTipsVisible(bool visible);   // ゲームのヒントを見せる（幕が閉じきっているあいだだけ）

    Next next_;
    bool fade_ = false;
    std::function<std::unique_ptr<Scene>()> make_;
    static inline int activeCount_ = 0;
    struct Counter {
        Counter() { ++activeCount_; }
    } counter_;
    Lumen::Stage stage_;
    bool loaded_ = false;
    bool dani_ = false;     // 段位道場の1曲目へ（loading_dani_song: 月と桜の絵と段位の札）
    GuminTaiko::SongInfo song_;
    float time_ = 0.0f;
    bool closed_ = false;   // 幕が閉じきった（前の画面を片付けた）
    bool out_ = false;
    float preRun_ = 0.0f;   // 次の画面を幕の裏で進めた時間
    std::unique_ptr<Scene> previous_;
    std::unique_ptr<Scene> nextScene_;
};
