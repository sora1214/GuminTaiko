#include "AttractScene.hpp"

#include <algorithm>

#include "EntryScene.hpp"
#include "GameSettings.hpp"
#include "LoadingScene.hpp"
#include "PlayData.hpp"
#include "SceneManager.hpp"
#include "SoundManager.hpp"
#include "TaikoInput.hpp"

using namespace GuminTaiko;

namespace {

constexpr const char* kDir = "lumen/000_default/attract/";
constexpr float kStep = 1.0f / 60.0f;
constexpr float kFadeSeconds = 0.33f;
constexpr int kFps = 60;

// タイトル（title_main.lua）
constexpr int kTitleTotal = int(kFps * 6.5f);
constexpr int kTitleCall = int(kFps * 1.5f);
// バチの注意（caution.lua）
constexpr int kCautionTotal = 7 * kFps;
constexpr int kCautionVoiceFrame = 32 - 1;   // lua の current_frame は 1 から
// 曲紹介（musicintro_main.lua）
constexpr int kIntroSongCount = 5;           // 紹介する曲の数（lua の MusicIntroSongNum は C++ 側が決める）
constexpr int kIntroOneSong = 5 * kFps;
constexpr int kIntroPlayTime = int(4.5f * kFps);
// 再生が止まらない画面の上限
constexpr int kPlayLimit = 15 * kFps;

constexpr int kSlotBgm = 0;
constexpr int kSlotVoice = 1;

void Hide(Lumen::Stage& stage, const char* name) {
    if (Lumen::MovieClip* clip = stage.GetMovieClip(name)) clip->SetVisible(false);
}

} // namespace

void AttractScene::Initialize() {
    GameSettings::Get().SetAttract(true);
    GameSettings::Get().SetPlaying(false);
    PlayDataManager::Get().ResetEntries();
    lastCoins_ = PlayDataManager::Get().Coins();
    for (const char* bank : {"bgm_common_v12a", "voice_common_v12a", "se_common_v12a"}) SoundManager::Get().Preload(bank);
    StartScreen(boot_ ? Screen::Notice : Screen::Title);
}

void AttractScene::Finalize() {
    SoundManager::Get().StopAll();
    GameSettings::Get().SetAttract(false);
}

// ===========================================================================
// 画面の切り替え
// ===========================================================================
void AttractScene::StartScreen(Screen screen) {
    screen_ = screen;
    nowTime_ = 0;
    ending_ = false;
    fade_ = 1.0f;
    main_ = nullptr;
    loaded_ = false;
    stage_ = Lumen::Stage();

    switch (screen) {
    case Screen::Notice:
        loaded_ = stage_.Load(std::string(kDir) + "notice");
        main_ = stage_.GetMovieClip("notice_instance_0");
        if (main_) main_->GotoAndPlay(0);
        break;
    case Screen::Title:
        loaded_ = stage_.Load(std::string(kDir) + "title");
        Hide(stage_, "banner_instance");
        Hide(stage_, "numberofstage_instance");
        break;
    case Screen::MusicIntro:
        loaded_ = stage_.Load(std::string(kDir) + "musicintro");
        Hide(stage_, "banner_instance");
        Hide(stage_, "numberofstage_instance");
        main_ = stage_.GetMovieClip("musicintro_instance");
        if (main_) {
            songInfo_ = main_->Find("songname_instance");
            for (int i = 0; i < 4; ++i) otherSongInfo_[i] = main_->Find(TextFormat("songnamesame_instance_%d", i));
            main_->SetText("othersong_text_instance", "text_othersongs", "attract_othersongs");
        }
        BuildIntroSongs();
        introIndex_ = 0;
        introSoundState_ = "Wait";
        if (introSongs_.empty()) loaded_ = false;
        else DispMusicInfo();
        // 曲の変換を先に始めておく
        for (const IntroSong& song : introSongs_) SoundManager::Get().PrepareSong(song.main->SoundBank());
        break;
    case Screen::BNLogo:
        loaded_ = stage_.Load(std::string(kDir) + "bnlogo");
        Hide(stage_, "banner_instance");
        main_ = stage_.GetMovieClip("bnlogo_instance_0");
        if (main_) main_->GotoAndPlay(0);
        break;
    case Screen::Caution:
        loaded_ = stage_.Load(std::string(kDir) + "caution");
        main_ = stage_.GetMovieClip("caution_instance_0");
        if (main_) main_->GotoAndPlay(0);
        break;
    case Screen::Copyright:
        loaded_ = stage_.Load(std::string(kDir) + "copyright");
        main_ = stage_.GetMovieClip("copyright_instance_0");
        if (main_) {
            main_->GotoAndPlay(0);
            main_->SetText("text_instance_0", "text01", "copyright_01");
            main_->SetText("text_instance_0", "text02", "copyright_02");
            main_->SetText("text_instance_1", "text01", "copyright_03");
            main_->SetText("text_instance_1", "text02", "copyright_04");
        }
        break;
    }
    // 読み込めなかった画面は飛ばす
    if (!loaded_) ending_ = true;
}

