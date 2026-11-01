#include "LoadingScene.hpp"

#include <string>

#include "DaniData.hpp"
#include "EnsoScene.hpp"
#include "PlayData.hpp"
#include "ResultScene.hpp"
#include "SceneManager.hpp"
#include "SongSelectScene.hpp"
#include "SoundManager.hpp"
#include "raylib.h"

using namespace GuminTaiko;

namespace {

constexpr const char* kMovie = "lumen/000_default/loading/loading_song";
constexpr const char* kFadeMovie = "lumen/000_default/loading/loading_kuro_result";   // 演奏ゲーム → リザルト → 曲選択
// 段位道場の1曲目の前（2曲目からは演奏画面の幕 dani_enso_between）。in で前の画面が暗くなり（stop で暗転しきる）、
// 絵が出て out までゆっくり動き、end で演奏画面に切り替わる（幕はないので、そのまま切り替える）
constexpr const char* kDaniMovie = "lumen/000_default/enso_dani/loading_dani/loading_dani_song";
constexpr float kMinShowSeconds = 2.5f;   // 幕が開き始めるまでの最短の時間
constexpr float kPreRunSeconds = 0.6f;    // 曲選択の出てくる演出（27 フレーム）を幕の裏で進める時間
// 暗転（loading_kuro_result）を流す速さ。データのままだと暗くなるまで 110 フレーム（約 1.8 秒）、明けるまで 20 フレームかかるので速める
//   暗くなるまで 約 0.3 秒、明けるまで 約 0.17 秒
constexpr float kFadeInSpeed = 6.0f;
constexpr float kFadeOutSpeed = 2.0f;
// ヒントの文言（tips001〜012。どんメダル・AI バトルの話は、この移植にない機能なので出さない）
constexpr int kTipsCount = 12;

} // namespace

std::unique_ptr<Scene> LoadingScene::MakeNext() const {
    if (make_) return make_();
    if (next_ == Next::SongSelect) return std::make_unique<SongSelectScene>();
    if (next_ == Next::Result) return std::make_unique<ResultScene>();
    return std::make_unique<EnsoScene>();
}

void LoadingScene::Initialize() {
    previous_ = SceneManager::GetInstance().TakeKeptScene();

    const PlayDataManager& pd = PlayDataManager::Get();
    // 曲が要るのは演奏へ行くときだけ（曲の一覧は起動のときに読み込んである）
    if (next_ == Next::Enso) {
        if (const SongInfo* song = SongDatabase::Get().FindSong(pd.SelectedSong())) song_ = *song;
    }
    // 演奏で流す曲の変換を今のうちに始める
    if (next_ == Next::Enso && !song_.id.empty()) SoundManager::Get().PrepareSong(song_.SoundBank());

    dani_ = next_ == Next::Enso && !fade_ && pd.DecidedMode() == GameMode::Dani && PlayDataManager::Get().Dani().active;
    const char* movie = dani_ ? kDaniMovie : fade_ ? kFadeMovie : kMovie;
    if (!stage_.Load(movie)) {
        TraceLog(LOG_WARNING, "LoadingScene: %s を読み込めません", movie);
        return;
    }
    loaded_ = true;

    if (dani_) {
        if (Lumen::MovieClip* c = stage_.GetMovieClip("dani_rank")) c->GotoAndStop(DaniLabel(PlayDataManager::Get().Dani().level));
        // 「今回の挑戦は記録されません」（自動演奏のときだけ）
        if (Lumen::MovieClip* c = stage_.GetMovieClip("save_caution")) c->GotoAndStop(EnsoScene::autoPlay ? "on" : "off");
        stage_.Root()->GotoAndPlay("in");
        return;
    }

    auto text = [this](const char* clip, const char* field, const std::string& key) {
        if (Lumen::MovieClip* c = stage_.GetMovieClip(clip)) c->SetText(field, key);
    };
    // 曲名は演奏へ向かうときだけ（曲選択へ戻るときは出さない）
    if (next_ == Next::Enso) {
        // 元のデータでは曲名（深さ 8〜10）は幕が閉じきった瞬間（stop）に出て、開き始め（out）で消えるので、
        // 曲名の帯（深さ 4）が薄く出入りしているあいだ曲名がない。帯と同じ透明度で出し入れして、帯があるあいだは必ず出す
        for (int depth : {8, 9, 10}) stage_.Root()->LinkDepthAlpha(depth, 4);
        text("song_title_mc", "song_title_text", "song_" + song_.id);
        text("song_sub_title_mc", "song_sub_title_text", "song_sub_" + song_.id);
        // 曲名の下のアーティスト名は、曲名と同じ字形にする（小さい字は細い字形になるので、太い字形を指定する）
        if (Lumen::MovieClip* c = stage_.GetMovieClip("song_sub_title_mc")) {
            Lumen::MovieClip::TextStyle style;
            style.face = FontFace::Large;
            style.colors = false;
            c->SetTextStyle("song_sub_title_text", style);
        }
        text("song_ruby_mc", "song_ruby_text", "song_detail_" + song_.id);
    } else {
        for (const char* name : {"song_title_mc", "song_sub_title_mc", "song_ruby_mc"}) {
            if (Lumen::MovieClip* c = stage_.GetMovieClip(name)) c->SetVisible(false);
        }
    }
    // ヒント（深さ 11・12）は、前後の画面が少しでも見えているあいだは出さない。幕が閉じきってから、開き始めるまでだけ出す
    //   （Update で切り替える）
    if (!fade_) SetTipsVisible(false);
    text("tips_title_mc", "tips_title_text", "hint");
    text("tips_mc", "tips_text", TextFormat("tips%03d", GetRandomValue(1, kTipsCount)));
    // ヒントの本文は、白抜きではなく黒で塗りつぶした文字にする
    if (Lumen::MovieClip* c = stage_.GetMovieClip("tips_mc")) {
        Lumen::MovieClip::TextStyle style;
        style.fill = Color{0, 0, 0, 255};
        style.outlineRatio = 0.0f;
        c->SetTextStyle("tips_text", style);
    }

    // 手洗いの案内（最後の曲のとき）・演奏スキップ・左右の吹き出しは、ここでは出さない
    // 下の遊び方の絵（description）も出さず、そこにヒントの文言を見せる
    for (const char* name : {"washhands", "enso_skip_on", "description"}) {
        if (Lumen::MovieClip* c = stage_.GetMovieClip(name)) c->SetVisible(false);
    }

    stage_.Root()->GotoAndPlay("in");
}

