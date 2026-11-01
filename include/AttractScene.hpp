#pragma once
#include <memory>
#include <string>
#include <vector>

#include "LumenPlayer.hpp"
#include "Scene.hpp"
#include "SongDatabase.hpp"

// アトラクト（Data/x64/lua/attract の各画面を移植したもの）
//   起動したときだけ: NOTICE（notice.lua）→ 権利表記（copyright.lua）。このあいだは面を叩いてもエントリーへ行かない
//   繰り返し: タイトル（title_main.lua）→ 曲紹介（musicintro_main.lua）→ バチの注意（caution.lua）
//   （あそびかた tutorial.lua と BANDAI NAMCO のロゴ bnlogo.lua は出さない）
//   画面の順番は C++ 側が決めていて lua にはないので、この順にしている。
//   アトラクトムービー（attractmovie.lua）は WMV の動画の上にバナーを重ねる画面で、動画を再生できないので出さない。
//   バナー（common/banner）の中身は筐体の設定（Cabinet.AttractBanner）で決まるので出さない。
// どの画面でも、コインを入れる・カードをタッチする・（クレジットがあれば）面を叩くとエントリー画面へ。
class AttractScene : public Scene {
public:
    explicit AttractScene(bool boot = false) : boot_(boot) {}

    void Initialize() override;
    void Update(float deltaTime) override;
    void Draw() override;
    void Finalize() override;

private:
    enum class Screen { Notice, Title, MusicIntro, BNLogo, Caution, Copyright };

    struct IntroSong {
        const GuminTaiko::SongInfo* main = nullptr;
        std::vector<const GuminTaiko::SongInfo*> subs;   // 一緒に出す曲（最大4）
    };

    void StartScreen(Screen screen);
    void NextScreen();
    void Step();                  // 1フレーム（60fps）ぶんの lua の Proc
    void EndScreen();             // lua の Common.LuaFinish

    // 曲紹介
    void BuildIntroSongs();
    void DispMusicInfo();
    void DispSong(Lumen::MovieClip* mc, const GuminTaiko::SongInfo* song);
    void UpdateIntroSound();
    void FadeOutIntro();

    void GoEntry();

    bool boot_;
    Screen screen_ = Screen::Title;
    Lumen::Stage stage_;
    bool loaded_ = false;
    bool goingEntry_ = false;     // エントリー画面へ暗転し始めた

    int nowTime_ = 0;             // 画面が始まってからのフレーム
    bool ending_ = false;         // 暗転して次の画面へ
    float fade_ = 1.0f;           // 画面の暗さ（1 で真っ黒）
    float accumulator_ = 0.0f;
    Lumen::MovieClip* main_ = nullptr;

    // 曲紹介
    std::vector<IntroSong> introSongs_;
    int introIndex_ = 0;
    std::string introSoundState_ = "Wait";
    int introLoadCounter_ = 0;
    Lumen::MovieClip* songInfo_ = nullptr;
    Lumen::MovieClip* otherSongInfo_[4] = {};

    int lastCoins_ = 0;
};