void AttractScene::NextScreen() {
    // 起動時だけ NOTICE → 権利表記、そのあとは タイトル → 曲紹介 → バチの注意 を繰り返す
    switch (screen_) {
    case Screen::Notice: StartScreen(Screen::Copyright); break;
    case Screen::Copyright: StartScreen(Screen::Title); break;
    case Screen::Title: StartScreen(Screen::MusicIntro); break;
    case Screen::MusicIntro: StartScreen(Screen::Caution); break;
    case Screen::BNLogo:
    case Screen::Caution: StartScreen(Screen::Title); break;
    }
}

void AttractScene::EndScreen() {
    if (ending_) return;
    ending_ = true;
    if (screen_ == Screen::Title) {
        SoundManager::Get().StopSlot(kSlotVoice);
        SoundManager::Get().StopSlot(kSlotBgm);
    }
    if (screen_ == Screen::MusicIntro) SoundManager::Get().StopPreview(kFadeSeconds);
}

// エントリー画面へは暗転で切り替える（暗転のあいだはこの画面を止めたまま後ろに描く）
void AttractScene::GoEntry() {
    if (goingEntry_) return;
    goingEntry_ = true;
    SoundManager::Get().StopAll();
    SceneManager::GetInstance().ChangeScene(
        std::make_unique<LoadingScene>([] { return std::unique_ptr<Scene>(std::make_unique<EntryScene>()); }), true);
}

// ===========================================================================
// 進行
// ===========================================================================
void AttractScene::Update(float deltaTime) {
    // コイン・カード・（クレジットがあれば）面を叩くとエントリーへ
    PlayDataManager& pd = PlayDataManager::Get();
    // NOTICE と権利表記のあいだは、面を叩いてもエントリーへ行かない（起動時の表示を最後まで見せる）
    const bool bootScreen = screen_ == Screen::Notice || screen_ == Screen::Copyright;
    if (pd.Coins() > lastCoins_ || TaikoInput::IsCardTouched() || TaikoInput::IsNewCardTouched() ||
        (!bootScreen && TaikoInput::AnyDon() && pd.CanPay())) {
        GoEntry();
        return;
    }
    lastCoins_ = pd.Coins();
    if (TaikoInput::IsFreePlayToggled()) GameSettings::Get().SetValue("ItemFreePlay", pd.IsFreePlay() ? 0 : 1);

    accumulator_ = std::min(accumulator_ + deltaTime, kStep * 4.0f);
    while (accumulator_ >= kStep) {
        accumulator_ -= kStep;
        Step();
    }
}

void AttractScene::Step() {
    // 画面の切り替えは暗転をはさむ（lua の FadeFlag）
    if (ending_) {
        fade_ += kStep / kFadeSeconds;
        if (fade_ >= 1.0f) NextScreen();
        return;
    }
    const bool fadingIn = fade_ > 0.0f;
    if (fadingIn) fade_ = std::max(0.0f, fade_ - kStep / kFadeSeconds);

    switch (screen_) {
    case Screen::Notice:
    case Screen::BNLogo:
    case Screen::Copyright:
        // 再生が終わったら次へ
        ++nowTime_;
        if ((main_ && !main_->IsPlay() && nowTime_ > 1) || nowTime_ > kPlayLimit) EndScreen();
        break;
    case Screen::Title:
        if (fadingIn) break;   // FadeInWait
        if (nowTime_ == 0) SoundManager::Get().PlaySlot("bgm_common_v12a", "title_v12a", kSlotBgm);
        ++nowTime_;
        if (nowTime_ == kTitleCall) SoundManager::Get().PlaySlot("voice_common_v12a", "title", kSlotVoice);
        if (nowTime_ > kTitleTotal) EndScreen();
        break;
    case Screen::Caution:
        ++nowTime_;
        if (main_ && main_->CurrentFrame() == kCautionVoiceFrame && main_->IsPlay()) {
            // 「危険なので、バチをふりまわしたり太鼓以外のものを叩いたりしないでね」
            SoundManager::Get().Play("voice_common_v12a", "caution");
        }
        if (nowTime_ > kCautionTotal) EndScreen();
        break;
    case Screen::MusicIntro:
        if (fadingIn) break;   // FadeInWait
        if (nowTime_ == 0 && introSoundState_ == "Wait" && introIndex_ == 0) {
            SoundManager::Get().PlayPreview(introSongs_[0].main->SoundBank(), 0.0f, true);
            introSoundState_ = "LoadWait";
            introLoadCounter_ = 0;
        }
        UpdateIntroSound();
        ++nowTime_;
        if (nowTime_ > kIntroOneSong) {
            // 曲の切り替え
            if (introIndex_ + 1 >= int(introSongs_.size())) {
                EndScreen();
            } else if (introSoundState_ == "Wait") {
                ++introIndex_;
                DispMusicInfo();
                nowTime_ = 1;
                SoundManager::Get().PlayPreview(introSongs_[size_t(introIndex_)].main->SoundBank(), 0.0f, true);
                introSoundState_ = "LoadWait";
                introLoadCounter_ = 0;
            }
        } else if (nowTime_ > kIntroPlayTime) {
            FadeOutIntro();
        }
        break;
    }
    stage_.Update(kStep);
}