void LoadingScene::SetTipsVisible(bool visible) {
    if (!loaded_) return;
    for (int depth : {11, 12}) stage_.Root()->FixDepthAlpha(depth, visible ? 1.0f : 0.0f);
}

void LoadingScene::Finalize() {
    if (previous_) previous_->Finalize();
    previous_.reset();
    if (nextScene_) nextScene_->Finalize();
    nextScene_.reset();
}

void LoadingScene::Update(float deltaTime) {
    time_ += deltaTime;
    if (!loaded_) {
        if (previous_) previous_->Finalize();
        previous_.reset();
        SceneManager::GetInstance().ChangeScene(MakeNext());
        return;
    }
    stage_.Update(fade_ ? deltaTime * (out_ ? kFadeOutSpeed : kFadeInSpeed) : deltaTime);

    Lumen::MovieClip* root = stage_.Root();
    if (dani_) {
        UpdateDani(root);
        return;
    }
    // in は stop のラベルで止める（止めないと out まで流れてしまう）
    const int stop = root->LabelFrame("stop");
    if (!out_ && stop >= 0 && root->CurrentFrame() >= stop) {
        root->GotoAndStop("stop");
        if (!closed_) {
            // 幕が閉じきったので、前の画面を片付けてから次の画面を準備する（重い処理は幕の裏で）
            closed_ = true;
            if (previous_) previous_->Finalize();
            previous_.reset();
            nextScene_ = MakeNext();
            nextScene_->Initialize();
        }
    }

    if (!fade_) SetTipsVisible(closed_ && !out_);

    // 曲選択は画面が出てくる演出（start_song_select）から始まるので、幕の裏で済ませておく。
    // 演奏ゲームは進めると曲の前の待ち時間が減ってしまうので、止めたままにする
    if (closed_ && !out_ && next_ == Next::SongSelect && nextScene_ && preRun_ < kPreRunSeconds) {
        nextScene_->Update(deltaTime);
        preRun_ += deltaTime;
    }

    const bool ready = next_ != Next::Enso || song_.id.empty() || SoundManager::Get().IsSongPrepared(song_.SoundBank());
    const float minShow = fade_ ? 0.0f : kMinShowSeconds;
    if (!out_ && closed_ && ready && time_ >= minShow) {
        root->GotoAndPlay("out");
        out_ = true;
    }
    // out が end まで来たら、準備しておいた画面に切り替える
    const int end = root->LabelFrame("end");
    if (out_ && nextScene_ && (root->CurrentFrame() >= end - 1 || !root->IsPlay())) {
        SceneManager::GetInstance().ChangeScene(std::move(nextScene_), false, true);
    }
}

// 段位道場の1曲目の前: 暗転しきったら（stop）次の画面を準備し、絵を out まで流す。曲の準備が済むまでは out の手前で待つ
void LoadingScene::UpdateDani(Lumen::MovieClip* root) {
    const int frame = root->CurrentFrame();
    if (!closed_ && frame >= root->LabelFrame("stop")) {
        closed_ = true;
        if (previous_) previous_->Finalize();
        previous_.reset();
        nextScene_ = MakeNext();
        nextScene_->Initialize();
    }
    const bool ready = song_.id.empty() || SoundManager::Get().IsSongPrepared(song_.SoundBank());
    if (!out_) {
        if (frame >= root->LabelFrame("out") - 1) {
            if (closed_ && ready) {
                root->GotoAndPlay("out");
                out_ = true;
            } else {
                root->Stop();
            }
        } else if (!root->IsPlay()) {
            root->Play();   // stop のラベルで止まっても、絵は out まで流す
        }
    }
    if (out_ && nextScene_ && (root->CurrentFrame() >= root->LabelFrame("end") - 1 || !root->IsPlay())) {
        SceneManager::GetInstance().ChangeScene(std::move(nextScene_), false, true);
    }
}

void LoadingScene::Draw() {
    ClearBackground(BLACK);
    // 幕の後ろ: 閉じるまでは前の画面、開くときは次の画面（どちらも止めたまま描く）
    if (!closed_ && previous_) previous_->Draw();
    if (out_ && nextScene_ && !dani_) nextScene_->Draw();
    if (loaded_) stage_.Draw();
}