// ===========================================================================
// 曲紹介
// ===========================================================================
void AttractScene::BuildIntroSongs() {
    introSongs_.clear();
    SongDatabase& db = SongDatabase::Get();
    // 新曲を、ジャンルが偏らないように順に選ぶ（なければジャンルの先頭の曲）
    std::vector<const SongInfo*> picked;
    for (int round = 0; round < 2 && int(picked.size()) < kIntroSongCount; ++round) {
        for (const GenreInfo& genre : db.Genres()) {
            if (int(picked.size()) >= kIntroSongCount) break;
            for (const SongInfo* song : db.SongsInGenre(genre.genreNo)) {
                if (std::find(picked.begin(), picked.end(), song) != picked.end()) continue;
                if (song->sample) continue;   // TJA のない曲（サンプルの譜面）は紹介しない
                if (round == 0 && !song->isNew) continue;
                picked.push_back(song);
                break;
            }
        }
    }
    for (const SongInfo* song : picked) {
        IntroSong intro;
        intro.main = song;
        // 一緒に出す曲: 同じジャンルの曲（新曲を先に）
        for (int pass = 0; pass < 2 && intro.subs.size() < 4; ++pass) {
            for (const SongInfo* other : db.SongsInGenre(song->genreNo)) {
                if (intro.subs.size() >= 4) break;
                if (other == song || other->sample || (pass == 0) != other->isNew) continue;
                if (std::find(intro.subs.begin(), intro.subs.end(), other) != intro.subs.end()) continue;
                intro.subs.push_back(other);
            }
        }
        introSongs_.push_back(std::move(intro));
    }
}

void AttractScene::DispSong(Lumen::MovieClip* mc, const SongInfo* song) {
    if (!mc) return;
    if (!song) {
        mc->GotoAndStop("off");
        mc->SetVisible(false);
        return;
    }
    mc->SetVisible(true);
    mc->GotoAndStop("on");
    if (Lumen::MovieClip* text = mc->Find("text_instance")) {
        text->SetText("text_songname", "song_" + song->id);
        text->SetText("text_songnamesub", "song_sub_" + song->id);
        text->SetText("text_songnameruby", "song_detail_" + song->id);
    }
    if (Lumen::MovieClip* g = mc->Find("genre_instance")) g->SetText("text_genre", SongDatabase::GenreTextKey(song->genreNo));
    // 板の色（ラベル genre_pops など）。バラエティ（緑）・クラシック（黄色）の板はないので、白っぽい板を染める
    if (Lumen::MovieClip* base = mc->Find("genre_base_instance")) {
        base->GotoAndStop(std::string("genre_") + SongDatabase::GenrePlateLabel(song->genreNo));
        const std::array<float, 3> tint = SongDatabase::GenrePlateTint(song->genreNo);
        base->SetTint(Lumen::ColorF{tint[0], tint[1], tint[2], 1.0f});
    }
}

void AttractScene::DispMusicInfo() {
    const IntroSong& song = introSongs_[size_t(introIndex_)];
    DispSong(songInfo_, song.main);
    for (int i = 0; i < 4; ++i) DispSong(otherSongInfo_[i], i < int(song.subs.size()) ? song.subs[size_t(i)] : nullptr);
}

void AttractScene::FadeOutIntro() {
    // 再生中ならフェードアウト
    if (introSoundState_ != "Play") return;
    SoundManager::Get().StopPreview(0.5f);
    introSoundState_ = "FadeOut";
    if (songInfo_) songInfo_->GotoAndPlay("out");
    const IntroSong& song = introSongs_[size_t(introIndex_)];
    for (int i = 0; i < 4 && i < int(song.subs.size()); ++i) {
        if (otherSongInfo_[i]) otherSongInfo_[i]->GotoAndPlay("out");
    }
}

void AttractScene::UpdateIntroSound() {
    ++introLoadCounter_;
    SoundManager& sound = SoundManager::Get();
    if (introSoundState_ == "FadeOut") {
        if (!sound.IsPreviewPlaying()) introSoundState_ = "Wait";
    } else if (introSoundState_ == "LoadWait") {
        // 曲の変換が済んだら鳴り始める。済まないまま時間が過ぎたら、この曲は鳴らさない
        if (sound.IsPreviewStarted()) introSoundState_ = "Play";
        else if (introLoadCounter_ > kIntroOneSong) introSoundState_ = "Wait";
    } else if (introSoundState_ == "Play" && nowTime_ > kIntroOneSong) {
        introSoundState_ = "Wait";
    }
}

// ===========================================================================
// 描画
// ===========================================================================
void AttractScene::Draw() {
    ClearBackground(BLACK);
    if (loaded_) stage_.Draw();
    if (fade_ > 0.0f) DrawRectangle(0, 0, 1920, 1080, Color{0, 0, 0, (unsigned char)(std::min(1.0f, fade_) * 255.0f)});
}
