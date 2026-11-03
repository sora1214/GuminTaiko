#include "EnsoScene.hpp"

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <random>

#include "CommonParts.hpp"
#include "DaniResultScene.hpp"
#include "DaniSelectScene.hpp"
#include "GameFont.hpp"
#include "GameSettings.hpp"
#include "LoadingScene.hpp"
#include "PlayData.hpp"
#include "PlayRecord.hpp"
#include "SceneManager.hpp"
#include "SongSelectScene.hpp"
#include "AssetCache.hpp"
#include "HitAudio.hpp"
#include "SoundManager.hpp"
#include "TaikoInput.hpp"
#include "TestMenu.hpp"
#include "Tja.hpp"
#include "WordList.hpp"
#include "raymath.h"

using namespace GuminTaiko;

namespace {

constexpr const char* kDir = "lumen/000_default/enso_normal/enso/";

// ---- 画面の配置（1920x1080）----
constexpr float kLaneTop = 276.0f;         // レーンの帯（高さ 264）の上端。上は どんちゃんの背景
constexpr float kLaneHeight = 264.0f;
constexpr float kBottomTop = 540.0f;       // 背景と踊り子の帯（高さ 540）の上端
// 判定枠の中心（lane_hit の判定枠の輪を描いた画像から測った）。音符の中心がここに重なった時刻が判定の基準
constexpr float kJudgeX = 620.0f;
constexpr float kNoteY = 110.0f;           // レーンの帯の中での音符の高さ（判定枠の中心と同じ）
constexpr float kSpawnX = 1920.0f + 96.0f; // 音符が出てくる位置（1小節前）

constexpr Vector2 kFukidashiPos{250.0f, 20.0f};   // コンボの吹き出し（560x240）
constexpr Vector2 kRendaOffset{330.0f, -250.0f};  // 連打数（464x272）。レーンの帯の上端から

constexpr double kLeadIn = 1500.0;         // 曲を流し始めるまでの待ち（ms）
// 音声が混ぜられてからスピーカーで鳴るまでの遅れ（ms）。聞こえている位置に時刻を合わせる
constexpr double kOutputLatency = 30.0;
// 変換した曲の音は、譜面の時刻より 15〜25ms 遅れて始まる（9曲の音の立ち上がりと音符を照らし合わせて測った。
// 音声の圧縮形式の前置きのぶん）。譜面の時刻 = 曲の位置 − この値
constexpr double kSongDelay = 20.0;
constexpr int kJumpPool = 32;              // 同時に飛んでいける音符の数（連打は1秒に20打ほど × 飛ぶ 0.8 秒）
// 叩いた位置と判定枠の真ん中のずれを、飛び始めてからこの時間で無くして本来の道筋に合流させる
// （ゆっくり戻すと、飛びながら横にも流れて見える）
// フライングノーツの動きの最初の数コマは、音符が判定枠の真ん中にそのまま残る。叩いた音符が消えたのに、そこに音符が
// 残って見えるので、最初の kJumpSkipFrames コマは飛ばして、飛び始めから判定枠を離れた位置で出す
constexpr int kJumpSkipFrames = 1;
// song_info の movie（loop）で、ジャンルの板が見える時間と「N曲目」の板が見える時間
// ジャンル名の文字の上下位置（ジャンルの板は動かさない。小さくすると上へ、大きくすると下へ。単位はピクセル）
constexpr float kGenreNameOffsetY = -5.5f;
// 「N曲目」「N曲」の文字の上下位置（板は動かさない。使い方は上と同じ）
constexpr float kSongNumberOffsetY = -5.5f;
constexpr float kBadgeOffsetY = 0.0f;   // オートの札の上下位置（下の位置からのずれ）
constexpr float kBadgeLeft = 156.0f;     // オートの札の左端（難易度の絵の右）
constexpr float kBadgeCourseDy1P = -95.0f;   // 1P: ネームプレートの高さから、難易度の絵の高さまで
constexpr float kBadgeCourseDy2P = 80.0f;    // 2P: 同じく（下へ）
constexpr int kInfoGenreFrame = 10;
constexpr int kInfoNumberFrame = 160;
constexpr float kJumpMergeSeconds = 6.0f / 60.0f;
constexpr int kJudgeEffectFrames = 20;      // 良・可の文字と火花（hit_effect の hit_ryo など）の長さ
constexpr int kDancerSlots = 5;             // 踊り子の立ち位置（pos0〜4。中央から順）
constexpr int kStartDancers = 3;            // 演奏の始めから踊っている人数

// 立ち位置ごとの踊り子（色違いの Dancer1〜N のどれを出すか。N は踊り子のムービーごとに 2〜5）。
// 立ち位置は pos0 が中央、pos1・pos2 がその左右、pos3・pos4 が外側なので、左右で同じ色になるように割り当てる
int DancerVariant(int slot, int variants) { return (slot + 1) / 2 % std::max(1, variants) + 1; }
std::string DancerName(int slot, int variants) { return "Dancer" + std::to_string(DancerVariant(slot, variants)); }

constexpr int kAddScoreCount = 4;        // 同時に出せる加点の表示（lua: Tutorial.addScoreMax）
// 加点の表示からスコアが増えるまで。lua（遊び方説明）は 32 フレームだが、叩いてすぐ増えるように 0 にする
constexpr float kAddScoreDelay = 0.0f;
constexpr float kResultSeconds = 4.0f;     // 最後の音符のあと「フルコンボ」などを見せてからリザルトへ
constexpr float kGekiJumpSeconds = 65.0f / 60.0f;   // 風船（geki。虹がかかって消えるまで 65 フレーム）

// ---- 演奏オプション ----
// 音符位置調整の1段階（ms）。本家の値はわからないので 10ms にしている（右: 音符を後ろ（右）に描く）
constexpr double kNotePositionStepMs = 10.0;
// ランダムで色を入れ替える割合（きまぐれ・でたらめ）
constexpr double kKimagureRate = 0.25;
constexpr double kDetarameRate = 0.5;
constexpr int kSkipHits = 10;              // 演奏スキップ: フチを左右交互に叩く回数
constexpr float kSkipResetSeconds = 2.0f;  // 演奏スキップ: この間叩かなければ数え直す

// ---- サウンド ----
constexpr float kDonVolume = 0.6f;         // ドン（面）を叩いた音の大きさ（元の 60%、約 -4.4dB）
constexpr const char* kBankEnso = "se_enso_v12a";
constexpr const char* kBankVoice = "voice_enso_v12a";
constexpr const char* kBankTraining = "se_training";   // 特訓モード（fast / return: 早送り・早戻し、count: カウント、option: 設定、fumen: 止める）
constexpr int kTrainingMoveSlot = 6;                   // 早送り・早戻しの音を鳴らすスロット

// ---- 段位道場 ----
constexpr const char* kDaniDir = "lumen/000_default/enso_dani/enso/";
constexpr const char* kBankDaniPlay = "se_daniplay_v12e";   // fusuma_close / fusuma_open / disqualify / clear_normal / clear_upper / notclear
// お題の板（中心が原点の 1560 幅の板を3段、160 間隔）。下の帯の左に寄せ、右の段位の札（x 1560〜）にかからない位置
constexpr Vector2 kDaniDetailPos{750.0f, 655.0f};
// 段位道場の曲の前: 襖が開いて曲名が出たら（襖の演出の kDaniTitleFrame）曲名を出したまま待ち、
// 曲の前の待ち（kLeadIn）の kDaniAfterTitle 前に曲名を消し始める。襖が開くのは始まって約 1.35 秒、曲名が出きるのは約 3 秒（ms）
constexpr double kDaniLeadIn = 6700.0;
constexpr double kDaniAfterTitle = 1200.0;   // 曲名が消えきるまで（kDaniTitleFrame から end まで 69 フレーム）
constexpr int kDaniTitleFrame = 300;
const char* const kDaniSongLabels[] = {"1st", "2nd", "3rd"};

const char* SpriteLabel(NoteType type) {
    switch (type) {
    case NoteType::Don: return "don";
    case NoteType::Do: return "do";
    case NoteType::Ko: return "ko";
    case NoteType::Katsu: return "katsu";
    case NoteType::Ka: return "ka";
    case NoteType::BigDon: return "daidon";
    case NoteType::BigKatsu: return "daikatsu";
    case NoteType::Roll: return "renda";
    case NoteType::BigRoll: return "dairenda";
    case NoteType::Balloon: return "fusen";
    case NoteType::Kusudama: return "kusudama";
    case NoteType::HandDon: return "wdon1p";
    case NoteType::HandKatsu: return "wkatsu1p";
    default: return "none";
    }
}

Lumen::Matrix Translate(float x, float y, float sx = 1.0f, float sy = 1.0f) {
    Lumen::Matrix m;
    m.a = sx;
    m.d = sy;
    m.x = x;
    m.y = y;
    return m;
}

Lumen::MovieClip* Sub(Lumen::MovieClip* root, const std::string& path) {
    return root ? root->Find(path) : nullptr;
}

void Goto(Lumen::MovieClip* clip, const std::string& label, bool play = false) {
    if (!clip) return;
    if (play) clip->GotoAndPlay(label);
    else clip->GotoAndStop(label);
}

std::string Side(const std::vector<int>& joined, int player) {
    if (joined.size() <= 1) return "_c";
    return player == 0 ? "_l" : "_r";
}

void SetFusenDigits(Lumen::MovieClip* fukidashi, int remaining) {
    if (!fukidashi) return;
    const std::string s = std::to_string(std::clamp(remaining, 0, 999));
    const int len = int(s.size());
    for (const char* name : {"digit1_1", "digit10_1", "digit10_2", "digit100_1", "digit100_2", "digit100_3"}) {
        if (Lumen::MovieClip* c = fukidashi->Child(name)) c->SetVisible(false);
    }
    if (len == 1) {
        if (Lumen::MovieClip* c = fukidashi->Child("digit1_1")) {
            c->SetVisible(true);
            c->GotoAndStop("number_" + std::string(1, s[0]));
        }
    } else if (len == 2) {
        if (Lumen::MovieClip* c = fukidashi->Child("digit10_2")) {
            c->SetVisible(true);
            c->GotoAndStop("number_" + std::string(1, s[0]));
        }
        if (Lumen::MovieClip* c = fukidashi->Child("digit10_1")) {
            c->SetVisible(true);
            c->GotoAndStop("number_" + std::string(1, s[1]));
        }
    } else if (len >= 3) {
        if (Lumen::MovieClip* c = fukidashi->Child("digit100_3")) {
            c->SetVisible(true);
            c->GotoAndStop("number_" + std::string(1, s[0]));
        }
        if (Lumen::MovieClip* c = fukidashi->Child("digit100_2")) {
            c->SetVisible(true);
            c->GotoAndStop("number_" + std::string(1, s[1]));
        }
        if (Lumen::MovieClip* c = fukidashi->Child("digit100_1")) {
            c->SetVisible(true);
            c->GotoAndStop("number_" + std::string(1, s[2]));
        }
    }
}

} // namespace

// ===========================================================================
// 部品
// ===========================================================================
bool EnsoScene::Part::Load(const std::string& path, Vector2 position) {
    stage = std::make_unique<Lumen::Stage>();
    pos = position;
    if (!stage->Load(path)) {
        TraceLog(LOG_WARNING, "EnsoScene: %s を読み込めません", path.c_str());
        stage.reset();
        return false;
    }
    return true;
}

Lumen::MovieClip* EnsoScene::Part::Clip(const std::string& path) const {
    return stage ? stage->GetMovieClip(path) : nullptr;
}

void EnsoScene::Part::Update(float dt) const {
    if (stage) stage->Update(dt);
}

void EnsoScene::Part::Draw() const {
    if (stage && stage->Root() && stage->Root()->IsVisible()) stage->Draw(pos.x, pos.y);
}

// ===========================================================================
// 準備
// ===========================================================================
void EnsoScene::Initialize() {
    PlayDataManager& pd = PlayDataManager::Get();
    const SongInfo* song = SongDatabase::Get().FindSong(pd.SelectedSong());
    if (!song) {
        TraceLog(LOG_WARNING, "EnsoScene: 曲が選ばれていません");
        return;
    }
    song_ = *song;

    // 段位道場（1人だけで遊ぶ）
    if (pd.DecidedMode() == GameMode::Dani && pd.Dani().active) {
        daniCourse_ = DaniDatabase::Get().Course(pd.Dani().level);
        dani_ = daniCourse_ != nullptr;
    }

    std::vector<int> joined;
    for (int p = 0; p < 2; ++p) {
        if (pd.Player(p).userType != UserType::None) joined.push_back(p);
    }
    if (joined.empty()) joined.push_back(0);
    if (dani_) joined.resize(1);

    for (size_t i = 0; i < joined.size(); ++i) {
        players_.emplace_back();
        if (!SetupPlayer(players_.back(), joined[i], int(joined.size()))) players_.pop_back();
    }
    if (players_.empty()) return;

    // ---- 画面全体の部品 ----
    // ---- 画面全体の部品 ----
    const bool solo = players_.size() == 1;
    if (solo && !dani_) {
        // バラエティ（6）は、もとは同じジャンルだったゲームミュージックと同じ背景・踊り子にする。
        // クラシック（7）はニジイロにないジャンルなので、ナムコオリジナルと同じにする。創作譜面（8）はポップスと同じ
        static const char* const kBgNormals[] = {"bg_nomal_a_02", "bg_nomal_a_03", "bg_nomal_a_04", "bg_nomal_a_05",
                                                 "bg_nomal_a_03", "bg_nomal_a_01", "bg_nomal_a_03", "bg_nomal_a_01", "bg_nomal_a_02"};
        static const char* const kDancers[] = {"dancer_inu", "dancer_kame", "dancer_tetsuo", "dancer_omen", "dancer_unagi", "dancer_donko",
                                               "dancer_unagi", "dancer_donko", "dancer_inu"};
        const int genre = std::clamp(song_.genreNo, 0, kGenreCount - 1);
        bgBottom_.Load(std::string(kDir) + "background/" + kBgNormals[genre], {0.0f, kBottomTop});
        // 魂ゲージが満タンのときの背景（ふだんは隠す）
        bgFever_.Load(std::string(kDir) + "background/bg_fever_a_01", {0.0f, kBottomTop});
        Goto(bgFever_.Root(), "init");
        if (Lumen::MovieClip* root = bgFever_.Root()) root->SetVisible(false);
        bgFeverCycle_ = Cycle{bgFever_.Root(), "", "normal_fever", "fever", "fever_normal", -1, true};
        bgDai_.Load(std::string(kDir) + "background/bg_dai_a_01", {0.0f, kBottomTop});
        // 踊り子。立ち位置（pos0 が中央）ごとに色違いの4人（Dancer1〜4）が重ねて置かれているので、1人だけ出す。
        // 最初から中央の3人が踊っていて、魂ゲージが増えると外側の2人が入ってくる
        dancer_.Load(std::string(kDir) + "dancer/" + kDancers[genre], {0.0f, kBottomTop});
        dancerVariants_ = 0;
        if (Lumen::MovieClip* pos = dancer_.Clip("pos0")) {
            while (pos->Child("Dancer" + std::to_string(dancerVariants_ + 1))) ++dancerVariants_;
        }
        for (int i = 0; i < kDancerSlots; ++i) {
            Lumen::MovieClip* pos = dancer_.Clip("pos" + std::to_string(i));
            if (!pos) continue;
            pos->SetVisible(false);
            for (int d = 1; d <= dancerVariants_; ++d) {
                if (Lumen::MovieClip* dancer = pos->Child("Dancer" + std::to_string(d))) dancer->SetVisible(d == DancerVariant(i, dancerVariants_));
            }
        }
        SetDancers(kStartDancers);
        for (int i = 0; i < kStartDancers; ++i) {
            Goto(dancer_.Clip("pos" + std::to_string(i) + "/" + DancerName(i, dancerVariants_)), "dance", true);
        }
        feverEffect_.Load(std::string(kDir) + "fever/fever_effect1", {0.0f, kBottomTop});
        Goto(feverEffect_.Root(), "wait");
        if (Lumen::MovieClip* root = feverEffect_.Root()) root->SetVisible(false);
        feverEffectCycle_ = Cycle{feverEffect_.Root(), "", "normal_fever", "fever", "fever_normal", -1, true};
    }
    // どんちゃんの背景は「ふつう」から始める（ラベルを決めないと、ふつう → フィーバー → ミス を順に流してしまう）
    if (dani_) {
        // 段位道場の上の背景は道場（切り替えはない）
        donBg_.Load(std::string(kDaniDir) + "donbg/donbg_dojo_1p", {0.0f, 0.0f});
        Goto(donBg_.Root(), "normal", true);
    } else {
        donBg_.Load(std::string(kDir) + "donbg/donbg_a_01_1p", {0.0f, 0.0f});
        Goto(donBg_.Root(), "normal", true);
        donBgCycle_ = Cycle{donBg_.Root(), "normal", "normal_fever", "fever", "fever_normal", 0, false};
        if (Lumen::MovieClip* root = donBg_.Root()) donBgCycle_.outEnd = root->LabelFrame("fever_miss");
        // 神輿の行列は魂ゲージが満タンのときだけ
        donBgObj_.Load(std::string(kDir) + "donbg/donbg_obj_a_01", {0.0f, 0.0f});
        if (Lumen::MovieClip* root = donBgObj_.Root()) root->SetVisible(false);
    }
    donEnso_.Load(std::string(kDir) + "don/don_enso", {0.0f, 0.0f});
    // コンボの吹き出し（どんちゃんの横）
    fukidashi_.Load(std::string(kDir) + "information/don_fukidashi", kFukidashiPos);
    Goto(fukidashi_.Root(), "solo");
    Goto(fukidashi_.Clip("main_1p"), "wait");
    if (Lumen::MovieClip* c = fukidashi_.Clip("main_2p")) c->SetVisible(false);
    Goto(donEnso_.Root(), "player1", true);
    // 光とキラキラは魂ゲージが満タンのときなどの演出なので、ふだんは隠す
    for (const char* name : {"light", "kirakira", "don2p"}) {
        if (Lumen::MovieClip* clip = donEnso_.Clip(name)) clip->SetVisible(false);
    }
    gogoEffect_.Load(std::string(kDir) + "information/gogo_effect", {0.0f, 0.0f});
    Goto(gogoEffect_.Root(), "wait");
    result_.Load(std::string(kDir) + "information/action_result", {0.0f, kLaneTop});
    for (const char* name : {"dondafull_dani_mc", "fullcombo_dani_mc", "fail_dani_mc", "success_dani_mc", "dondafullMc",
                             "fullcomboMc", "failMc", "successMc"}) {
        if (Lumen::MovieClip* clip = result_.Clip(name)) clip->SetVisible(false);
    }

    // 風船・くす玉・連打・分岐・ポーズ・リザルト演出
    fusenPart_.Load(std::string(kDir) + "onpu/action_fusen", {0.0f, 0.0f});
    if (Lumen::MovieClip* root = fusenPart_.Root()) {
        root->SetVisible(false);
        Goto(root, "init");
    }
    kusudamaPart_.Load(std::string(kDir) + "onpu/action_kusudama", {0.0f, 0.0f});
    if (Lumen::MovieClip* root = kusudamaPart_.Root()) {
        root->SetVisible(false);
        Goto(root, "init");
    }
    rendaEffect_.Load(std::string(kDir) + "renda_effect/renda_effect_hamaya", {0.0f, 0.0f});
    if (Lumen::MovieClip* root = rendaEffect_.Root()) root->SetVisible(false);

    branchEffect_.Load(std::string(kDir) + "information/branch_effect", {264.0f, 180.0f});
    if (Lumen::MovieClip* root = branchEffect_.Root()) {
        root->SetVisible(false);
        Goto(root, "wait");
    }

    // 演奏スキップの数（フチを叩くと出る）
    skipPart_.Load(std::string(kDir) + "information/skip", {0.0f, 0.0f});
    Goto(skipPart_.Clip("skip_end"), "wait");

    pauseMenu_.Load("lumen/enso/pause/pause_menu", {0.0f, 0.0f});
    if (Lumen::MovieClip* root = pauseMenu_.Root()) {
        root->SetVisible(false);
        Goto(root, "init");
    }

    // 曲名とジャンル（右上）
    songInfo_.Load(std::string(kDir) + "information/song_info", {0.0f, 0.0f});
    if (Lumen::MovieClip* root = songInfo_.Root()) {
        Goto(root, "loop", true);
        if (Lumen::MovieClip* plate = songInfo_.Clip("genre")) {
            Goto(plate, SongDatabase::GenrePlateLabel(song_.genreNo));
            const std::array<float, 3> tint = SongDatabase::GenrePlateTint(song_.genreNo);
            plate->SetTint({tint[0], tint[1], tint[2], 1.0f});
        }
        if (Lumen::MovieClip* c = songInfo_.Clip("genre_name_mc")) {
            c->SetText("genre_name", SongDatabase::GenreTextKey(song_.genreNo));
            c->SetTextOffsetY(kGenreNameOffsetY);
        }
        if (Lumen::MovieClip* c = songInfo_.Clip("text_song_title_mc")) c->SetText("song_name", "song_" + song_.id);
        // 曲名は右寄せと中央寄せの2つが重ねて置かれているので、右寄せだけを出す
        if (Lumen::MovieClip* c = songInfo_.Clip("text_song_title_center_mc")) c->SetVisible(false);
        // ジャンルの板と「N曲目 / N曲」は、movie の loop には任せず止めておき、UpdateDaniSongInfo で
        // 同じ場所に交互にフェードして出す（演奏ゲームも段位道場も）
        if (Lumen::MovieClip* c = songInfo_.Clip("song_number")) {
            c->SetTint({1.0f, 1.0f, 1.0f, 0.0f});
            c->SetTextOffsetY(kSongNumberOffsetY);
            c->SetVisible(false);
        }
        root->GotoAndStop("loop");
    }
    // 段位道場は挑戦のあいだ（3曲）つづけて数える。オートにした曲が1曲でもあれば、記録は残さない
    if (!dani_ || pd.Dani().songIndex == 0) autoUsed = false;
    if (autoPlay) autoUsed = true;
    if (!dani_) {
        const PlayDataManager& playData = PlayDataManager::Get();
        SetSongNumber(playData.PlaySongCount(), playData.StageCount());
        daniInfoTint_ = SongDatabase::GenrePlateTint(song_.genreNo);
        daniInfoRun_ = true;
        daniInfoGenreAlpha_ = 0.0f;
    }
    if (dani_) {
        // 曲名・ジャンル・「N曲目」は、襖が開いてから、その曲のものに切り替える（それまでは前の曲のまま。1曲目は何も出さない）
        const int songIndex = pd.Dani().songIndex;
        if (songIndex > 0) {
            ShowDaniSongInfo(songIndex - 1, false);
        } else {
            for (const char* name : {"text_song_title_mc", "genre", "genre_name_mc", "song_number"}) {
                if (Lumen::MovieClip* c = songInfo_.Clip(name)) c->SetVisible(false);
            }
        }
    }

    // 演奏中に流すどんちゃんの動きを先に読み込んでおく（初めて流すときにファイルを読むと、そのフレームが数十 ms 止まる）
    for (const char* name : {"normal", "sabi", "full_gage", "balloon_loop", "balloon_nobeat", "balloon_success", "balloon_failure",
                             "miss", "full_combo"}) {
        DonAnimator::Preload(name);
    }
    for (const char* name : {"kusu_in", "kusu_loop", "kusu_nobeat", "kusu_success02", "kusu_failure"}) {
        DonAnimator::Preload(std::string(name) + "_p1");
        DonAnimator::Preload(std::string(name) + "_p2");
    }

    SetupNoteSprites();

    // どんちゃん（don_enso の差し込み枠）
    // 左上のどんちゃんは先頭のプレイヤーがエントリーで選んだきせかえ
    {
        const PlayerData& data = PlayDataManager::Get().Player(players_.front().index);
        don3d_.SetCostume(0, DonModel::FromEntry(data.costume, data.kigurumi, data.dress));
    }
    don3d_.Load();
    // 差し込み枠は画面全体（1920x1080）で、左上に拡大して置かれている
    donTexture_ = LoadRenderTexture(1920, 1080);
    SetTextureFilter(donTexture_.texture, TEXTURE_FILTER_BILINEAR);
    Lumen::SetExternalTexture("don1p", &donTexture_.texture, true);

    // 曲の変換を始めておく（済んだら流し始める）
    for (const char* bank : {kBankEnso, kBankVoice}) SoundManager::Get().Preload(bank);
    // 叩いた音（プレイヤーごとの音色）は最初の1回で読み込むと遅れるので、先に読み込んでおく
    for (const Player& player : players_) {
        SoundManager::Get().Preload(player.hitBank);
        for (const char* tone : {"don_c", "don_l", "don_r", "katsu_c", "katsu_l", "katsu_r"}) {
            SoundManager::Get().PreloadTone(player.hitBank, tone);
        }
    }
    // 叩いた瞬間に音を鳴らす監視（HitAudio）に、面とふちごとの音と割り当てたキーを登録する
    HitAudio::ClearPadSounds();
    {
        const std::vector<int> side = players_.size() >= 2 ? std::vector<int>{0, 1} : std::vector<int>{0};
        for (const Player& player : players_) {
            for (int pad = 0; pad < 4; ++pad) {
                const bool don = pad == int(TaikoInput::Pad::LeftDon) || pad == int(TaikoInput::Pad::RightDon);
                const int id = SoundManager::Get().LowLatencyId(player.hitBank, std::string(don ? "don" : "katsu") + Side(side, player.index));
                int keys[TaikoInput::kKeySlots];
                int count = 0;
                for (int slot = 0; slot < TaikoInput::kKeySlots; ++slot) {
                    const int vk = TaikoInput::WindowsKey(TaikoInput::BoundKey(TaikoInput::PadAction(player.index, TaikoInput::Pad(pad)), slot));
                    if (vk > 0) keys[count++] = vk;
                }
                HitAudio::SetPadSound(player.index, pad, id, SoundManager::Get().SeGain() * (don ? kDonVolume : 1.0f), keys, count);
            }
        }
    }
    // 演奏中に初めて鳴らす音も、読み込みで1フレーム止まらないよう（ロード画面の幕の裏で）先に読んでおく
    {
        SoundManager& sound = SoundManager::Get();
        size_t hits = 0;
        for (const Player& player : players_) {
            size_t count = 0;
            for (const Note& note : player.notes) count += note.src.IsHit() ? 1 : 0;
            hits = std::max(hits, count);
        }
        for (int c : {10, 30, 50}) {
            if (size_t(c) <= hits) sound.PreloadTone(kBankVoice, TextFormat("combo_%04d_c", c));
        }
        for (int c = 100; c <= 5000 && size_t(c) <= hits; c += 100) sound.PreloadTone(kBankVoice, TextFormat("combo_%04d_c", c));
        for (const char* tone : {"fullcombo_c", "dondafullcombo_c"}) sound.PreloadTone(kBankVoice, tone);
        for (const char* tone : {"clear_c", "notclear_c", "fullcombo_c", "dondafullcombo_c", "balloon_success_c", "kusudama_success"}) {
            sound.PreloadTone(kBankEnso, tone);
        }
    }
    SoundManager::Get().PrepareSong(song_.SoundBank());
    clock_ = -kLeadIn;
    if (dani_) SetupDani();
    loaded_ = true;

    // 特訓モードの小節（譜面の小節。小節線を消した小節も1つと数える）
    for (const FumenMeasure& m : players_.front().fumen.measures) {
        trainingMeasures_.push_back(m.time);
        trainingMeasureBpm_.push_back(m.bpm);
        trainingMeasureScroll_.push_back(m.scroll[0]);
    }
    // F2 の暗転のあと: 特訓モードで、選んでいた小節に止めて始める
    if (startTraining) {
        startTraining = false;
        SoundManager::Get().Preload(kBankTraining);
        for (const char* tone : {"count", "option", "fumen"}) SoundManager::Get().PreloadTone(kBankTraining, tone);
        training_ = true;
        trainingPaused_ = true;
        trainingMeasure_ = trainingMeasures_.empty() ? 0 : std::clamp(startTrainingMeasure, 0, int(trainingMeasures_.size()) - 1);
        clock_ = trainingMeasures_.empty() ? 0.0 : trainingMeasures_[size_t(trainingMeasure_)];
    }
}

bool EnsoScene::SetupPlayer(Player& player, int index, int players) {
    PlayDataManager& pd = PlayDataManager::Get();
    player.active = true;
    player.index = index;
    player.course = std::clamp(pd.SelectedCourse(index), 0, 4);
    std::string error;
    const bool ok = song_.IsTja() ? LoadTja(song_.tjaPath, player.course, player.fumen, &error)
                                  : LoadFumen(FumenPath(song_.id, player.course), player.fumen, &error);
    if (!ok) {
        TraceLog(LOG_WARNING, "EnsoScene: %s", error.c_str());
        return false;
    }
    SetJudgeWindows(player.course, player.fumen);   // 判定の幅は難易度で決める（譜面ファイルの値は使わない）
    // テストモードの GUMIN SETTINGS → JUDGE STRICTNESS で、良・可・不可の幅をまとめて広げる・狭める
    {
        static const float kScales[] = {1.5f, 1.25f, 1.0f, 0.8f, 0.6f};
        const int level = std::clamp(GameSettings::Get().Value(TestMenu::kJudgeStrictnessItem), 0, 4);
        for (float& window : player.fumen.windows) window *= kScales[level];
    }
    player.shinuti = std::max(10, player.fumen.shinuti > 0 ? player.fumen.shinuti : song_.shinuti[size_t(player.course)]);
    player.laneY = kLaneTop + (players >= 2 && index == 1 ? kLaneHeight : 0.0f);

    // 音符・小節線・ゴーゴーを並べる（分岐は普通譜面）
    for (const FumenMeasure& m : player.fumen.measures) {
        if (m.barline) {
            player.bars.push_back(m.time);
            player.barBpm.push_back(m.bpm);
            player.barScroll.push_back(m.scroll[0]);
        }
        if (player.gogo.empty() ? m.gogo : m.gogo != player.gogo.back().second) player.gogo.emplace_back(m.time, m.gogo);
        for (const FumenNote& n : m.notes[0]) {
            Note note;
            note.src = n;
            player.notes.push_back(note);
            lastTime_ = std::max(lastTime_, n.time + n.duration);
        }
    }
    std::stable_sort(player.notes.begin(), player.notes.end(), [](const Note& a, const Note& b) { return a.src.time < b.src.time; });

    // ---- 演奏オプション ----
    player.options = pd.Player(index).options;
    if (players >= 2) player.options.ensoSkip = false;   // 演奏スキップは1人のときだけ
    player.hitBank = TextFormat("se_neiro_%02d_v12a", std::clamp(player.options.neiro, 0, PlayOptions::kNeiroCount - 1));
    player.drawOffset = player.options.notePosition * kNotePositionStepMs;
    ApplyNoteOptions(player);

    // ---- レーンまわりの部品 ----
    const std::string layout = players >= 2 ? (index == 0 ? "duet1p" : "duet2p") : "solo";
    const Vector2 band{0.0f, player.laneY};
    player.lane.Load(std::string(kDir) + "lane/lane", band);
    Goto(player.lane.Root(), layout);
    player.laneHit.Load(std::string(kDir) + "lane/lane_hit", band);
    Goto(player.laneHit.Clip("branch"), "no_bunki");
    Goto(player.laneHit.Clip("gogo"), "normal");
    Goto(player.laneHit.Clip("hit_effect"), "no_onp");
    player.laneLeft.Load(std::string(kDir) + "lane/lane_left", band);
    Goto(player.laneLeft.Root(), dani_ ? "dani" : layout);   // 段位道場は青い板
    player.taiko.Load(std::string(kDir) + "information/taiko", band);
    player.hitEffect.Load(std::string(kDir) + "lane/hit_effect", band);
    Goto(player.hitEffect.Clip("origin/base"), "ryo");
    if (Lumen::MovieClip* root = player.hitEffect.Root()) root->SetVisible(false);

    player.course2.Load(std::string(kDir) + "information/course", band);
    static const char* const kCourseLabels[] = {"easy", "normal", "hard", "mania", "ura"};
    // 難易度のアイコン（おに など）はレーン左のパネル、スコアの下に出す（none は隠れるラベル）
    Goto(player.course2.Root(), "init");
    // 段位道場は難易度の代わりに「段位道場」のアイコン
    Goto(player.course2.Clip("course"), dani_ ? "dani" : kCourseLabels[player.course]);
    if (Lumen::MovieClip* text = player.course2.Clip("course/text_mc")) {
        static const char* const kCourseKeys[] = {"course_easy", "course_normal", "course_hard", "course_mania", "course_ura"};
        text->SetText("course_text", dani_ ? "段位道場" : kCourseKeys[player.course]);
    }

    // スコアと魂ゲージは 2P の位置もラベル（duet_player2 / hard_2p など）に入っているので、1P の帯に置く
    player.scorePart.Load(std::string(kDir) + "information/score", {0.0f, kLaneTop});
    Goto(player.scorePart.Root(), players >= 2 ? (index == 0 ? "duet_player1" : "duet_player2") : "solo");
    // スコアのキラキラ・ハイスコアの演出と、数字の光は使わない（lua: tutorial "Loading"）
    for (const char* name : {"score/kirakira", "score/high_score_bg", "high_score_anim"}) {
        if (Lumen::MovieClip* c = player.scorePart.Clip(name)) c->SetVisible(false);
    }
    for (int d = 1; d <= 7; ++d) {
        if (Lumen::MovieClip* light = player.scorePart.Clip("score/digit" + std::to_string(d) + "/light")) light->SetVisible(false);
    }
    // 加点の表示は4つを順に使い回す。2〜4つ目は score をもう3つ読み込み、加点の表示だけを使う
    const std::string scoreLabel = players >= 2 ? (index == 0 ? "duet_player1" : "duet_player2") : "solo";
    for (int i = 0; i < kAddScoreCount; ++i) {
        Part add;
        if (i == 0) {
            player.addScores.push_back(std::move(add));   // 1つ目は scorePart の中のもの
            continue;
        }
        add.Load(std::string(kDir) + "information/score", {0.0f, kLaneTop});
        Goto(add.Root(), scoreLabel);
        for (const char* name : {"score", "base", "high_score_anim", "scorerank_1p", "scorerank_2p"}) {
            if (Lumen::MovieClip* c = add.Clip(name)) c->SetVisible(false);
        }
        player.addScores.push_back(std::move(add));
    }
    for (int i = 0; i < kAddScoreCount; ++i) {
        const Part& add = i == 0 ? player.scorePart : player.addScores[size_t(i)];
        for (const char* name : {"add_score_l_mc", "add_score_r_1p_mc", "add_score_r_2p_mc"}) {
            if (Lumen::MovieClip* c = add.Clip(name)) c->SetVisible(false);
        }
    }
    player.comboPart.Load(std::string(kDir) + "information/combo_number", band);
    Goto(player.comboPart.Clip("combo_num"), "init");
    // 「コンボ」の文字: 字形は選曲のジャンルの看板と同じ（色と縁取りは元のまま）。コンボの数字が出るまで出さない
    if (Lumen::MovieClip* text = player.comboPart.Clip("text")) {
        Lumen::MovieClip::TextStyle style;
        style.colors = false;
        style.face = FontFace::Large;
        text->SetTextStyle("text_combo", style);
        text->SetVisible(false);
    }
    player.renda.Load(std::string(kDir) + "information/renda_number",
                      {kRendaOffset.x, player.laneY + kRendaOffset.y});
    Goto(player.renda.Root(), players >= 2 ? "duet" : "solo");
    for (const char* name : {"main_ai_mc", "main_duet_mc", "main_solo_mc"}) Goto(player.renda.Clip(name), "init");

    // 叩いた音符が飛んでいく演出
    for (int i = 0; i < kJumpPool; ++i) {
        Player::Jump jump;
        jump.part.Load(std::string(kDir) + "onpu/onp_jump", band);
        if (Lumen::MovieClip* root = jump.part.Root()) {
            root->GotoAndStop(0);
            root->SetVisible(false);
        }
        player.jumps.push_back(std::move(jump));
    }

    if (dani_) {
        // 段位用の魂ゲージ（合格ラインの印と「魂ゲージ 〇%以上」の札つき）。中身は UpdateDani が決める
        const int red = std::clamp(daniCourse_->gaugeRed, 0, 100);
        player.gauge.Load(std::string(kDaniDir) + "tamashiigauge/tamashii_gauge", {0.0f, 0.0f});
        player.gauge.stage->SetTextFace(FontFace::Large);
        Goto(player.gauge.Root(), "dani_enso");
        Goto(player.gauge.Clip("gauge_mc"), "border_" + std::to_string(red / 2));
        Goto(player.gauge.Clip("gauge_mc/gauge_border"), "dani_enso");
        if (Lumen::MovieClip* border = player.gauge.Clip("gauge_mc/gauge_border")) border->SetText("tx_border", std::to_string(red) + "%以上");
        Goto(player.gauge.Clip("gauge_mc/tamashii_mc"), "not_clear");
        Goto(player.gauge.Clip("gauge_mc/gauge_lamp_mc"), "gage_0");
        // コンボとスコアは前の曲から続く
        const DaniRun& run = pd.Dani();
        player.combo = run.combo;
        player.maxCombo = run.combo;
        player.score = run.score;
        player.displayScore = run.score;
    } else {
        player.gauge.Load(std::string(kDir) + "tamashiigage/tamashii_gage", {0.0f, 0.0f});
        static const char* const kGaugeLabels[] = {"easy", "normal", "hard", "hard", "hard"};
        Goto(player.gauge.Root(), std::string(kGaugeLabels[player.course]) + (index == 0 ? "_1p" : "_2p"));
    }

    // ネームプレートは 1P ではパネルの下のふちにかかる位置、2P（スコアが下に来る）では上
    //   （本家の演奏画面: 1P の丸の中心が画面の (68, 494) あたり）
    //   位置を動かすときは、下の値を変える（x: 大きいほど右 / y: 大きいほど下。単位はピクセル）
    constexpr float kPlateX = 160.0f;
    constexpr float kPlateY1P = 217.0f;   // 1P（レーンの上端からの y）
    constexpr float kPlateY2P = 40.0f;    // 2P（2人で遊ぶとき）
    const bool lower = players >= 2 && index == 1;
    player.plate.Load("lumen/000_default/common/name_plate", {kPlateX, player.laneY + (lower ? kPlateY2P : kPlateY1P)});
    CommonParts::SetNamePlate(player.plate.Root(), index);
    return true;
}

// オートプレイ中のしるし。選曲画面で演奏オプションのアイコンが並ぶところ（ネームプレートの下、左端から）に、同じ大きさで出す
void EnsoScene::DrawAutoBadge(const Player& player) const {
    const bool lower = players_.size() >= 2 && player.index == 1;
    // 本家の演奏画面の演奏オプションは、難易度の丸い絵（おになど）のすぐ右、同じ高さに並ぶ。
    // 難易度の絵はネームプレートの上（2P はスコアが下に来るので下）にある
    const float centerY = player.laneY + (lower ? 40.0f + kBadgeCourseDy2P : 217.0f + kBadgeCourseDy1P) + kBadgeOffsetY;
    CommonParts::DrawAutoBadge(kBadgeLeft, centerY, 1.0f);
}

// 音符の絵の外ぶち（黒）と縁の白を、本家（AC）の見た目に近づける。AC では外ぶち・目・口が真っ黒ではなく少し浮いた暗い色（約 24,28,26）で、
// 縁の白もやや青みがかっている。絵（onp_all の画像）を、最初に1回だけ書き換える
static void MatchNoteLook(const std::string& moviePath) {
    static bool done = false;
    if (done) return;
    done = true;
    constexpr unsigned char kBlackR = 24, kBlackG = 28, kBlackB = 26;   // 黒の下限（AC の外ぶちの色）
    constexpr int kRimBlueBoost = 9;                                    // 縁の白の青み（AC: 245,239,234 / ここ: 247,239,223）
    for (const Texture2D& texture : AssetCache::Get().Nutexb("Data/x64/" + moviePath + ".nutexb")) {
        if (texture.id == 0) continue;
        Image image = LoadImageFromTexture(texture);
        if (!image.data || image.format != PIXELFORMAT_UNCOMPRESSED_R8G8B8A8) {
            UnloadImage(image);
            continue;
        }
        unsigned char* pixels = static_cast<unsigned char*>(image.data);
        const size_t count = size_t(image.width) * size_t(image.height);
        for (size_t i = 0; i < count; ++i) {
            unsigned char* p = pixels + i * 4;
            if (p[3] == 0) continue;
            if (p[0] >= 240 && p[1] >= 232 && p[2] >= 210 && p[2] <= 235) {
                p[2] = (unsigned char)std::min(255, p[2] + kRimBlueBoost);
            } else {
                p[0] = std::max(p[0], kBlackR);
                p[1] = std::max(p[1], kBlackG);
                p[2] = std::max(p[2], kBlackB);
            }
        }
        UpdateTexture(texture, image.data);
        UnloadImage(image);
    }
}

// 音符の種類ごとに onp_all を用意する（lua はないので見た目の切り替えはラベルで行う）
void EnsoScene::SetupNoteSprites() {
    const std::string path = std::string(kDir) + "onpu/onp_all";
    for (NoteType type : {NoteType::Don, NoteType::Do, NoteType::Ko, NoteType::Katsu, NoteType::Ka, NoteType::BigDon,
                          NoteType::BigKatsu, NoteType::Roll, NoteType::BigRoll, NoteType::Balloon, NoteType::Kusudama,
                          NoteType::HandDon, NoteType::HandKatsu}) {
        const std::string label = SpriteLabel(type);
        NoteSprite sprite;
        sprite.stage = std::make_unique<Lumen::Stage>();
        if (!sprite.stage->Load(path)) continue;
        MatchNoteLook(path);
        sprite.clip = sprite.stage->GetMovieClip("onp_base/onp0");
        if (!sprite.clip) continue;
        sprite.clip->GotoAndStop(label);
        // 音符の下の文字は日本語
        if (Lumen::MovieClip* moji = sprite.clip->Child("moji")) {
            moji->GotoAndStop("japanese");
            for (const char* part : {"head", "body", "tail"}) Goto(moji->Child(part), "japanese");
            if (Lumen::MovieClip* lang = moji->Child("language")) {
                const char* langLabel = label.c_str();
                if (type == NoteType::HandDon) langLabel = "te";
                else if (type == NoteType::HandKatsu) langLabel = "katsu_te";
                lang->GotoAndStop(langLabel);
            }
        }
        // 連打は胴と尻尾を別に描いて伸ばす
        if (type == NoteType::Roll || type == NoteType::BigRoll) {
            sprite.body = sprite.clip->Find("onp/body");
            sprite.tail = sprite.clip->Find("onp/tail");
        }
        sprites_[label] = std::move(sprite);
    }
    barStage_ = std::make_unique<Lumen::Stage>();
    if (barStage_->Load(path)) {
        bar_ = barStage_->GetMovieClip("bar_base/bar0");
        Goto(bar_, "bar");
    }
}

// あべこべ（ドンとカッをすべて入れ替える）とランダム（きまぐれ・でたらめの割合で入れ替える）。
// 大音符・手をつなぐ音符も同じ大きさのまま色だけ変える。連打・風船はそのまま
void EnsoScene::ApplyNoteOptions(Player& player) {
    const PlayOptions& options = player.options;
    const double rate = options.random == 1 ? kKimagureRate : options.random == 2 ? kDetarameRate : 0.0;
    if (!options.abekobe && rate <= 0.0) return;
    std::mt19937 random{std::random_device{}()};
    std::uniform_real_distribution<double> uniform(0.0, 1.0);
    auto flip = [](NoteType type) {
        switch (type) {
        case NoteType::Don: case NoteType::Do: return NoteType::Katsu;
        case NoteType::Ko: return NoteType::Ka;
        case NoteType::Katsu: return NoteType::Don;
        case NoteType::Ka: return NoteType::Ko;
        case NoteType::BigDon: return NoteType::BigKatsu;
        case NoteType::BigKatsu: return NoteType::BigDon;
        case NoteType::HandDon: return NoteType::HandKatsu;
        case NoteType::HandKatsu: return NoteType::HandDon;
        default: return type;
        }
    };
    for (Note& note : player.notes) {
        if (!note.src.IsHit()) continue;
        bool swap = options.abekobe;
        if (rate > 0.0 && uniform(random) < rate) swap = !swap;
        if (swap) note.src.type = flip(note.src.type);
    }
}

// 演奏スキップ（lua: option_enso_skip_window「つかっていない太鼓のフチを左右交互に 10回叩くと演奏を終了できます」）
void EnsoScene::UpdateEnsoSkip(float deltaTime) {
    if (players_.size() != 1 || !players_.front().options.ensoSkip || finished_ || skipped_) return;
    const int unused = players_.front().index == 0 ? 1 : 0;
    Lumen::MovieClip* root = skipPart_.Clip("skip_end");
    skipIdle_ += deltaTime;
    if (skipCount_ > 0 && skipIdle_ > kSkipResetSeconds) {
        skipCount_ = 0;
        skipLastSide_ = -1;
        Goto(root, "out", true);
    }
    const bool left = TaikoInput::IsHit(unused, TaikoInput::Pad::LeftKa);
    const bool right = TaikoInput::IsHit(unused, TaikoInput::Pad::RightKa);
    if (!left && !right) return;
    const int side = left ? 0 : 1;
    if (side == skipLastSide_) return;   // 同じフチを続けて叩いても数えない
    skipLastSide_ = side;
    skipIdle_ = 0.0f;
    if (skipCount_ == 0) Goto(root, "in", true);
    ++skipCount_;
    Goto(skipPart_.Clip("skip_end/skip_end_panel"), "count_" + std::to_string(std::min(skipCount_, kSkipHits)));
    SoundManager::Get().Play("se_common_v12a", "katsu_c");
    if (skipCount_ < kSkipHits) return;

    // 演奏を終える。成績は残さず、そのままリザルトへ
    skipped_ = true;
    SoundManager::Get().StopPreview(0.3f);
    finished_ = true;
    finishTimer_ = kResultSeconds - 1.0f;
}

void EnsoScene::Finalize() {
    HitAudio::ClearPadSounds();
    SoundManager::Get().StopAll();
    if (donTexture_.id != 0) UnloadRenderTexture(donTexture_);
    donTexture_ = RenderTexture2D{};
    don3d_.Unload();
    Lumen::ClearExternalTextures();
}

// ===========================================================================
// 進行
// ===========================================================================
void EnsoScene::Update(float deltaTime) {
    if (!loaded_) {
        if (TaikoInput::AnyDon()) SceneManager::GetInstance().ChangeScene(std::make_unique<SongSelectScene>());
        return;
    }

    // 画面を作った直後は、読み込みで最初のフレームが長くなる。そのまま進めると襖の動きが飛んでカクつくので、少しのあいだ上限をつける
    if (warmupFrames_ < 6) {
        ++warmupFrames_;
        deltaTime = std::min(deltaTime, 1.0f / 60.0f);
    }

    // 叩いた瞬間の音を鳴らすのは、叩きを受け付けているあいだだけ（ポーズ・暗転・演奏が終わったあと・特訓の停止中は鳴らさない）
    HitAudio::SetMonitorActive(!isPaused_ && !leaving_ && !(training_ && trainingPaused_));

    if (isPaused_) {
        pauseMenu_.Update(deltaTime);
        UpdatePauseMenu();
        return;
    }

    // ESCキーでポーズメニュー（再開する / 最初から / 選曲画面に戻る）。暗転中は受け付けない
    if (!leaving_ && TaikoInput::IsBackPressed()) {
        TogglePause();
        return;
    }

    // F2: 暗転して特訓モードに切り替える（今の小節で止めて始める）。もう一度押すと、暗転して最初から通常の演奏をやり直す
    if (TaikoInput::IsTrainingPressed() && !dani_ && !finished_ && !leaving_ && !LoadingScene::IsActive()) {
        if (!training_) EnterTraining();
        else FadeToEnso(false, 0);
        return;
    }
    if (leaving_ && !finished_) return;   // 暗転している
    if (training_) {
        for (float& flash : trainingButtonFlash_) flash = std::max(0.0f, flash - deltaTime);
        // 叩いた面・ふちを太鼓の絵で光らせる
        for (int p = 0; p < 2; ++p) {
            for (int pad = 0; pad < 4; ++pad) {
                float& flash = trainingHitFlash_[p][pad];
                flash = std::max(0.0f, flash - deltaTime);
                if (TaikoInput::IsHit(p, TaikoInput::Pad(pad))) flash = 0.12f;
            }
        }
    }
    if (training_ && trainingPaused_) {
        UpdateTraining(deltaTime);
        if (isPaused_ || !trainingPaused_) return;
        // 止めているあいだも、どんちゃん・背景・踊り子は動かしておく
        UpdateDonAnimation(deltaTime);
        danceTime_ += double(deltaTime);
        for (Player& player : players_) {
            UpdateDisplays(player);
            player.renda.Update(deltaTime);   // 連打数の表示が閉じるところまで流す
        }
        for (Part* part : {&bgBottom_, &bgFever_, &bgDai_, &dancer_, &feverEffect_, &donBg_, &donBgObj_, &donEnso_, &fukidashi_,
                           &songInfo_}) {
            part->Update(deltaTime);
        }
        return;
    }
    // 演奏中は 2P の太鼓の面（1人のとき）か Space で止める
    if (training_ && (TaikoInput::KeyPressed(KEY_SPACE) || (players_.size() == 1 && TaikoInput::IsDon(1)))) {
        PauseTraining();
        return;
    }
    if (training_) {
        // 演奏を始める前の1小節はカウントの音を鳴らす
        while (!trainingBeats_.empty() && clock_ >= trainingBeats_.front()) {
            SoundManager::Get().Play(kBankTraining, "count");
            trainingBeats_.erase(trainingBeats_.begin());
        }
    }

    // F3: オートプレイの入り切り（オートにした演奏は記録を残さない）
    // オートの入り切りは選曲画面と段位選択画面だけ（CommonParts::ToggleAutoPlay）。演奏中は切り替えられない
    if (autoPlay) autoUsed = true;
    UpdateDonAnimation(deltaTime);
    UpdateClock(deltaTime);
    for (Player& player : players_) UpdatePlayer(player);
    UpdateEnsoSkip(deltaTime);
    danceTime_ += double(deltaTime);
    UpdateStage(players_.front());
    UpdatePending(deltaTime);
    UpdateDaniSongInfo(deltaTime);
    if (dani_) UpdateDani(deltaTime);

    for (Part* part : {&bgBottom_, &bgFever_, &bgDai_, &dancer_, &feverEffect_, &donBg_, &donBgObj_, &donEnso_, &fukidashi_,
                       &songInfo_, &gogoEffect_, &result_, &fusenPart_, &kusudamaPart_, &rendaEffect_, &branchEffect_,
                       &skipPart_, &daniBg_, &daniDetail_, &daniPlate_, &daniBetween_}) {
        part->Update(deltaTime);
    }
    for (Cycle* cycle : {&donBgCycle_, &bgFeverCycle_, &feverEffectCycle_}) UpdateCycle(*cycle);
    for (Player& player : players_) {
        for (Part* part : {&player.lane, &player.laneHit, &player.laneLeft, &player.taiko, &player.scorePart, &player.comboPart,
                           &player.course2, &player.gauge, &player.hitEffect, &player.plate, &player.renda}) {
            part->Update(deltaTime);
        }
        for (size_t i = 1; i < player.addScores.size(); ++i) player.addScores[i].Update(deltaTime);
        // 加点の表示から 32 フレーム後にスコアの表示を増やす
        for (size_t i = 0; i < player.pendingScores.size();) {
            Player::PendingScore& pending = player.pendingScores[i];
            pending.remain -= deltaTime;
            if (pending.remain > 0.0f) {
                ++i;
                continue;
            }
            player.displayScore += pending.points;
            player.pendingScores.erase(player.pendingScores.begin() + long(i));
        }
        for (Player::Jump& jump : player.jumps) {
            if (jump.remain <= 0.0f) continue;
            jump.part.Update(deltaTime);
            jump.remain -= deltaTime;
            jump.elapsed += deltaTime;
            // 始めは速く、合流するところでゆっくり（ease-out）
            const float t = 1.0f - std::min(1.0f, jump.elapsed / kJumpMergeSeconds);
            jump.part.pos.x = jump.offsetX * t * t;
            if (jump.remain <= 0.0f) {
                if (Lumen::MovieClip* root = jump.part.Root()) root->SetVisible(false);
            }
        }
    }
    for (auto& entry : sprites_) entry.second.stage->Update(deltaTime);
    if (barStage_) barStage_->Update(deltaTime);

    // 最後の音符が終わり、曲も終わったら結果を出す（特訓モードでは最初の小節を選んで止まる）
    if (!finished_ && songStarted_ && clock_ > lastTime_ + 1500.0 &&
        (SoundManager::Get().IsSongFinished() || clock_ > lastTime_ + 6000.0)) {
        if (training_) {
            PauseTraining();
            trainingMeasure_ = 0;
            return;
        }
        Finish();
    }
    if (finished_ && !leaving_ && !dani_) {
        finishTimer_ += deltaTime;
        UpdateResultVoice();
        if (finishTimer_ >= kResultSeconds) {
            // この画面は黒いフェードが終わるまで後ろに描かれる
            leaving_ = true;
            StoreResults();
            SceneManager::GetInstance().ChangeScene(std::make_unique<LoadingScene>(LoadingScene::Next::Result), true);
        }
    }
}

// 曲の再生位置に合わせて時刻を進める（再生位置は音声のバッファ単位でしか進まないので、なめらかに寄せる）
void EnsoScene::UpdateClock(float dt) {
    SoundManager& sound = SoundManager::Get();
    if (!songStarted_) {
        if (!sound.IsSongPrepared(song_.SoundBank())) return;   // 変換が終わるまで待つ
        // 曲の読み込み（数十 ms かかる）は曲の前の待ちのあいだに済ませ、止めたまま置いておく。
        // 流し始めるときに読み込むと、そのフレームが止まって時刻が曲の位置から飛び、音符が一瞬戻って見える
        if (!songLoading_) {
            sound.PlaySong(song_.SoundBank());
            sound.PauseSong();
            songLoading_ = true;
        }
        // 最初のフレームは画面の準備の時間まで含んで長いことがあるので、1フレームで進める時刻に上限をつける
        clock_ += std::min(double(dt), 0.05) * 1000.0;
        // 聞こえるまでの遅れ（lag）の分だけ先に流し始め、時刻は止めずにそのまま進める。
        // 曲の読み込みが済むまでは、流し始める時刻の手前で待つ
        const double lag = Lag();
        if (!sound.IsSongLoaded()) {
            clock_ = std::min(clock_, -lag - 1.0);
            return;
        }
        if (clock_ >= -lag) {
            sound.ResumeSong();
            songStarted_ = true;
            drift_ = 0.0;
        }
        return;
    }
    // 特訓モードで曲の頭より前から始めたとき: 曲の頭の時刻になったら曲を流し始める
    const double speed = double(trainingTempo_);
    if (trainingCountIn_) {
        clock_ += std::min(double(dt), 0.05) * 1000.0 * speed;
        const double lag = Lag();
        if (clock_ >= -lag) {
            sound.SeekSong(0.0f);
            sound.ResumeSong();
            trainingCountIn_ = false;
            drift_ = 0.0;
        }
        return;
    }
    // 時刻はフレームの経過時間で進め、曲の再生位置（聞こえている位置）からずれてきたら寄せる
    if (fixedStep) {
        clock_ += double(dt) * 1000.0 * speed;
        return;
    }
    const double lag = Lag();
    const float played = sound.SongTime();
    if (played < 0.0f) {
        // 曲がまだ読み込まれていない（鳴り始めていない）ので、時刻を進めない
        clock_ = -lag;
        return;
    }
    const double before = clock_;
    clock_ += double(dt) * 1000.0 * speed;
    if (!sound.IsSongFinished() && !sound.IsSongPaused()) {
        // 再生位置は音声の処理の単位（数 ms〜十数 ms）でしか進まないので、そのまま寄せると音符の速さがふらつく。
        // ずれを 0.25 秒ほどかけてならしてから、0.5 秒ほどかけてゆっくり寄せる（1フレームで動かすのは 0.1ms 程度）。
        // 大きくずれたとき（止まった・飛んだ）だけ一気に合わせる
        const double target = double(played) * 1000.0 - lag;
        const double diff = target - clock_;
        if (std::fabs(diff) > 60.0) {
            clock_ = target;
            drift_ = 0.0;
        } else {
            drift_ += (diff - drift_) * std::min(1.0, double(dt) / 0.25);
            clock_ += drift_ * std::min(1.0, double(dt) / 0.5);
        }
    }
    if (logClock) {
        // 確認用: 時刻の進みが経過時間からどれだけずれたか（1秒ごとに最大を出す）
        static double worst = 0.0, sinceLog = 0.0;
        worst = std::max(worst, std::fabs((clock_ - before) - double(dt) * 1000.0 * speed));
        sinceLog += dt;
        if (sinceLog >= 1.0) {
            TraceLog(LOG_WARNING, "clock: 1フレームの進みのずれ 最大 %.2f ms（時刻 %.0f 曲 %.0f 速さ %.2f）", worst, clock_,
                     double(played) * 1000.0, speed);            worst = sinceLog = 0.0;
        }
    }
}

void EnsoScene::UpdatePlayer(Player& player) {
    const Fumen& f = player.fumen;
    const double badWindow = f.windows[2];

    // ---- 入力 ----
    if (finished_) {
        // 曲が終わったあと、リザルトへ行くまでも、叩いた音と太鼓は反応させる（判定・得点は動かさない）
        const int p = player.index;
        if (TaikoInput::IsHit(p, TaikoInput::Pad::LeftDon)) HitFeedback(player, true, false);
        if (TaikoInput::IsHit(p, TaikoInput::Pad::RightDon)) HitFeedback(player, true, true);
        if (TaikoInput::IsHit(p, TaikoInput::Pad::LeftKa)) HitFeedback(player, false, false);
        if (TaikoInput::IsHit(p, TaikoInput::Pad::RightKa)) HitFeedback(player, false, true);
    } else {
        const int p = player.index;
        if (TaikoInput::IsHit(p, TaikoInput::Pad::LeftDon)) Hit(player, true, false);
        if (TaikoInput::IsHit(p, TaikoInput::Pad::RightDon)) Hit(player, true, true);
        if (TaikoInput::IsHit(p, TaikoInput::Pad::LeftKa)) Hit(player, false, false);
        if (TaikoInput::IsHit(p, TaikoInput::Pad::RightKa)) Hit(player, false, true);

        if (autoPlay) {
            for (size_t i = player.first; i < player.notes.size(); ++i) {
                const Note& note = player.notes[i];
                if (note.src.time > clock_) break;
                if (note.judged) continue;
                if (note.src.IsHit()) {
                    Hit(player, note.src.IsDon(), false);
                } else if (clock_ <= note.src.time + note.src.duration && std::fmod(clock_, 70.0) < 18.0) {
                    Hit(player, true, false);   // 連打・風船は 1 秒に 14 回ほど
                }
            }
        }
    }

    // ---- 見逃した音符・終わった連打 ----
    for (size_t i = player.first; i < player.notes.size(); ++i) {
        Note& note = player.notes[i];
        if (note.src.time <= clock_ && !note.judged) {
            if (note.src.type == NoteType::Balloon && activeBalloon_ < 0) {
                StartBalloon(player, int(i));
            } else if (note.src.type == NoteType::Kusudama && activeKusudama_ < 0) {
                StartKusudama(player, int(i));
            }
        }
        if (note.src.time > clock_ + badWindow) break;
        if (note.judged) continue;
        if (note.src.IsHit() && clock_ > note.src.time + badWindow) {
            ApplyJudge(player, note, Judge::Bad, true);
        } else if ((note.src.IsRoll() || note.src.IsBalloon()) && clock_ > note.src.time + note.src.duration) {
            note.judged = true;
            if (player.activeRoll == int(i)) {
                player.activeRoll = -1;
                UpdateRenda(player, false);
            }
            if (note.src.type == NoteType::Balloon && activeBalloon_ == int(i)) {
                MissBalloon(player);
            } else if (note.src.type == NoteType::Kusudama && activeKusudama_ == int(i)) {
                MissKusudama(player);
            }
        }
    }
    while (player.first < player.notes.size() && player.notes[player.first].judged) ++player.first;

    // ---- ゴーゴータイム ----
    bool gogo = false;
    for (const auto& change : player.gogo) {
        if (change.first > clock_) break;
        gogo = change.second;
    }
    if (gogo != player.gogoNow) {
        player.gogoNow = gogo;
        Goto(player.laneHit.Clip("gogo"), gogo ? "in" : "out", true);
        if (gogo) Goto(gogoEffect_.Root(), "splash", true);
    }

    UpdateDisplays(player);
}

// 叩いたときの音と太鼓の動き（判定はしない）。曲が終わってリザルトへ行くまでの間も、これだけは出す
void EnsoScene::HitFeedback(Player& player, bool don, bool right) {
    const std::vector<int> side = players_.size() >= 2 ? std::vector<int>{0, 1} : std::vector<int>{0};
    // 叩いた瞬間に監視が音を鳴らしていたら、ここでは鳴らさない（重ねない）
    const int pad = don ? (right ? int(TaikoInput::Pad::RightDon) : int(TaikoInput::Pad::LeftDon))
                        : (right ? int(TaikoInput::Pad::RightKa) : int(TaikoInput::Pad::LeftKa));
    if (!HitAudio::ConsumeEarlyHit(player.index, pad)) {
        // ドン（面）の音は音圧が強いので下げる（カッはそのまま）
        SoundManager::Get().Play(player.hitBank, std::string(don ? "don" : "katsu") + Side(side, player.index), don ? kDonVolume : 1.0f);
    }
    Goto(player.taiko.Clip(std::string(right ? "right_" : "left_") + (don ? "don" : "katsu")), "on", true);
    // レーンの光（叩いた色）。区切り 10 フレームだけ流して、何も出ていない頭のフレームに戻す
    PlayOnce(player.laneHit.Clip("effect"), don ? "don_s" : "katsu_s", 10, "", 0);
}

// 叩いた（面: don = true、ふち: false）
void EnsoScene::Hit(Player& player, bool don, bool right) {
    const Fumen& f = player.fumen;
    HitFeedback(player, don, right);

    // 連打・風船の最中
    for (size_t i = player.first; i < player.notes.size(); ++i) {
        Note& note = player.notes[i];
        if (note.src.time > clock_) break;
        if (note.judged || !(note.src.IsRoll() || note.src.IsBalloon())) continue;
        if (clock_ > note.src.time + note.src.duration) continue;
        if (note.src.IsBalloon() && !don) return;   // 風船は面だけ
        ++note.count;
        ++player.rolls;
        player.activeRoll = int(i);
        const int points = note.src.type == NoteType::BigRoll ? 200 : 100;
        player.score += points;
        ShowAddScore(player, points);   // 連打も1打ごとに加点を出す（lua: tutorial scene07）
        // 連打数の扇は連打とくす玉だけ。風船は風船の吹き出しに残りの数が出るので扇は出さない
        if (note.src.type != NoteType::Balloon) UpdateRenda(player, true);

        if (note.src.type == NoteType::Balloon) {
            HitBalloon(player);
        } else if (note.src.type == NoteType::Kusudama) {
            HitKusudama(player);
        } else {
            // 連打は1打ごとに、叩いた面・ふちの音符が飛んでいく（大きい連打は大きい音符）
            if (note.src.type == NoteType::BigRoll) LaunchJump(player, don ? "daiRenda" : "daiRendaKatsu");
            else LaunchJump(player, don ? "don" : "katsu");
            if (Lumen::MovieClip* root = rendaEffect_.Root()) {
                root->SetVisible(true);
                Goto(root, players_.size() >= 2 && player.index == 1 ? "mask_2p" : "mask_1p", true);
                Schedule(root, "", 0.3f, false, true);
            }
        }

        if (note.src.IsBalloon() && note.count >= std::max(1, note.src.hits)) {
            // 割れた
            note.judged = true;
            note.brokeAt = clock_;
            // 風船は叩いた数 × 100 点だけで、割れたときの加点はない（くす玉は割れたら 5000 点）
            if (note.src.type == NoteType::Kusudama) {
                player.score += 5000;
                ShowAddScore(player, 5000);
                BreakKusudama(player);
            } else {
                BreakBalloon(player);
            }
            player.activeRoll = -1;
            UpdateRenda(player, false);
        }
        return;
    }

    // 判定する音符を選ぶ。前から順に、不可の幅（windows[2]）に入っている音符を見る
    //   ・同じ色: その音符を判定する（早すぎ・遅すぎで不可の幅なら不可）。
    //     ただし不可になる距離で、後ろにもっと近い同じ色の音符があれば、そちらをねらったとみなす
    //     （前の音符は叩かれないまま通り過ぎて不可になる）
    //   ・違う色: 判定しない（空打ちとして、後ろの音符を見る）。ドンとカッを同時に叩く「ドカッ」「カドッ」や、
    //     dk kd を dkdkd のように間に空打ちを入れても、違う色で音符を巻き込んで不可にしない
    //   不可の幅より早い打鍵は、どの音符にも当たらない空打ち
    for (size_t i = player.first; i < player.notes.size(); ++i) {
        Note& note = player.notes[i];
        const double diff = note.src.time - clock_;
        if (diff > f.windows[2]) break;
        if (note.judged || !note.src.IsHit()) continue;
        const double error = std::fabs(diff);
        if (note.src.IsDon() != don) continue;
        if (error > f.windows[1]) {
            bool closer = false;
            for (size_t j = i + 1; j < player.notes.size(); ++j) {
                const Note& next = player.notes[j];
                const double nextDiff = next.src.time - clock_;
                if (nextDiff > f.windows[2]) break;
                if (next.judged || !next.src.IsHit() || next.src.IsDon() != don) continue;
                closer = std::fabs(nextDiff) < error;
                break;
            }
            if (closer) continue;
        }
        if (error <= f.windows[0]) ApplyJudge(player, note, Judge::Good);
        else if (error <= f.windows[1]) ApplyJudge(player, note, Judge::Ok);
        else ApplyJudge(player, note, Judge::Bad);
        return;
    }
}

// 判定枠の真ん中から魂ゲージへ音符を飛ばす（onp_jump。type は types のラベルの頭: don / katsu / daiDon / daiRenda など）
void EnsoScene::LaunchJump(Player& player, const std::string& type, float offsetX, float seconds) {
    Player::Jump& jump = player.jumps[player.nextJump];
    player.nextJump = (player.nextJump + 1) % player.jumps.size();
    Lumen::MovieClip* root = jump.part.Root();
    if (!root) return;
    root->SetVisible(true);
    root->GotoAndPlay("start");
    Lumen::MovieClip* types = jump.part.Clip("base/types");
    Goto(types, type + (player.index == 0 ? "1p" : "2p"));
    // 使い回しで前と同じ種類のときは types のフレームが変わらず、中の飛ぶ動き（don1p など）が前の終わり
    // （48 フレーム目）のままになって、一周して頭に戻るまで飛び出さない。叩いたフレームから飛ぶよう頭から流し直す
    if (types) {
        for (auto& entry : types->DisplayList()) {
            if (entry.second.clip) entry.second.clip->GotoAndPlay(0);
        }
    }
    jump.part.Update((float(kJumpSkipFrames) + 0.01f) / 60.0f);
    jump.remain = seconds;
    // 飛ぶ動きの頭は判定枠の真ん中なので、叩いた位置とのずれの分だけずらして始め、魂ゲージに着くまでに 0 にする
    jump.elapsed = 0.0f;
    jump.offsetX = offsetX;
    jump.part.pos.x = offsetX;
}

void EnsoScene::ApplyJudge(Player& player, Note& note, Judge judge, bool missed) {
    note.judged = true;
    note.missed = missed;
    const Fumen& f = player.fumen;
    const bool big = note.src.IsBig();

    if (judge == Judge::Bad) {
        ++player.bad;
        player.combo = 0;
        player.hp += f.hpBad;
        if (player.index == players_.front().index && activeBalloon_ < 0 && activeKusudama_ < 0) {
            don_.SetNonLoopAnimation("miss", false);
        }
    } else {
        const bool good = judge == Judge::Good;
        if (good) ++player.good;
        else ++player.ok;
        ++player.combo;
        player.maxCombo = std::max(player.maxCombo, player.combo);
        player.hp += good ? f.hpGood : f.hpOk;
        // 真打: 良は配点どおり、可は半分（10点単位で切り捨て）。大音符も同じ点数
        const int points = good ? player.shinuti : player.shinuti / 20 * 10;
        player.score += points;
        ShowAddScore(player, points);

        // 叩いた音符は、叩いた位置にかかわらず、判定枠から魂ゲージへ飛んでいく（onp_jump）
        const bool isDon = note.src.IsDon();
        LaunchJump(player, big ? (isDon ? "daiDon" : "daiKatsu") : (isDon ? "don" : "katsu"), 0.0f);

        // コンボのボイスと吹き出し
        // むずかしい以下: 10, 30, 50, 100 ごと。おに（裏も）: 50, 100 ごと
        const int c = player.combo;
        const bool oni = player.course >= kCourseOni;
        if ((!oni && (c == 10 || c == 30)) || c == 50 || (c >= 100 && c % 100 == 0 && c <= 5000)) {
            if (VoiceOn(player)) SoundManager::Get().Play(kBankVoice, TextFormat("combo_%04d_c", c));
            if (player.index == players_.front().index) ShowFukidashi(c);
        }
    }
    player.hp = std::clamp(player.hp, 0, f.hpMax);

    // 段位道場の魂ゲージは3曲で1本。曲ごとの増え方（満タンまでの割合）に、その曲の音符の数の割合をかけて足す
    if (dani_ && f.hpMax > 0) {
        DaniRun& run = PlayDataManager::Get().Dani();
        const int delta = judge == Judge::Bad ? f.hpBad : judge == Judge::Good ? f.hpGood : f.hpOk;
        const double weight = run.totalNotes > 0 ? double(run.notes[size_t(run.songIndex)]) / run.totalNotes : 1.0 / kDaniSongCount;
        run.gauge = std::clamp(run.gauge + double(delta) / f.hpMax * weight, 0.0, 1.0);
    }

    // 見逃した不可は判定の表示を出さない（叩いた不可だけ出す）
    if (!missed) ShowJudge(player, note, judge);
}

// 判定の演出。良・可は叩けたときだけ（判定枠の光、良/可の文字と火花）。見逃し・不可は判定枠の「不可」だけ
void EnsoScene::ShowJudge(Player& player, const Note& note, Judge judge) {
    const bool big = note.src.IsBig();
    static const char* const kLaneLabels[2][3] = {{"hit_ryo", "hit_ka", "hit_huka"}, {"hit_dai_ryo", "hit_dai_ka", "hit_dai_huka"}};
    PlayOnce(player.laneHit.Clip("hit_effect"), kLaneLabels[big ? 1 : 0][int(judge)], 20, "no_onp");
    if (big && judge != Judge::Bad) PlayOnce(player.laneHit.Clip("effect"), note.src.IsDon() ? "don_b" : "katsu_b", 10, "", 0);

    // 良/可/不可の文字と火花（hit_effect）。base をその判定のフレームで止め、中の演出だけを頭から流す
    // （不可は大音符でも同じ文字。叩き間違い・早すぎ・見逃しのどれでも出す）
    Lumen::MovieClip* root = player.hitEffect.Root();
    Lumen::MovieClip* base = player.hitEffect.Clip("origin/base");
    if (!root || !base) return;
    struct Kind {
        const char* base;
        const char* child;
        const char* label;
    };
    static const Kind kKinds[2][3] = {{{"ryo", "ryo", "hit_ryo"}, {"ka", "ka", "hit_ka"}, {"fuka", "fuka", "hit_huka"}},
                                      {{"ryoBig", "ryoBig", "hit_ryo_big"}, {"kaBig", "kaBig", "hit_ka_big"}, {"fuka", "fuka", "hit_huka"}}};
    const Kind& kind = kKinds[big ? 1 : 0][int(judge)];
    base->GotoAndStop(kind.base);
    Goto(base->Child(kind.child), kind.label, true);
    root->SetVisible(true);
    // 中の演出（hit_ryo など）は 20 フレームで、放っておくと頭に戻ってもう一度流れるので、流し終えたところで隠す
    // （次に叩けば出し直す）
    Schedule(root, "", float(kJudgeEffectFrames) / 60.0f, false, true);
}

// スコア・コンボ・魂ゲージ・連打数の表示
void EnsoScene::UpdateDisplays(Player& player) {
    // スコア（7桁、上の桁の 0 は出さない）。増えるたびに数字が跳ねる（lua: TutorialScore.ScoreUpdate は GotoAndPlay）
    if (player.displayScore != player.shownScore) {
        const bool first = player.shownScore < 0;
        player.shownScore = player.displayScore;
        const std::string digits = std::to_string(std::min(player.displayScore, 9999999));
        for (int d = 1; d <= 7; ++d) {
            Lumen::MovieClip* clip = player.scorePart.Clip("score/digit" + std::to_string(d));
            const int index = int(digits.size()) - d;
            Goto(clip, index >= 0 ? "number_" + std::string(1, digits[size_t(index)]) : "none", !first);
        }
    }

    // コンボ（10 から出す。桁数ごとに別の数字の組を使う）
    if (player.combo != player.shownCombo) {
        // 増えたときは数字を縮めて戻す（数字の各ラベルの 10 フレームの動き。最後のフレームで止まる）
        const bool bump = player.combo > player.shownCombo;
        player.shownCombo = player.combo;
        Lumen::MovieClip* combo = player.comboPart.Clip("combo_num");
        // 「コンボ」の文字は数字と同時に出す（10 コンボから）
        if (Lumen::MovieClip* text = player.comboPart.Clip("text")) text->SetVisible(player.combo >= 10);
        if (player.combo < 10) {
            Goto(combo, "init");
        } else {
            const int level = player.combo >= 100 ? 3 : player.combo >= 50 ? 2 : 1;
            Goto(combo, "level" + std::to_string(level));
            const std::string digits = std::to_string(std::min(player.combo, 9999));
            const std::string group = "combo_level" + std::to_string(level);
            static const char* const kGroups[] = {"digit1_", "digit10_", "digit100_", "digit1000_"};
            for (int g = 0; g < 4; ++g) {
                for (int d = 0; d <= g; ++d) {
                    Lumen::MovieClip* clip = player.comboPart.Clip(group + "/" + kGroups[g] + std::to_string(d));
                    if (!clip) continue;
                    // 桁数が合う組だけ数字を出す（_0 が一の位）
                    if (int(digits.size()) == g + 1) Goto(clip, "number_" + std::string(1, digits[digits.size() - 1 - size_t(d)]), bump);
                    else Goto(clip, "number_none");
                }
            }
        }
    }

    // 魂ゲージ（50 目盛り）。段位道場は UpdateDani
    if (dani_) return;
    const int gauge = player.fumen.hpMax > 0 ? player.hp * 50 / player.fumen.hpMax : 0;
    if (gauge != player.shownGauge) {
        player.shownGauge = gauge;
        // 満タンになったら虹色に光らせ、魂に炎をつける（リザルトと同じ rainbow / fire）。減ったら戻す
        const bool full = gauge >= 50;
        const bool changed = full != player.gaugeFull;
        player.gaugeFull = full;
        if (Lumen::MovieClip* root = player.gauge.Root()) {
            for (auto& entry : root->DisplayList()) {
                Lumen::MovieClip* clip = entry.second.clip.get();
                if (!clip) continue;
                clip->GotoAndStop("gage_" + std::to_string(gauge));
                if (!changed) continue;
                Goto(clip->Child("rainbow"), full ? "fever_start" : "fever_end", true);
                Goto(clip->Child("fire"), full ? "fever_start" : "fever_end", true);
            }
        }
    }

}

// ===========================================================================
// 演出
// ===========================================================================
// 連打数（renda_number）。叩くたびに数字が跳ね、連打が終わったら消える
void EnsoScene::UpdateRenda(Player& player, bool hit) {
    Lumen::MovieClip* main = player.renda.Clip(players_.size() >= 2 ? "main_duet_mc" : "main_solo_mc");
    if (!main) return;
    if (!hit) {
        if (player.rendaOpen) Goto(main, "out", true);
        player.rendaOpen = false;
        player.rendaShown = -1;
        return;
    }
    if (player.activeRoll < 0 || size_t(player.activeRoll) >= player.notes.size()) return;
    const Note& note = player.notes[size_t(player.activeRoll)];
    const int count = std::min(999, note.src.IsBalloon() ? std::max(0, note.src.hits - note.count) : note.count);
    if (count == player.rendaShown) return;
    player.rendaShown = count;
    // 扇は連打の最初の1打で開き（hit。開いたあと 38 フレーム目で止まって開いたままになる）、連打が終わるまで閉じない。
    // 2打目からは数字だけ変える（数字は number_N で1打ごとに跳ねる）
    if (!player.rendaOpen) Goto(main, "hit", true);
    player.rendaOpen = true;
    const std::string digits = std::to_string(count);
    Goto(Sub(main, "renda_num"), digits.size() >= 3 ? "renda_hit_100" : digits.size() == 2 ? "renda_hit_10" : "renda_hit_1");
    static const char* const kGroups[] = {"digit1_", "digit10_", "digit100_"};
    const int g = int(digits.size()) - 1;
    // renda_num には 1桁・2桁・3桁用の数字（digit1_0 / digit10_0〜1 / digit100_0〜2）がまとめて置かれていて、
    // renda_hit_10 などのラベルでは使わない組の一部しか消えない。使わない組は前の連打の数字（0 など）が残って
    // 重なって見えるので、今の桁数の組だけを出す
    for (int group = 0; group < 3; ++group) {
        for (int d = 0; d <= group; ++d) {
            if (Lumen::MovieClip* clip = Sub(main, std::string("renda_num/") + kGroups[group] + std::to_string(d))) {
                clip->SetVisible(group == g);
            }
        }
    }
    for (int d = 0; d <= g; ++d) {
        Goto(Sub(main, std::string("renda_num/") + kGroups[g] + std::to_string(d)),
             "number_" + std::string(1, digits[digits.size() - 1 - size_t(d)]), true);
    }
}

// 叩いたときに加わった点数（スコアの横に出る）
void EnsoScene::ShowAddScore(Player& player, int points) {
    // スコアの表示は 32 フレーム後に増える（lua: TutorialScore.Create）
    player.pendingScores.push_back(Player::PendingScore{points, kAddScoreDelay});

    // 加点の表示は4つを順に使う（lua: score_plus の addScore_current_id）
    const int slot = player.nextAddScore;
    player.nextAddScore = (player.nextAddScore + 1) % kAddScoreCount;
    const Part& part = slot == 0 || size_t(slot) >= player.addScores.size() ? player.scorePart : player.addScores[size_t(slot)];
    const char* name = players_.size() >= 2 ? (player.index == 0 ? "add_score_r_1p_mc" : "add_score_r_2p_mc") : "add_score_l_mc";
    Lumen::MovieClip* add = part.Clip(name);
    if (!add) return;
    const std::string digits = std::to_string(std::min(points, 99999));
    for (int d = 1; d <= 6; ++d) {
        const int index = int(digits.size()) - d;
        std::string label = "none";
        if (index >= 0) label = "number_" + std::string(1, digits[size_t(index)]);
        else if (index == -1) label = "plus";
        Goto(Sub(add, "digit" + std::to_string(d)), label);
    }
    // 32 フレームの演出。放っておくと頭に戻って出続けるので、1回流したら隠す
    add->SetVisible(true);
    add->GotoAndPlay("score");
    Schedule(add, "", float(add->FrameCount() - 1) / 60.0f, false, true);
}

// コンボの吹き出し（どんちゃんが「○○コンボ！」と言う）
void EnsoScene::ShowFukidashi(int combo) {
    Lumen::MovieClip* main = fukidashi_.Clip("main_1p");
    if (!main) return;
    Goto(Sub(main, "combo_num"), "combo" + std::to_string(combo));
    main->GotoAndPlay("start");
}

// 魂ゲージに合わせて、踊り子の人数・クリアの背景・入魂（満タン）の演出を切り替える
void EnsoScene::UpdateStage(const Player& player) {
    const Fumen& f = player.fumen;
    if (dani_) {
        // 段位道場は踊り子も背景の切り替えもない。満タンでどんちゃんが光る
        SetFever(PlayDataManager::Get().Dani().gauge >= 1.0);
        return;
    }
    if (f.hpMax <= 0) return;
    const int gauge = player.hp * 50 / f.hpMax;
    const int clear = std::max(1, f.hpClear * 50 / f.hpMax);
    // 始めは3人。クリアの半分で4人目、クリアで5人目が入ってくる
    SetDancers(gauge >= clear ? 5 : gauge * 2 >= clear ? 4 : kStartDancers);
    SetClear(gauge >= clear);
    SetFever(player.hp >= f.hpMax);

    // 踊り子は「入場 → 踊り（dance〜out の手前を繰り返す）」。後から入場した人もそろうよう、
    // 踊りのどのフレームにいるかは共通の時計（danceTime_）で決め、入場を終えた人をそのフレームに合わせる
    if (Lumen::MovieClip* root = dancer_.Root()) {
        for (int i = 0; i < dancers_; ++i) {
            Lumen::MovieClip* pos = root->Child("pos" + std::to_string(i));
            if (!pos) continue;
            {
                Lumen::MovieClip* dancer = pos->Child(DancerName(i, dancerVariants_));
                if (!dancer) continue;
                const int dance = dancer->LabelFrame("dance");
                const int out = dancer->LabelFrame("out");
                if (dance < 0 || out <= dance) continue;
                const int frame = dancer->CurrentFrame();
                if (frame < dance - 1 || frame >= out) continue;   // 入場中・退場中はそのまま
                const int target = dance + int(danceTime_ * 60.0) % (out - dance);
                // 1フレームまでのずれは次の更新で追いつくので、それより離れていたら合わせ直す。
                // 踊りの最後のフレームに来たら（そのままだと退場に進むので）必ず合わせ直す
                const int length = out - dance;
                const int diff = std::abs(frame - target);
                const int distance = std::min(diff, length - diff);
                if (frame != target && (distance > 1 || frame >= out - 1)) dancer->GotoAndPlay(target);
            }
        }
    }
}

void EnsoScene::SetDancers(int count) {
    Lumen::MovieClip* root = dancer_.Root();
    if (!root || count == dancers_) return;
    // 中央から順に出てくる
    for (int i = dancers_; i < count; ++i) {
        Lumen::MovieClip* pos = root->Child("pos" + std::to_string(i));
        if (!pos) continue;
        pos->SetVisible(true);
        Goto(pos->Child(DancerName(i, dancerVariants_)), "in", true);
    }
    // 減ったら後から来た人から退場する
    for (int i = count; i < dancers_; ++i) {
        Lumen::MovieClip* pos = root->Child("pos" + std::to_string(i));
        if (!pos) continue;
        Goto(pos->Child(DancerName(i, dancerVariants_)), "out", true);
        Schedule(pos, "", 1.5f, false, true);
    }
    dancers_ = count;
}

// クリアのラインに乗ったら、上（どんちゃんの背景）と下の背景をクリアの絵にする
void EnsoScene::SetClear(bool clear) {
    if (clear == clear_) return;
    clear_ = clear;
    for (Cycle* cycle : {&donBgCycle_, &bgFeverCycle_}) SetCycle(*cycle, clear);
}

// 入魂（魂ゲージが満タン）: 下におみこし（fever_effect）、上におみこしの行列（donbg_obj）
void EnsoScene::SetFever(bool fever) {
    if (fever == fever_) return;
    fever_ = fever;
    SetCycle(feverEffectCycle_, fever);
    if (Lumen::MovieClip* root = donBgObj_.Root()) {
        root->SetVisible(fever);
        if (fever) root->GotoAndPlay(0);   // 行列は端から歩いてくる
    }
    for (const char* name : {"light", "kirakira"}) {
        if (Lumen::MovieClip* clip = donEnso_.Clip(name)) clip->SetVisible(fever);
    }
}

void EnsoScene::SetCycle(Cycle& cycle, bool on) {
    if (!cycle.clip) return;
    if (on) {
        cycle.clip->SetVisible(true);
        cycle.clip->GotoAndPlay(cycle.in);
        cycle.phase = 1;
    } else if (cycle.phase != 0) {
        cycle.clip->GotoAndPlay(cycle.out);
        cycle.phase = 3;
    }
}

void EnsoScene::UpdateCycle(Cycle& cycle) {
    if (!cycle.clip) return;
    const int frame = cycle.clip->CurrentFrame();
    const int loopStart = cycle.clip->LabelFrame(cycle.loop);
    const int outStart = cycle.clip->LabelFrame(cycle.out);
    const int outEnd = cycle.outEnd > 0 ? cycle.outEnd : cycle.clip->FrameCount();
    switch (cycle.phase) {
    case 0:
        // ふだんの繰り返しは、次のラベル（入り）に着いたら頭に戻す
        if (!cycle.offLoop.empty() && frame >= cycle.clip->LabelFrame(cycle.in) - 1) cycle.clip->GotoAndPlay(cycle.offLoop);
        break;
    case 1:
        if (frame >= loopStart) cycle.phase = 2;
        break;
    case 2:
        if (frame >= outStart - 1) cycle.clip->GotoAndPlay(cycle.loop);
        break;
    case 3:
        if (frame >= outEnd - 1 || !cycle.clip->IsPlay()) {
            cycle.phase = 0;
            if (cycle.hideWhenOff) {
                cycle.clip->Stop();
                cycle.clip->SetVisible(false);
            } else if (!cycle.offLoop.empty()) {
                cycle.clip->GotoAndPlay(cycle.offLoop);
            }
        }
        break;
    }
}

void EnsoScene::Schedule(Lumen::MovieClip* clip, const std::string& label, float seconds, bool play, bool hide, int frame) {
    if (!clip) return;
    // 同じクリップへの予約は新しいものに置き換える（続けて叩いたときに前の予約で止めてしまわないように）
    pending_.erase(std::remove_if(pending_.begin(), pending_.end(), [clip](const Pending& p) { return p.clip == clip; }),
                   pending_.end());
    Pending pending;
    pending.clip = clip;
    pending.label = label;
    pending.remain = seconds;
    pending.play = play;
    pending.hide = hide;
    pending.frame = frame;
    pending_.push_back(pending);
}

void EnsoScene::PlayOnce(Lumen::MovieClip* clip, const std::string& label, int frames, const std::string& restLabel, int restFrame) {
    if (!clip || clip->LabelFrame(label) < 0) return;
    clip->GotoAndPlay(label);
    Schedule(clip, restLabel, float(frames) / 60.0f, false, false, restLabel.empty() ? restFrame : -1);
}

void EnsoScene::UpdatePending(float dt) {
    for (size_t i = 0; i < pending_.size();) {
        Pending& p = pending_[i];
        p.remain -= dt;
        if (p.remain > 0.0f) {
            ++i;
            continue;
        }
        // 踊り子がまた出てきていたら隠さない
        const bool stillShown = p.hide && p.clip->Name().rfind("pos", 0) == 0 &&
                                std::atoi(p.clip->Name().c_str() + 3) < dancers_;
        if (p.hide && !stillShown) p.clip->SetVisible(false);
        if (!p.label.empty()) Goto(p.clip, p.label, p.play);
        else if (p.frame >= 0) p.clip->GotoAndStop(p.frame);
        pending_.erase(pending_.begin() + long(i));
    }
}

void EnsoScene::Finish() {
    if (dani_) {
        DaniSongEnd();
        return;
    }
    finished_ = true;
    finishTimer_ = 0.0f;
    const Player& main = players_.front();
    const bool clear = main.hp >= main.fumen.hpClear;
    const bool fullCombo = main.bad == 0 && !main.notes.empty();
    const bool perfect = fullCombo && main.ok == 0;
    const char* clip = perfect ? "dondafullMc" : fullCombo ? "fullcomboMc" : clear ? "successMc" : "failMc";
    if (Lumen::MovieClip* mc = result_.Clip(clip)) {
        mc->SetVisible(true);
        mc->GotoAndPlay("start");
    }
    const char* se = perfect ? "dondafullcombo_c" : fullCombo ? "fullcombo_c" : clear ? "clear_c" : "notclear_c";
    // クリア・フルコンボ・失敗の効果音（ジングル）は、ボイスの設定に関係なく鳴らす。「ボイス」で消すのは声だけ
    SoundManager::Get().Play(kBankEnso, se);
    if (fullCombo) {
        // 「フルコンボ！」の声は、クリア成功の文字のあと「フルコンボ」の文字が出る瞬間に合わせて鳴らす（UpdateResultVoice）
        resultVoice_ = perfect ? "dondafullcombo_c" : "fullcombo_c";   // 「ボイス」の設定に関係なく鳴らす
        resultVoiceClip_ = result_.Clip(clip);
        finishTimer_ = -1.0f;   // 文字が出るのが遅いので、リザルトへ行くのを少し遅らせる
        don_.SetNonLoopAnimation("full_combo", true);
    }
}

// フルコンボ・ドンダフルコンボの声: 文字の動き（action_result の 125 フレーム目）で「フルコンボ」の文字が出る瞬間に鳴らす
void EnsoScene::UpdateResultVoice() {
    if (!resultVoice_) return;
    constexpr int kTextFrame = 125;
    const bool shown = !resultVoiceClip_ || resultVoiceClip_->CurrentFrame() >= kTextFrame;
    if (!shown && finishTimer_ < 1.5f) return;
    SoundManager::Get().Play(kBankVoice, resultVoice_);
    resultVoice_ = nullptr;
}

// ===========================================================================
// 描画
// ===========================================================================
// 音符の横位置。判定枠から右へ、1小節分の時間でレーンの端に届く速さで流れる。
// 演奏オプションの「はやさ」の倍率で速くし、「音符位置調整」のぶん描く位置をずらす
float EnsoScene::NoteX(const Player& player, double time, double bpm, double scroll) const {
    const double measure = 240000.0 / std::max(1.0, bpm);
    const double speed = (kSpawnX - kJudgeX) / measure * scroll * double(player.options.SpeedValue());
    return float(kJudgeX + (time + player.drawOffset - clock_) * speed);
}

void EnsoScene::Draw() {
    ClearBackground(BLACK);
    if (!loaded_) {
        GameFont::Get().Draw("譜面を読み込めませんでした（面をたたくと曲選択にもどります）", 960.0f, 520.0f, 40.0f, RAYWHITE,
                             TextAlign::Center);
        return;
    }

    RenderDon();
    RenderTrainingTopBackground();

    bgBottom_.Draw();
    bgFever_.Draw();
    bgDai_.Draw();
    dancer_.Draw();
    feverEffect_.Draw();
    // 段位道場: 下の帯にお題の板と段位の札
    daniBg_.Draw();
    daniDetail_.Draw();
    daniPlate_.Draw();
    // 上の帯の部品は帯の外にはみ出さないように切る
    BeginScissorMode(0, 0, 1920, int(kLaneTop));
    if (training_) DrawTrainingTopBackground();
    else donBg_.Draw();
    donBgObj_.Draw();
    donEnso_.Draw();
    fukidashi_.Draw();
    EndScissorMode();

    for (const Player& player : players_) {
        player.gauge.Draw();
        player.lane.Draw();
        player.laneHit.Draw();
        DrawNotes(player);
        player.hitEffect.Draw();
        // 叩いて飛んでいく音符。遅れて叩くと判定枠より左（ミニ太鼓の板の上）から飛び立つので、板の裏から出てくるように、
        // 板（laneLeft）より先に描く。魂ゲージへ飛ぶ先には板がないので、見え方は変わらない
        for (const Player::Jump& jump : player.jumps) {
            if (jump.remain > 0.0f) jump.part.Draw();
        }
        player.laneLeft.Draw();
        player.taiko.Draw();
        player.course2.Draw();
        // スコアと加点の表示（4つを順に使う）。古いものから描き、いちばん新しい加点を上に重ねる。
        // 1つ目は scorePart（スコアの数字も入っている）
        for (int k = 0; k < kAddScoreCount; ++k) {
            const int slot = (player.nextAddScore + k) % kAddScoreCount;
            if (slot == 0 || size_t(slot) >= player.addScores.size()) player.scorePart.Draw();
            else player.addScores[size_t(slot)].Draw();
        }
        player.comboPart.Draw();
        player.plate.Draw();
        if (autoPlay) DrawAutoBadge(player);
        player.renda.Draw();
    }
    // 曲のあいだの襖（レーンの帯をふさぐ）
    daniBetween_.Draw();
    gogoEffect_.Draw();
    songInfo_.Draw();
    rendaEffect_.Draw();
    fusenPart_.Draw();
    kusudamaPart_.Draw();
    branchEffect_.Draw();
    result_.Draw();
    skipPart_.Draw();
    DrawTraining();

    if (isPaused_) {
        DrawPauseMenu();
    }
}

void EnsoScene::DrawNotes(const Player& player) {
    const float y = player.laneY + kNoteY;
    Lumen::BeginBatch();

    // 小節線
    if (bar_) {
        for (size_t i = 0; i < player.bars.size(); ++i) {
            const float x = NoteX(player, player.bars[i], player.barBpm[i], player.barScroll[i]);
            if (x < -100.0f || x > kSpawnX + 100.0f) continue;   // 音符と同じく、レーン左の板の裏まで流す
            Lumen::DrawClip(bar_, Translate(x, y));
        }
    }

    // 遠いものから描き、近い音符を上に重ねる。特訓モードで止めているあいだは、叩いた音符も譜面どおりに出す
    const bool review = training_ && trainingPaused_;
    // ドロン: 音符を描かない（小節線と、叩いたあと飛んでいく音符は出す）
    if (player.options.doron && !review) {
        Lumen::EndBatch();
        return;
    }

    // 見逃した音符は判定枠を過ぎてもそのまま流し、レーン左の板（あとで描く）の裏に消えるまで描く
    for (size_t i = player.notes.size(); i-- > 0;) {
        const Note& note = player.notes[i];
        if (!review && note.judged && !note.src.IsRoll() && !note.missed) continue;   // 叩いた音符は、叩いたその場ですぐ消える
        float x = NoteX(player, note.src.time, note.src.bpm, note.src.scroll);
        if (x > kSpawnX + 100.0f) continue;
        if (!review && note.src.IsBalloon() && note.src.time <= clock_) x = kJudgeX;   // 風船は判定枠で止まる
        const float end = note.src.IsRoll() ? NoteX(player, note.src.time + note.src.duration, note.src.bpm, note.src.scroll) : x;
        if (end < -200.0f) continue;
        DrawNote(player, note, x, y);
    }
    Lumen::EndBatch();
    if (review) DrawTrainingLane(player);
}

void EnsoScene::DrawNote(const Player& player, const Note& note, float x, float y) {
    auto found = sprites_.find(SpriteLabel(note.src.type));
    if (found == sprites_.end() || !found->second.clip) return;
    const NoteSprite& sprite = found->second;

    if (note.src.IsRoll() && sprite.body && sprite.tail) {
        // 連打: 胴を頭から終わりまで伸ばし、尻尾の中心を終わりの時刻の位置に置く
        //   ムービーの胴（onp/body）は幅 8 の図形を中で 9 倍した「中心から ±36」の帯で、
        //   頭の中心（0）から 72 までを覆うように置かれ、尻尾はその先（112）にある。
        //   胴を中心で伸ばすと頭より後ろにもはみ出すので、左端を頭の中心に固定したまま右へ伸ばす
        constexpr float kBodyHalfWidth = 36.0f;
        const float end = NoteX(player, note.src.time + note.src.duration, note.src.bpm, note.src.scroll);
        const Lumen::MovieClip* onp = sprite.clip->Find("onp");
        const Lumen::Matrix onpM = onp ? onp->PlacementMatrix() : Lumen::Matrix();
        const Lumen::Matrix bodyM = Lumen::Concat(onpM, sprite.body->PlacementMatrix());
        const Lumen::Matrix tailM = Lumen::Concat(onpM, sprite.tail->PlacementMatrix());
        const float bodyLeft = bodyM.x - kBodyHalfWidth * bodyM.a;    // 頭から見た胴の左端（ふつうは 0）
        const float bodyRight = bodyM.x + kBodyHalfWidth * bodyM.a;   // 胴の右端（尻尾がつながるところ）
        const float tailGap = tailM.x - bodyRight;                     // 胴の右端から尻尾の中心まで
        const float width = std::max(0.0f, (end - x) - tailGap - bodyLeft);
        Lumen::Matrix body = bodyM;
        body.a = width / (2.0f * kBodyHalfWidth);
        body.x = x + bodyLeft + width * 0.5f;
        body.y += y;
        if (width > 0.0f) Lumen::DrawClip(sprite.body, body);
        Lumen::Matrix tail = tailM;
        tail.x = x + bodyLeft + width + tailGap;
        tail.y += y;
        Lumen::DrawClip(sprite.tail, tail);
        // 頭は胴と尻尾を隠して描く
        const_cast<Lumen::MovieClip*>(sprite.body)->SetVisible(false);
        const_cast<Lumen::MovieClip*>(sprite.tail)->SetVisible(false);
        Lumen::DrawClip(sprite.clip, Translate(x, y));
        const_cast<Lumen::MovieClip*>(sprite.body)->SetVisible(true);
        const_cast<Lumen::MovieClip*>(sprite.tail)->SetVisible(true);
        return;
    }
    Lumen::DrawClip(sprite.clip, Translate(x, y));
}

// どんちゃん（don_enso の差し込み枠に描く）
//   どんちゃんの動きは 60fps のデータなので、1/60 秒の区切りが変わったときだけ描き直す（間のフレームは前の絵のまま）。
//   骨の計算と頂点の変形が重く（1回 約 1ms）、毎フレーム描くと演奏中の描く速さが大きく落ちる
void EnsoScene::RenderDon() {
    if (!don3d_.IsLoaded() || donTexture_.id == 0) return;
    const long long frame = static_cast<long long>(GetTime() * 60.0);
    if (frame == donRenderedFrame_) return;
    donRenderedFrame_ = frame;
    don_.Apply(don3d_);

    // どんちゃんの大きさと足の位置（調整する値）。大きさは 1.0 で以前のまま、足の位置は画面の y（上の帯の下の黒い線は 276）
    constexpr float kDonScale = 1.2f;
    constexpr float kDonFeetY = 274.0f;
    // 差し込み枠は画面に 0.63 倍で置かれ、中心が (248, 138)。1.0 倍のとき足は画面の y = 243 に来る（世界の座標で 0.017）
    constexpr float kFeetWorldY = 0.017f;
    constexpr float kPixelsPerUnit = 850.0f;   // 1.0 倍のとき、世界の 1 が画面の何 px か
    Camera3D camera{};
    camera.target = Vector3{0.0f, kFeetWorldY + (kDonFeetY - 138.0f) / (kPixelsPerUnit * kDonScale), 0.0f};
    camera.position = Vector3{0.0f, camera.target.y + 0.06f, 1.7f};
    camera.up = Vector3{0.0f, 1.0f, 0.0f};
    camera.fovy = 0.8f / kDonScale;
    camera.projection = CAMERA_ORTHOGRAPHIC;
    BeginTextureMode(donTexture_);
    ClearBackground(Color{0, 0, 0, 0});
    BeginMode3D(camera);
    don3d_.Draw(0, don3d_.Expression(), MatrixRotateY(30.0f * DEG2RAD));
    EndMode3D();
    EndTextureMode();
}

// 「_p1」「_p2」の付く動きの名前（くす玉は叩いている人の側の動きを使う）
static std::string DonSide(const char* name, int player) {
    return std::string(name) + (player == 1 ? "_p2" : "_p1");
}

// 繰り返す動きはその時の状態から決める（風船・くす玉 → ゴーゴータイム → 魂ゲージ満タン → ふつう）
// 曲のいまの BPM。いまの時刻（clock_）が入っている小節の BPM（曲が始まる前は最初の小節）。
// 特訓モードで曲の速さを変えているときは、その倍率をかける
double EnsoScene::CurrentBpm() const {
    if (players_.empty()) return 120.0;
    const std::vector<FumenMeasure>& measures = players_.front().fumen.measures;
    if (measures.empty()) return 120.0;
    auto next = std::upper_bound(measures.begin(), measures.end(), clock_,
                                 [](double time, const FumenMeasure& m) { return time < m.time; });
    const FumenMeasure& now = next == measures.begin() ? *next : *(next - 1);
    return now.bpm * double(training_ ? trainingTempo_ : 1.0f);
}

// どんちゃんの踊り（normal / sabi / full_gage）は 120 BPM に合わせて作られている（normal はちょうど 4 拍）。
// 曲のいまの BPM ÷ 120 の速さで流す。BPM が変わっても急に変わらないよう、ゆっくり寄せる。
// 風船・くす玉の連打や、叩いたときの動きは BPM に関係なくデータどおりの速さ
constexpr double kDonBaseBpm = 120.0;
constexpr float kDonRateMin = 0.5f;
constexpr float kDonRateMax = 3.0f;
constexpr float kDonRateSeconds = 0.3f;   // 速さが目標に寄る時間の目安

void EnsoScene::UpdateDonAnimation(float dt) {
    // ふつうは "normal"、ゴーゴータイムは "sabi"（lua の Don.SetLoopAnimation と同じ）
    std::string loop = "normal";
    if (!players_.empty() && players_.front().gogoNow) loop = "sabi";
    if (activeBalloon_ >= 0) loop = "balloon_loop";
    else if (activeKusudama_ >= 0) loop = DonSide("kusu_nobeat", balloonPlayer_);
    else if (fever_) loop = "full_gage";
    don_.SetLoopAnimation(loop, false);

    const bool dancing = loop == "normal" || loop == "sabi" || loop == "full_gage";
    const float target = dancing ? std::clamp(float(CurrentBpm() / kDonBaseBpm), kDonRateMin, kDonRateMax) : 1.0f;
    donRate_ += (target - donRate_) * std::min(1.0f, dt / kDonRateSeconds);
    don_.SetLoopRate(donRate_);
    don_.Update(dt);

    if (donSlotShowTimer_ > 0.0f) {
        donSlotShowTimer_ -= dt;
        if (donSlotShowTimer_ <= 0.0f) SetDonSlotHidden(false);
    }
    if (kusudamaTime_ >= 0.0f) {
        const float before = kusudamaTime_;
        kusudamaTime_ += dt;
        // 26 フレーム後に「連打」の文字（lua: tutorial_kusudama_Update）
        if (before < 26.0f / 60.0f && kusudamaTime_ >= 26.0f / 60.0f) {
            Goto(kusudamaPart_.Clip("main/rendas_text"), "init", true);
        }
    }
}

void EnsoScene::SetDonSlotHidden(bool hidden, float showAfter) {
    // don_enso はどんちゃんの差し込み枠だけのムービー
    if (Lumen::MovieClip* slot = donEnso_.Root()) slot->SetVisible(!hidden);
    donSlotShowTimer_ = hidden && showAfter > 0.0f ? showAfter : -1.0f;
}

// 風船: どんちゃんは balloon_loop を繰り返し、叩くたびに balloon_nobeat、割れたら balloon_success（lua: tutorial scene04）
// 風船のムービーにどんちゃんの枠があるので、そのあいだふだんの枠は隠す
void EnsoScene::StartBalloon(Player& player, int noteIndex) {
    activeBalloon_ = noteIndex;
    balloonPlayer_ = player.index;
    if (player.index == players_.front().index) SetDonSlotHidden(true);
    if (Lumen::MovieClip* root = fusenPart_.Root()) {
        root->SetVisible(true);
        if (Lumen::MovieClip* main = fusenPart_.Clip("main")) {
            main->SetVisible(true);
            Goto(main->Child("don"), players_.size() >= 2 ? (player.index == 0 ? "duet_player1" : "duet_player2") : "solo");
            main->GotoAndPlay("start");
            const Note& note = player.notes[size_t(noteIndex)];
            const int total = std::max(1, note.src.hits);
            const int remain = std::max(0, total - note.count);
            if (Lumen::MovieClip* fukidashi = main->Child("fukidashi")) {
                SetFusenDigits(fukidashi, remain);
            }
            if (Lumen::MovieClip* fusen = main->Child("fusen")) {
                fusen->GotoAndStop("geki_05");
            }
        }
    }
}

void EnsoScene::HitBalloon(Player& player) {
    if (activeBalloon_ < 0 || size_t(activeBalloon_) >= player.notes.size()) return;
    const Note& note = player.notes[size_t(activeBalloon_)];
    const int total = std::max(1, note.src.hits);
    const int remain = std::max(0, total - note.count);
    if (Lumen::MovieClip* main = fusenPart_.Clip("main")) {
        if (Lumen::MovieClip* fukidashi = main->Child("fukidashi")) {
            SetFusenDigits(fukidashi, remain);
            fukidashi->GotoAndPlay("geki_hit");
        }
        if (Lumen::MovieClip* fusen = main->Child("fusen")) {
            const float ratio = float(remain) / float(total);
            const char* label = ratio <= 0.2f ? "geki_01" : ratio <= 0.4f ? "geki_02" : ratio <= 0.6f ? "geki_03" : ratio <= 0.8f ? "geki_04" : "geki_05";
            fusen->GotoAndStop(label);
        }
    }
    if (player.index == players_.front().index) don_.SetNonLoopAnimation("balloon_nobeat", false);
}

void EnsoScene::BreakBalloon(Player& player) {
    if (Lumen::MovieClip* main = fusenPart_.Clip("main")) {
        main->GotoAndPlay("break");
        Schedule(fusenPart_.Root(), "", 1.2f, false, true);
    }
    // 割れた風船が虹をかけながら魂ゲージへ飛んでいく（onp_jump の geki。虹はマスクで少しずつ見せる画像）
    LaunchJump(player, "geki", 0.0f, kGekiJumpSeconds);
    if (VoiceOn(player)) SoundManager::Get().Play(kBankEnso, "balloon_success_c");
    if (player.index == players_.front().index) {
        don_.SetNonLoopAnimation("balloon_success", true);
        SetDonSlotHidden(true, 1.2f);   // 風船のムービーが消えたらふだんの枠に戻す
    }
    activeBalloon_ = -1;
}

void EnsoScene::MissBalloon(Player& player) {
    if (activeBalloon_ >= 0 && size_t(activeBalloon_) < player.notes.size()) {
        const Note& note = player.notes[size_t(activeBalloon_)];
        const int total = std::max(1, note.src.hits);
        const int remain = std::max(0, total - note.count);
        const float ratio = float(remain) / float(total);
        const char* missLabel = ratio <= 0.2f ? "geki01_miss" : ratio <= 0.4f ? "geki02_miss" : ratio <= 0.6f ? "geki_03_miss" : ratio <= 0.8f ? "geki04_miss" : "geki05_miss";
        if (Lumen::MovieClip* main = fusenPart_.Clip("main")) {
            if (Lumen::MovieClip* mf = main->Child("missfusen")) {
                mf->GotoAndPlay(missLabel);
            }
            main->GotoAndPlay("miss");
            Schedule(fusenPart_.Root(), "", 1.0f, false, true);
        }
        if (player.index == players_.front().index) {
            don_.SetNonLoopAnimation("balloon_failure", true);
            SetDonSlotHidden(true, 1.0f);
        }
    }
    activeBalloon_ = -1;
}

// くす玉（lua: tutorial_kusudama_start / tutorial_kusudama_Update と scene08 のどんちゃん）
//   始まり: main "start"、kusudama_hit "geki_05"、どんちゃん kusu_in → kusu_nobeat を繰り返す
//   叩く: 残りに合わせて kusudama_hit を geki_04 〜 geki_00 へ、どんちゃん kusu_loop
//   割れた: kusudama_hit を隠し kusudama_success_high "start"・main "success_high"、どんちゃん kusu_success02、65 フレーム後に消す
static const char* KusudamaGeki(int remain, int total) {
    if (remain <= 0) return "geki_00";
    const float ratio = float(remain) / float(std::max(1, total));
    return ratio <= 0.2f ? "geki_00" : ratio <= 0.4f ? "geki_01" : ratio <= 0.6f ? "geki_02" : ratio <= 0.8f ? "geki_03" : ratio < 1.0f ? "geki_04" : "geki_05";
}

void EnsoScene::StartKusudama(Player& player, int noteIndex) {
    activeKusudama_ = noteIndex;
    balloonPlayer_ = player.index;
    kusudamaTime_ = 0.0f;
    if (Lumen::MovieClip* root = kusudamaPart_.Root()) {
        root->SetVisible(true);
        if (Lumen::MovieClip* main = kusudamaPart_.Clip("main")) {
            main->SetVisible(true);
            main->GotoAndPlay("start");
            // 1人で遊ぶときは 2P のどんちゃんの枠を隠す（lua: tutorial_kusudama_init）
            const bool duet = players_.size() >= 2;
            for (const char* path : {"don_player2", "kusudama_success_high/don_player2", "kusudama_success_low/don_player2",
                                     "kusudama_miss/don_player2"}) {
                if (Lumen::MovieClip* clip = main->Find(path)) clip->SetVisible(duet);
            }
            const Note& note = player.notes[size_t(noteIndex)];
            const int total = std::max(1, note.src.hits);
            const int remain = std::max(0, total - note.count);
            if (Lumen::MovieClip* hit = main->Child("kusudama_hit")) {
                hit->SetVisible(true);
                hit->GotoAndPlay("geki_05");
            }
            if (Lumen::MovieClip* counter = main->Child("renda_counter")) {
                SetFusenDigits(counter, remain);
            }
        }
    }
    don_.SetNonLoopAnimation(DonSide("kusu_in", player.index), true);
    SetDonSlotHidden(true);
}

void EnsoScene::HitKusudama(Player& player) {
    if (activeKusudama_ < 0 || size_t(activeKusudama_) >= player.notes.size()) return;
    const Note& note = player.notes[size_t(activeKusudama_)];
    const int total = std::max(1, note.src.hits);
    const int remain = std::max(0, total - note.count);
    if (Lumen::MovieClip* main = kusudamaPart_.Clip("main")) {
        if (Lumen::MovieClip* hit = main->Child("kusudama_hit")) {
            const std::string label = KusudamaGeki(remain, total);
            if (label != KusudamaGeki(remain + 1, total)) hit->GotoAndPlay(label);
        }
        if (Lumen::MovieClip* counter = main->Child("renda_counter")) {
            SetFusenDigits(counter, remain);
        }
    }
    // くす玉の登場の動きが終わってから叩く動きにする
    if (!don_.IsPlayingNonLoop() || kusudamaTime_ > 19.0f / 60.0f) {
        don_.SetNonLoopAnimation(DonSide("kusu_loop", player.index), false);
    }
}

void EnsoScene::BreakKusudama(Player& player) {
    if (Lumen::MovieClip* main = kusudamaPart_.Clip("main")) {
        if (Lumen::MovieClip* hit = main->Child("kusudama_hit")) hit->SetVisible(false);
        Goto(main->Child("kusudama_success_high"), "start", true);
        main->GotoAndPlay("success_high");
        Schedule(kusudamaPart_.Root(), "", 65.0f / 60.0f, false, true);
    }
    if (VoiceOn(player)) SoundManager::Get().Play(kBankEnso, "kusudama_success");
    don_.SetNonLoopAnimation(DonSide("kusu_success02", player.index), true);
    SetDonSlotHidden(true, 49.0f / 60.0f);
    activeKusudama_ = -1;
    kusudamaTime_ = -1.0f;
}

void EnsoScene::MissKusudama(Player& player) {
    if (Lumen::MovieClip* main = kusudamaPart_.Clip("main")) {
        if (Lumen::MovieClip* hit = main->Child("kusudama_hit")) hit->SetVisible(false);
        Goto(main->Child("kusudama_miss"), "start", true);
        main->GotoAndPlay("miss");
        Schedule(kusudamaPart_.Root(), "", 65.0f / 60.0f, false, true);
    }
    don_.SetNonLoopAnimation(DonSide("kusu_failure", player.index), true);
    SetDonSlotHidden(true, 49.0f / 60.0f);
    activeKusudama_ = -1;
    kusudamaTime_ = -1.0f;
}

// ===========================================================================
// 特訓モード（F2）
// ===========================================================================
int EnsoScene::MeasureAt(double time) const {
    int index = 0;
    for (int i = 0; i < int(trainingMeasures_.size()); ++i) {
        if (trainingMeasures_[size_t(i)] <= time + 1.0) index = i;
    }
    return index;
}

double EnsoScene::Lag() const {
    // 聞こえるまでの遅れ（実時間）はテンポの分だけ譜面の時刻では伸び縮みする。曲の頭の遅れ（kSongDelay）は曲の中の時間
    return (kOutputLatency + double(offsetMs)) * double(trainingTempo_) + kSongDelay;
}

void EnsoScene::FadeToEnso(bool training, int measure) {
    if (LoadingScene::IsActive()) return;
    leaving_ = true;
    SoundManager::Get().PauseSong();
    SoundManager::Get().StopSlot(kTrainingMoveSlot);
    startTraining = training;
    startTrainingMeasure = measure;
    SceneManager::GetInstance().ChangeScene(
        std::make_unique<LoadingScene>([] { return std::unique_ptr<Scene>(std::make_unique<EnsoScene>()); }), true);
}

// 暗転してから、今の小節（曲の前なら最初の小節）で止めた特訓モードの画面に切り替える
void EnsoScene::EnterTraining() {
    if (training_ || finished_ || leaving_ || players_.empty()) return;
    FadeToEnso(true, songStarted_ ? MeasureAt(clock_) : 0);
}

void EnsoScene::PauseTraining() {
    trainingPaused_ = true;
    trainingCountIn_ = false;
    trainingBeats_.clear();
    SoundManager::Get().PauseSong();
    trainingRunEnd_ = clock_;
    trainingMeasure_ = MeasureAt(clock_);
    // 出ている演出は片付ける（止めているあいだは譜面を見せる）
    for (Player& player : players_) {
        if (Lumen::MovieClip* root = player.hitEffect.Root()) root->SetVisible(false);
        for (Player::Jump& jump : player.jumps) {
            jump.remain = 0.0f;
            if (Lumen::MovieClip* root = jump.part.Root()) root->SetVisible(false);
        }
        player.activeRoll = -1;
        UpdateRenda(player, false);
    }
    Goto(fukidashi_.Clip("main_1p"), "wait");
    for (Part* part : {&fusenPart_, &kusudamaPart_, &rendaEffect_}) {
        if (Lumen::MovieClip* root = part->Root()) root->SetVisible(false);
    }
    activeBalloon_ = activeKusudama_ = -1;
    kusudamaTime_ = -1.0f;
    SetDonSlotHidden(false);
    SoundManager::Get().Play(kBankTraining, "fumen");
}

// 選んだ小節の1小節前（最初の小節なら 2 秒前）から流す。選んだ小節より前の音符は判定しない
void EnsoScene::ResumeTraining() {
    SoundManager& sound = SoundManager::Get();
    if (!songStarted_) {
        // 特訓モードで始めた画面: 曲の読み込みが済むまでは始めない
        if (!sound.IsSongLoaded()) return;
        songStarted_ = true;
    }
    const double start = trainingMeasures_.empty() ? 0.0 : trainingMeasures_[size_t(trainingMeasure_)];
    double lead = trainingMeasure_ > 0 ? start - trainingMeasures_[size_t(trainingMeasure_ - 1)] : 2000.0;
    lead = std::clamp(lead, 1000.0, 4000.0);
    const double resume = start - lead;
    // 始める前の1小節は拍ごとにカウントの音を鳴らす
    trainingBeats_.clear();
    if (!trainingMeasureBpm_.empty()) {
        const double bpm = trainingMeasureBpm_[size_t(std::max(0, trainingMeasure_ - 1))];
        const double beat = 60000.0 / std::max(30.0, bpm);
        for (double t = start - beat; t >= resume - 1.0; t -= beat) trainingBeats_.insert(trainingBeats_.begin(), t);
    }

    // 成績と連打の数は、止めて演奏し直すたびに 0 から数え直す
    for (Player& player : players_) {
        for (Note& note : player.notes) {
            note.judged = note.src.time < start - 1.0;
            note.count = 0;
            note.brokeAt = -1.0;
        }
        player.first = 0;
        while (player.first < player.notes.size() && player.notes[player.first].judged) ++player.first;
        player.activeRoll = -1;
        player.combo = 0;
        player.good = player.ok = player.bad = player.rolls = 0;
        UpdateRenda(player, false);
    }
    trainingRunStart_ = start;
    trainingRunEnd_ = -1.0;
    // 途中の風船・くす玉は片付ける
    activeBalloon_ = activeKusudama_ = -1;
    kusudamaTime_ = -1.0f;
    for (Part* part : {&fusenPart_, &kusudamaPart_}) {
        if (Lumen::MovieClip* root = part->Root()) root->SetVisible(false);
    }
    SetDonSlotHidden(false);

    clock_ = resume;
    drift_ = 0.0;
    sound.SetSongSpeed(trainingTempo_);
    const double lag = Lag();
    if (resume + lag >= 0.0) {
        sound.SeekSong(float((resume + lag) / 1000.0));
        sound.ResumeSong();
    } else {
        // 曲の頭より前から: 曲の頭の時刻になるまで、音を止めたまま時刻だけ進める
        sound.SeekSong(0.0f);
        trainingCountIn_ = true;
    }
    trainingPaused_ = false;
    sound.StopSlot(kTrainingMoveSlot);
    trainingMoveSound_ = 0;
    trainingButtonFlash_[1] = 0.25f;
    sound.Play("se_common_v12a", "don_c");
}

void EnsoScene::SetTrainingTempo(float tempo) {
    tempo = std::clamp(std::round(tempo * 10.0f) / 10.0f, 0.5f, 1.5f);
    if (std::fabs(tempo - trainingTempo_) < 0.001f) return;
    trainingTempo_ = tempo;   // 曲に掛けるのは演奏を始めるとき
    SoundManager::Get().Play(kBankTraining, "option");
}

// 止めているあいだの操作。表示は選んだ小節が判定枠に来るように、なめらかに動かす
//   1P の太鼓: ふち左 早戻し（1小節前へ）、面 再生、ふち右 早送り（1小節先へ）
//   2P の太鼓（1人のとき）: ふち左 テンポ遅、面 メニュー（ポーズメニュー）、ふち右 テンポ速
//   キーボード: ←→（押し続けると続けて動く）、PageUp / PageDown 10小節、Home 最初の小節、↑↓ テンポ、Space 再生
void EnsoScene::UpdateTraining(float deltaTime) {
    SoundManager& sound = SoundManager::Get();
    // 特訓モードで始めた画面: 曲を読み込んで止めておく（再生を押したらすぐ流せるように）
    if (!songStarted_ && !songLoading_ && sound.IsSongPrepared(song_.SoundBank())) {
        sound.PlaySong(song_.SoundBank());
        sound.PauseSong();
        songLoading_ = true;
    }

    const int count = int(trainingMeasures_.size());
    const bool solo = players_.size() == 1;
    int move = 0;
    if (TaikoInput::IsKaLeft(0) || TaikoInput::ActionRepeat(TaikoInput::Action::P1KaLeft)) move = -1;
    if (TaikoInput::IsKaRight(0) || TaikoInput::ActionRepeat(TaikoInput::Action::P1KaRight)) move = 1;
    if (TaikoInput::KeyPressed(KEY_PAGE_UP)) move = -10;
    if (TaikoInput::KeyPressed(KEY_PAGE_DOWN)) move = 10;
    if (TaikoInput::KeyPressed(KEY_HOME)) move = -count;
    if (move != 0 && count > 0) {
        trainingButtonFlash_[move < 0 ? 0 : 2] = 0.2f;
        trainingMeasure_ = std::clamp(trainingMeasure_ + move, 0, count - 1);
    }
    if (TaikoInput::IsDon(0) || TaikoInput::KeyPressed(KEY_SPACE)) {
        ResumeTraining();
        return;
    }
    if ((solo && TaikoInput::IsKaLeft(1)) || TaikoInput::KeyPressed(KEY_DOWN) || IsKeyPressedRepeat(KEY_DOWN)) {
        trainingButtonFlash_[3] = 0.2f;
        SetTrainingTempo(trainingTempo_ - 0.1f);
    }
    if ((solo && TaikoInput::IsKaRight(1)) || TaikoInput::KeyPressed(KEY_UP) || IsKeyPressedRepeat(KEY_UP)) {
        trainingButtonFlash_[5] = 0.2f;
        SetTrainingTempo(trainingTempo_ + 0.1f);
    }
    if (solo && TaikoInput::IsDon(1)) {
        trainingButtonFlash_[4] = 0.2f;
        TogglePause();
        return;
    }

    // 選んだ小節が判定枠に来るまで譜面を流す。流しているあいだは早送り・早戻しの音
    const double target = count > 0 ? trainingMeasures_[size_t(trainingMeasure_)] : 0.0;
    clock_ += (target - clock_) * std::min(1.0, double(deltaTime) * 12.0);
    if (std::fabs(target - clock_) < 0.5) clock_ = target;
    const int direction = std::fabs(target - clock_) < 20.0 ? 0 : target > clock_ ? 1 : -1;
    if (direction != trainingMoveSound_) {
        if (direction == 0) sound.StopSlot(kTrainingMoveSlot);
        else sound.PlaySlot(kBankTraining, direction > 0 ? "fast" : "return", kTrainingMoveSlot);
        trainingMoveSound_ = direction;
    }
}

// 特訓モードの画面の部品（本家に部品のムービーがないので、ブログの画面写真にならって描く）
namespace {

constexpr float kTrainingPanelTop = kBottomTop + 60.0f; // 成績と太鼓の操作（止めているとき）

// 特訓モードの素材（Data\x64\lumen\998_tokkun）。初めて描くときに読み込む
constexpr float kTrainingScale = 1.5f;   // 下の背景（1280x368）と太鼓の絵は 1.5 倍で置く
constexpr float kTrainingBarLeft = 499.5f;                  // 進み具合の溝（背景の絵の 333〜1246）
constexpr float kTrainingBarRight = 1869.0f;
constexpr float kTrainingBarY = kBottomTop + 25.5f;         // 溝の上端（背景の絵の 17）
constexpr float kTrainingBarHeight = 27.0f;
constexpr float kTrainingDrumLeft = 853.0f;                 // 太鼓の面の中心の x（1P / 2P）
constexpr float kTrainingDrumRight = 1553.0f;
constexpr float kTrainingDrumTop = 568.0f;                  // 太鼓の絵を置く上端
constexpr float kDrumImageLeft = 250.0f;                    // 絵の中の太鼓の中心（左・右）
constexpr float kDrumImageRight = 702.0f;
constexpr float kDrumImageHalf = 473.0f;                    // 絵を左右の太鼓に分ける x
constexpr float kDrumHitShift = 452.0f;                     // 叩いた光（1P の太鼓の位置）を 2P の太鼓へ動かす幅

struct TrainingTextures {
    Texture2D down{}, drum{}, drumWait{}, red{}, white{}, gogo{}, measure{}, bigNumber{}, smallNumber{};
    Texture2D hit[4]{};   // 0: 左のふち 1: 右のふち 2: 左の面 3: 右の面
};

Texture2D LoadTrainingTexture(const std::string& name) {
    Texture2D texture = LoadTexture(("Data/x64/lumen/998_tokkun/" + name).c_str());
    if (texture.id != 0) SetTextureFilter(texture, TEXTURE_FILTER_BILINEAR);
    return texture;
}

// 止めているときの太鼓: 「演奏中」の文字と一時停止の絵を消した面にする（楕円の中を面の色で塗り、真ん中の線だけ引き直す）
Texture2D MakeWaitingDrum() {
    Image image = LoadImage("Data/x64/lumen/998_tokkun/BigTaiko.png");
    if (image.data == nullptr) return Texture2D{};
    ImageFormat(&image, PIXELFORMAT_UNCOMPRESSED_R8G8B8A8);
    Color* pixels = static_cast<Color*>(image.data);
    const Color face{255, 245, 220, 255};
    const Color line{238, 226, 198, 255};
    for (float center : {245.0f, 245.0f + kDrumHitShift}) {
        for (int y = 90; y <= 220; ++y) {
            for (int x = int(center) - 120; x <= int(center) + 120; ++x) {
                const float dx = (float(x) - center) / 115.5f, dy = (float(y) - 155.0f) / 60.5f;
                if (dx * dx + dy * dy > 1.0f) continue;
                if (x < 0 || x >= image.width) continue;
                Color& pixel = pixels[y * image.width + x];
                pixel = (x == int(center) - 1 || x == int(center)) ? line : face;
            }
        }
    }
    Texture2D texture = LoadTextureFromImage(image);
    UnloadImage(image);
    if (texture.id != 0) SetTextureFilter(texture, TEXTURE_FILTER_BILINEAR);
    return texture;
}

const TrainingTextures& TrainingArt() {
    static TrainingTextures art;
    static bool loaded = false;
    if (!loaded) {
        loaded = true;
        art.down = LoadTrainingTexture("Down.png");
        art.drum = LoadTrainingTexture("BigTaiko.png");
        art.drumWait = MakeWaitingDrum();
        art.red = LoadTrainingTexture("ProgressBar_Red.png");
        art.white = LoadTrainingTexture("ProgressBar_White.png");
        art.gogo = LoadTrainingTexture("GoGoPoint.png");
        art.measure = LoadTrainingTexture("Speed_Measure.png");
        art.bigNumber = LoadTrainingTexture("BigNumber.png");
        art.smallNumber = LoadTrainingTexture("SmallNumber.png");
        for (int i = 0; i < 4; ++i) art.hit[i] = LoadTrainingTexture("DrumHit/" + std::to_string(i) + ".png");
    }
    return art;
}

// 絵の数字（0〜9 が横に並んだ素材）を左から並べる。置いた右端の x を返す
float DrawTrainingNumber(const Texture2D& texture, int value, float x, float centerY, float scale) {
    if (texture.id == 0) return x;
    const std::string text = std::to_string(std::max(0, value));
    const float cell = float(texture.width) / 10.0f;
    for (char digit : text) {
        const Rectangle source{cell * float(digit - '0'), 0.0f, cell, float(texture.height)};
        const Rectangle dest{x, centerY - float(texture.height) * scale * 0.5f, cell * scale, float(texture.height) * scale};
        DrawTexturePro(texture, source, dest, Vector2{0.0f, 0.0f}, 0.0f, WHITE);
        x += cell * scale;
    }
    return x;
}

// 素材の一部（札や斜線）を置く
void DrawTrainingPiece(const Texture2D& texture, Rectangle source, float x, float centerY, float scale) {
    if (texture.id == 0) return;
    const Rectangle dest{x, centerY - source.height * scale * 0.5f, source.width * scale, source.height * scale};
    DrawTexturePro(texture, source, dest, Vector2{0.0f, 0.0f}, 0.0f, WHITE);
}

// ボタン: 上に名前の札、下に絵
enum class TrainingIcon { Rewind, Play, Forward, Slow, Menu, Fast };

void DrawTrainingButton(Vector2 c, TrainingIcon icon, float flash) {
    GameFont& font = GameFont::Get();
    const bool big = icon == TrainingIcon::Play || icon == TrainingIcon::Menu;
    const float scale = 1.0f + 0.08f * std::min(1.0f, flash / 0.2f);
    const float w = (big ? 124.0f : 118.0f) * scale;
    const float h = (big ? 160.0f : 154.0f) * scale;
    const Rectangle box{c.x - w * 0.5f, c.y - h * 0.5f, w, h};
    const Color labelColor = big ? Color{250, 172, 160, 255} : Color{196, 236, 240, 255};
    const Color border = big ? Color{220, 90, 80, 255} : Color{120, 170, 180, 255};
    DrawRectangleRounded(Rectangle{box.x - 5.0f, box.y - 5.0f, box.width + 10.0f, box.height + 10.0f}, 0.12f, 8, border);
    DrawRectangleRounded(box, 0.1f, 8, Color{252, 252, 250, 255});
    const float labelH = 40.0f * scale;
    DrawRectangleRounded(Rectangle{box.x, box.y, box.width, labelH}, 0.3f, 8, labelColor);
    static const char* const kLabels[] = {"早戻し", "再生", "早送り", "テンポ", "メニュー", "テンポ"};
    font.Draw(kLabels[int(icon)], c.x, box.y + 6.0f * scale, 28.0f * scale, Color{40, 40, 40, 255}, TextAlign::Center);

    const Vector2 m{c.x, box.y + labelH + (box.height - labelH) * 0.5f};   // 絵の中心
    const float s = 26.0f * scale;
    const Color ink{30, 30, 30, 255};
    switch (icon) {
    case TrainingIcon::Rewind:
        DrawTriangle(Vector2{m.x - 2.0f * s, m.y}, Vector2{m.x, m.y + s}, Vector2{m.x, m.y - s}, ink);
        DrawTriangle(Vector2{m.x, m.y}, Vector2{m.x + 2.0f * s * 0.9f, m.y + s}, Vector2{m.x + 2.0f * s * 0.9f, m.y - s}, ink);
        break;
    case TrainingIcon::Forward:
        DrawTriangle(Vector2{m.x + 2.0f * s, m.y}, Vector2{m.x, m.y - s}, Vector2{m.x, m.y + s}, ink);
        DrawTriangle(Vector2{m.x, m.y}, Vector2{m.x - 2.0f * s * 0.9f, m.y - s}, Vector2{m.x - 2.0f * s * 0.9f, m.y + s}, ink);
        break;
    case TrainingIcon::Play:
        DrawTriangle(Vector2{m.x + 1.4f * s, m.y}, Vector2{m.x - s, m.y - 1.5f * s}, Vector2{m.x - s, m.y + 1.5f * s}, ink);
        break;
    case TrainingIcon::Menu:
        for (int i = 0; i < 4; ++i) {
            DrawRectangleRec(Rectangle{m.x - 1.3f * s, m.y - 1.2f * s + float(i) * 0.75f * s, 2.6f * s, 0.34f * s}, ink);
        }
        break;
    case TrainingIcon::Slow:
    case TrainingIcon::Fast:
        font.Draw(icon == TrainingIcon::Slow ? "遅" : "速", m.x, m.y - 44.0f * scale, 86.0f * scale, ink, TextAlign::Center);
        break;
    }
    if (flash > 0.0f) {
        DrawRectangleRounded(box, 0.1f, 8, Color{255, 255, 255, (unsigned char)(160.0f * std::min(1.0f, flash / 0.2f))});
    }
}


// 吹き出し（連打音符の上の打数）
void DrawCountBubble(float x, float bottom, const char* text, Color bg, Color fg) {
    GameFont& font = GameFont::Get();
    const float w = std::max(64.0f, font.Measure(text, 34.0f).x + 26.0f);
    const float h = 46.0f;
    const Rectangle box{x - w * 0.5f, bottom - 14.0f - h, w, h};
    DrawTriangle(Vector2{x - 11.0f, box.y + h - 2.0f}, Vector2{x, bottom + 2.0f}, Vector2{x + 11.0f, box.y + h - 2.0f}, Color{30, 30, 30, 255});
    DrawRectangleRounded(Rectangle{box.x - 4.0f, box.y - 4.0f, box.width + 8.0f, box.height + 8.0f}, 0.3f, 8, Color{30, 30, 30, 255});
    DrawRectangleRounded(box, 0.3f, 8, bg);
    DrawTriangle(Vector2{x - 7.0f, box.y + h - 1.0f}, Vector2{x, bottom - 3.0f}, Vector2{x + 7.0f, box.y + h - 1.0f}, bg);
    font.Draw(text, x, box.y + 5.0f, 34.0f, fg, TextAlign::Center, 3.0f, Color{30, 30, 30, 255});
}

} // namespace

// 止めているあいだの譜面の上: 小節線の右下に小節の番号、直前の演奏で叩いた連打の数の吹き出し
void EnsoScene::DrawTrainingLane(const Player& player) {
    GameFont& font = GameFont::Get();
    for (size_t i = 0; i < trainingMeasures_.size(); ++i) {
        const float x = NoteX(player, trainingMeasures_[i], trainingMeasureBpm_[i], trainingMeasureScroll_[i]);
        if (x < kJudgeX - 260.0f || x > 1920.0f) continue;
        font.Draw(TextFormat("%d", int(i) + 1), x + 8.0f, player.laneY + kNoteY + 62.0f, 30.0f, RAYWHITE, TextAlign::Left, 3.0f);
    }
    if (trainingRunEnd_ < 0.0) return;
    for (const Note& note : player.notes) {
        if (!(note.src.IsRoll() || note.src.IsBalloon())) continue;
        if (note.src.time < trainingRunStart_ - 1.0 || note.src.time > trainingRunEnd_) continue;
        const float x = NoteX(player, note.src.time, note.src.bpm, note.src.scroll);
        if (x < -100.0f || x > 1980.0f) continue;
        const float bottom = player.laneY + 26.0f;
        if (note.src.IsRoll()) {
            DrawCountBubble(x, bottom, TextFormat("%d", note.count), Color{255, 232, 60, 255}, Color{30, 30, 30, 255});
            continue;
        }
        // 風船: 青 割れなかった / 黄 割れた。くす玉: 青 割れなかった / 白 ギリギリ割れた / 黄 はやく割れた
        const int total = std::max(1, note.src.hits);
        Color fg{80, 150, 255, 255};
        if (note.brokeAt >= 0.0) {
            const bool late = note.src.type == NoteType::Kusudama && note.brokeAt > note.src.time + note.src.duration * 0.75;
            fg = late ? RAYWHITE : Color{255, 214, 40, 255};
        }
        DrawCountBubble(x, bottom, TextFormat("%d/%d", std::min(note.count, total), total), Color{60, 60, 70, 255}, fg);
    }
}

namespace {

// 色相を回すシェーダー（色の向きだけを YIQ で回し、明るさは変えない）
constexpr const char* kTrainingHueFragment = R"(#version 330
in vec2 fragTexCoord;
in vec4 fragColor;
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float hue;
out vec4 finalColor;
void main() {
    vec4 c = texture(texture0, fragTexCoord) * fragColor * colDiffuse;
    float y = dot(c.rgb, vec3(0.299, 0.587, 0.114));
    float i = dot(c.rgb, vec3(0.596, -0.274, -0.322));
    float q = dot(c.rgb, vec3(0.211, -0.523, 0.312));
    float cs = cos(hue), sn = sin(hue);
    float i2 = i * cs - q * sn;
    float q2 = i * sn + q * cs;
    vec3 rgb = vec3(y + 0.956 * i2 + 0.621 * q2, y - 0.272 * i2 - 0.647 * q2, y - 1.106 * i2 + 1.703 * q2);
    finalColor = vec4(clamp(rgb, 0.0, 1.0), c.a);
}
)";

} // namespace

// 特訓モードの上の背景: ふだんの背景（橙）を、下の背景の紫に合わせて色相を回して描く
//   背景を一度テクスチャに描いてから、色相を回すシェーダーで画面に写す（シェーダーが使えなければ、ふだんのまま描く）
void EnsoScene::RenderTrainingTopBackground() {
    if (!training_) return;
    if (!trainingTopTried_) {
        trainingTopTried_ = true;
        trainingTopTexture_ = LoadRenderTexture(1920, int(kLaneTop));
        trainingHue_ = LoadShaderFromMemory(nullptr, kTrainingHueFragment);
        trainingHueLocation_ = GetShaderLocation(trainingHue_, "hue");
    }
    if (trainingTopTexture_.id == 0) return;
    BeginTextureMode(trainingTopTexture_);
    ClearBackground(Color{0, 0, 0, 0});
    donBg_.Draw();
    EndTextureMode();
}

void EnsoScene::DrawTrainingTopBackground() {
    constexpr float kHue = 1.8f;   // ラジアン（橙 → 紫）
    RenderTexture2D& target = trainingTopTexture_;
    Shader& shader = trainingHue_;
    if (target.id == 0 || shader.id <= 0 || trainingHueLocation_ < 0) {
        donBg_.Draw();
        return;
    }
    SetShaderValue(shader, trainingHueLocation_, &kHue, SHADER_UNIFORM_FLOAT);
    BeginShaderMode(shader);
    DrawTextureRec(target.texture, Rectangle{0.0f, 0.0f, float(target.texture.width), -float(target.texture.height)}, Vector2{0.0f, 0.0f}, WHITE);
    EndShaderMode();
}

void EnsoScene::DrawTraining() {
    if (!training_ || players_.empty()) return;
    GameFont& font = GameFont::Get();
    const Player& player = players_.front();

    // 右上の「特訓モード」
    {
        const Rectangle tag{1600.0f, 150.0f, 280.0f, 62.0f};
        DrawRectangleRounded(Rectangle{tag.x - 4.0f, tag.y - 4.0f, tag.width + 8.0f, tag.height + 8.0f}, 0.5f, 8, RAYWHITE);
        DrawRectangleRounded(tag, 0.5f, 8, Color{214, 30, 40, 255});
        font.Draw("特訓モード", tag.x + tag.width * 0.5f, tag.y + 10.0f, 40.0f, RAYWHITE, TextAlign::Center, 4.0f,
                  Color{120, 10, 20, 255});
    }

    // 下の背景（演奏を始めても変えない）。左の黒い板と、右の紫の模様、進み具合の溝
    const TrainingTextures& art = TrainingArt();
    if (art.down.id != 0) {
        DrawTexturePro(art.down, Rectangle{0.0f, 0.0f, float(art.down.width), float(art.down.height)},
                       Rectangle{0.0f, kBottomTop, float(art.down.width) * kTrainingScale, float(art.down.height) * kTrainingScale},
                       Vector2{0.0f, 0.0f}, 0.0f, WHITE);
    } else {
        DrawRectangle(0, int(kBottomTop), 1920, int(1080.0f - kBottomTop), Color{8, 8, 12, 255});
    }

    // 曲テンポ・小節数・進み具合（ゴーゴータイムの開始位置の印つき）
    const int count = int(trainingMeasures_.size());
    const int current = trainingPaused_ ? trainingMeasure_ : MeasureAt(clock_);
    {
        const float centerY = kBottomTop + 30.0f;
        const float tag = 1.3f;
        DrawTrainingPiece(art.measure, Rectangle{0.0f, 0.0f, 64.0f, 50.0f}, 22.0f, centerY, tag);   // 曲テンポ
        // 曲テンポは倍率（1.0 など）で出す。数字の素材に小数点がないので、点は丸で描く
        const int tenths = int(std::lround(double(trainingTempo_) * 10.0));
        float tempoX = DrawTrainingNumber(art.bigNumber, tenths / 10, 112.0f, centerY, 1.1f);
        const Vector2 dot{tempoX + 4.0f, centerY + 13.0f};
        DrawCircleV(dot, 5.5f, Color{40, 40, 40, 255});
        DrawCircleV(dot, 3.5f, RAYWHITE);
        tempoX = DrawTrainingNumber(art.bigNumber, tenths % 10, tempoX + 10.0f, centerY, 1.1f);
        font.Draw("倍", tempoX + 2.0f, centerY - 15.0f, 30.0f, RAYWHITE, TextAlign::Left, 3.0f, Color{40, 40, 40, 255});
        DrawTrainingPiece(art.measure, Rectangle{143.0f, 0.0f, 66.0f, 50.0f}, 212.0f, centerY, tag);   // 小節
        float x = DrawTrainingNumber(art.bigNumber, count > 0 ? current + 1 : 0, 306.0f, centerY, 1.1f);
        DrawTrainingPiece(art.measure, Rectangle{266.0f, 0.0f, 32.0f, 50.0f}, x, centerY, 1.0f);
        x += 32.0f;
        DrawTrainingNumber(art.smallNumber, count, x, centerY + 2.0f, 1.0f);
    }
    if (count > 0) {
        const float left = kTrainingBarLeft, right = kTrainingBarRight, top = kTrainingBarY, height = kTrainingBarHeight;
        const double begin = trainingMeasures_.front();
        const double end = std::max(lastTime_, trainingMeasures_.back()) + 1.0;
        auto toX = [&](double t) { return left + float(std::clamp((t - begin) / (end - begin), 0.0, 1.0)) * (right - left); };
        // 溝は背景の絵にある。演奏した分を赤、レーンに見えている範囲を白で重ねる
        auto fill = [&](const Texture2D& texture, float from, float to) {
            if (texture.id == 0 || to <= from) return;
            const float span = right - left;
            const Rectangle source{(from - left) / span * float(texture.width), 0.0f, (to - from) / span * float(texture.width),
                                   float(texture.height)};
            DrawTexturePro(texture, source, Rectangle{from, top, to - from, height}, Vector2{0.0f, 0.0f}, 0.0f, WHITE);
        };
        const float now = toX(clock_);
        fill(art.red, left, now);
        const size_t m = size_t(std::clamp(MeasureAt(clock_), 0, count - 1));
        const double visible = 240000.0 / std::max(1.0, trainingMeasureBpm_[m]) * double((1920.0f - kJudgeX) / (kSpawnX - kJudgeX)) /
                               std::max(0.1, trainingMeasureScroll_[m]);
        fill(art.white, now, toX(clock_ + visible));
        if (art.gogo.id != 0) {
            for (const auto& change : player.gogo) {
                if (!change.second) continue;
                DrawTexture(art.gogo, int(toX(change.first)) - art.gogo.width / 2, int(top + height) - 12, WHITE);
            }
        }
    }

    // ---- 直前の演奏の成績（止めているあいだも、演奏中も出す） ----
    const int judged = player.good + player.ok + player.bad;
    auto percent = [&](int n) { return judged > 0 ? n * 100 / judged : 0; };
    const Color orange{255, 176, 30, 255};
    font.Draw("たたけた率", 28.0f, kTrainingPanelTop + 58.0f, 48.0f, RAYWHITE, TextAlign::Left, 3.0f);
    font.Draw(TextFormat("%d%%", percent(player.good + player.ok)), 476.0f, kTrainingPanelTop + 52.0f, 56.0f, orange,
              TextAlign::Right, 3.0f);
    struct Row {
        const char* name;
        int value;
        Color color;
    };
    const Row rows[] = {{"良", player.good, Color{255, 150, 40, 255}}, {"可", player.ok, RAYWHITE}, {"不可", player.bad, Color{80, 150, 255, 255}}};
    for (int i = 0; i < 3; ++i) {
        const float y = kTrainingPanelTop + 144.0f + 57.0f * float(i);
        DrawRectangleRounded(Rectangle{20.0f, y, 460.0f, 52.0f}, 0.5f, 8, Color{44, 44, 54, 255});
        font.Draw(rows[i].name, 96.0f, y + 6.0f, 38.0f, rows[i].color, TextAlign::Center, 3.0f);
        font.Draw(TextFormat("%d", rows[i].value), 300.0f, y + 6.0f, 38.0f, RAYWHITE, TextAlign::Right, 3.0f);
        font.Draw(TextFormat("%d%%", percent(rows[i].value)), 466.0f, y + 6.0f, 38.0f, orange, TextAlign::Right, 3.0f);
    }
    const float rendaY = kTrainingPanelTop + 340.0f;
    DrawRectangleRounded(Rectangle{20.0f, rendaY, 300.0f, 52.0f}, 0.7f, 8, Color{120, 110, 24, 255});
    font.Draw("連打", 76.0f, rendaY + 6.0f, 38.0f, Color{255, 230, 60, 255}, TextAlign::Center, 3.0f);
    font.Draw(TextFormat("%d", player.rolls), 270.0f, rendaY + 6.0f, 38.0f, RAYWHITE, TextAlign::Right, 3.0f);
    font.Draw(TextFormat("%s：特訓モードをやめる", TaikoInput::KeyName(TaikoInput::BoundKey(TaikoInput::Action::Training, 0)).c_str()),
              28.0f, 1080.0f - 50.0f, 26.0f, Color{170, 170, 180, 255});

    // ---- 太鼓（1P / 2P）。演奏中は「演奏中」と一時停止の絵、止めているときは操作のボタンを出す ----
    const float drumLeftX = kTrainingDrumLeft - kDrumImageLeft * kTrainingScale;     // 絵の左端（1P の太鼓）
    const float drumRightX = kTrainingDrumRight - kDrumImageRight * kTrainingScale;  // 絵の左端（2P の太鼓）
    const Texture2D& drum = trainingPaused_ && art.drumWait.id != 0 ? art.drumWait : art.drum;
    if (drum.id != 0) {
        const float h = float(drum.height);
        DrawTexturePro(drum, Rectangle{0.0f, 0.0f, kDrumImageHalf, h},
                       Rectangle{drumLeftX, kTrainingDrumTop, kDrumImageHalf * kTrainingScale, h * kTrainingScale}, Vector2{0.0f, 0.0f}, 0.0f,
                       WHITE);
        DrawTexturePro(drum, Rectangle{kDrumImageHalf, 0.0f, float(drum.width) - kDrumImageHalf, h},
                       Rectangle{drumRightX + kDrumImageHalf * kTrainingScale, kTrainingDrumTop,
                                 (float(drum.width) - kDrumImageHalf) * kTrainingScale, h * kTrainingScale},
                       Vector2{0.0f, 0.0f}, 0.0f, WHITE);
        // 絵は胴の途中で切れているので、いちばん下の数行を画面の下まで引き伸ばして続ける
        const float bottom = kTrainingDrumTop + h * kTrainingScale;
        if (bottom < 1080.0f) {
            constexpr float kStrip = 3.0f;
            DrawTexturePro(drum, Rectangle{0.0f, h - kStrip - 1.0f, kDrumImageHalf, kStrip},
                           Rectangle{drumLeftX, bottom - 1.0f, kDrumImageHalf * kTrainingScale, 1080.0f - bottom + 2.0f}, Vector2{0.0f, 0.0f},
                           0.0f, WHITE);
            DrawTexturePro(drum, Rectangle{kDrumImageHalf, h - kStrip - 1.0f, float(drum.width) - kDrumImageHalf, kStrip},
                           Rectangle{drumRightX + kDrumImageHalf * kTrainingScale, bottom - 1.0f,
                                     (float(drum.width) - kDrumImageHalf) * kTrainingScale, 1080.0f - bottom + 2.0f},
                           Vector2{0.0f, 0.0f}, 0.0f, WHITE);
        }
    }
    // 叩いた面・ふちが光る（左のふち・右のふち・左の面・右の面の順の素材）
    static constexpr int kHitSprite[4] = {0, 2, 3, 1};   // TaikoInput::Pad の順（左ふち・左面・右面・右ふち）→ 素材の番号
    for (int p = 0; p < 2; ++p) {
        const float x = p == 0 ? drumLeftX : drumLeftX + kDrumHitShift * kTrainingScale;
        for (int pad = 0; pad < 4; ++pad) {
            const float flash = trainingHitFlash_[p][pad];
            const Texture2D& hit = art.hit[kHitSprite[pad]];
            if (flash <= 0.0f || hit.id == 0) continue;
            DrawTexturePro(hit, Rectangle{0.0f, 0.0f, float(hit.width), float(hit.height)},
                           Rectangle{x, kTrainingDrumTop, float(hit.width) * kTrainingScale, float(hit.height) * kTrainingScale},
                           Vector2{0.0f, 0.0f}, 0.0f, Color{255, 255, 255, (unsigned char)(255.0f * std::min(1.0f, flash / 0.08f))});
        }
    }
    if (!trainingPaused_) return;

    // 止めているとき: 1P の太鼓は 早戻し・再生・早送り、2P の太鼓は テンポ・メニュー
    const float buttonY = 765.0f, buttonBottomY = 884.0f;
    DrawTrainingButton(Vector2{kTrainingDrumLeft - 237.0f, buttonY}, TrainingIcon::Rewind, trainingButtonFlash_[0]);
    DrawTrainingButton(Vector2{kTrainingDrumLeft + 235.0f, buttonY}, TrainingIcon::Forward, trainingButtonFlash_[2]);
    DrawTrainingButton(Vector2{kTrainingDrumLeft, buttonBottomY}, TrainingIcon::Play, trainingButtonFlash_[1]);
    DrawTrainingButton(Vector2{kTrainingDrumRight - 237.0f, buttonY}, TrainingIcon::Slow, trainingButtonFlash_[3]);
    DrawTrainingButton(Vector2{kTrainingDrumRight + 237.0f, buttonY}, TrainingIcon::Fast, trainingButtonFlash_[5]);
    DrawTrainingButton(Vector2{kTrainingDrumRight, buttonBottomY}, TrainingIcon::Menu, trainingButtonFlash_[4]);
}

void EnsoScene::TogglePause() {
    if (finished_) return;
    isPaused_ = !isPaused_;
    if (isPaused_) {
        SoundManager::Get().PauseSong();
        pauseSelected_ = 0;
        if (Lumen::MovieClip* root = pauseMenu_.Root()) {
            root->SetVisible(true);
            root->GotoAndPlay("start");
            if (Lumen::MovieClip* main = pauseMenu_.Clip("main")) main->GotoAndStop("normal");
            LayoutPauseMenu();
        }
        SoundManager::Get().Play("se_common_v12a", "katsu_c");
    } else {
        // 曲の前の待ちのあいだは、読み込んで止めてある曲を流さない（流し始めは UpdateClock が決める）
        if (songStarted_ && !trainingCountIn_ && !(training_ && trainingPaused_)) SoundManager::Get().ResumeSong();
        if (Lumen::MovieClip* root = pauseMenu_.Root()) root->SetVisible(false);
    }
}

void EnsoScene::UpdatePauseMenu() {
    if (TaikoInput::IsBackPressed()) {
        TogglePause();
        return;
    }
    // ポーズメニュー: 再開する / 最初から / 選曲画面に戻る（1P・2P の太鼓、↑↓←→・Enter・Space）
    if (TaikoInput::AnyKaLeft() || TaikoInput::KeyPressed(KEY_LEFT) || TaikoInput::KeyPressed(KEY_UP)) {
        pauseSelected_ = (pauseSelected_ + 2) % 3;
        SoundManager::Get().Play("se_common_v12a", "katsu_c");
    } else if (TaikoInput::AnyKaRight() || TaikoInput::KeyPressed(KEY_RIGHT) || TaikoInput::KeyPressed(KEY_DOWN)) {
        pauseSelected_ = (pauseSelected_ + 1) % 3;
        SoundManager::Get().Play("se_common_v12a", "katsu_c");
    }

    LayoutPauseMenu();

    if (TaikoInput::AnyDon() || TaikoInput::KeyPressed(KEY_ENTER) || TaikoInput::KeyPressed(KEY_SPACE)) {
        SoundManager::Get().Play("se_common_v12a", "don_c");
        if (pauseSelected_ == 0) {
            TogglePause();
        } else if (pauseSelected_ == 1) {
            // 最初から（暗転してから）。特訓モードのやり直しは、最初の小節で止めた特訓モードから
            isPaused_ = false;
            SoundManager::Get().StopAll();
            if (dani_) {
                // 段位道場は1曲目から（成績も最初から）
                PlayDataManager& pd = PlayDataManager::Get();
                DaniRun& run = pd.Dani();
                const DaniRun fresh{true, run.level};
                run = fresh;
                pd.SetSelectedSong(daniCourse_->songs[0].uniqueId, "dani");
                pd.SetSelectedCourse(players_.front().index, daniCourse_->songs[0].course);
            }
            FadeToEnso(training_, 0);
        } else if (pauseSelected_ == 2) {
            // 選曲画面（段位道場は段位選択）に戻る（暗転してから）
            isPaused_ = false;
            leaving_ = true;
            SoundManager::Get().StopAll();
            if (dani_) {
                PlayDataManager::Get().Dani().active = false;
                SceneManager::GetInstance().ChangeScene(
                    std::make_unique<LoadingScene>([] { return std::unique_ptr<Scene>(std::make_unique<DaniSelectScene>()); }), true);
            } else {
                SceneManager::GetInstance().ChangeScene(std::make_unique<LoadingScene>(LoadingScene::Next::SongSelect, true), true);
            }
        }
    }
}

// ポーズメニュー（lumen/enso/pause/pause_menu）の並び
//   元のムービーの "normal" は4枚（演奏をつづける・はじめからやりなおす・「曲をえらぶ」にもどる・「モードをえらぶ」にもどる）を
//   x = -540 / -180 / 180 / 540 に並べ、選んでいる枠（menu_select）はゲーム側が選んだ札の位置へ動かす作り。
//   モード選択はこの移植にないので3枚にし、同じ間隔（360）で中央にそろえる
void EnsoScene::LayoutPauseMenu() {
    Lumen::MovieClip* main = pauseMenu_.Clip("main");
    if (!main) return;
    static const char* const kLabels[] = {"continue", "retry", "song_select"};
    static const char* const kTexts[] = {"pause_continue", "pause_retry", "pause_song_select"};
    constexpr float kSpacing = 360.0f;
    if (Lumen::MovieClip* title = main->Child("title_mc")) title->SetText("text_title", "pause_menu");
    for (int i = 0; i < 4; ++i) {
        Lumen::MovieClip* card = main->Child("menu" + std::to_string(i));
        if (!card) continue;
        card->SetVisible(i < 3);
        if (i >= 3) continue;
        Goto(card, kLabels[i]);
        card->SetText("text_mc", "text_menu", kTexts[i]);
        const Vector2 pos = card->Position();
        card->SetPosition({float(i - 1) * kSpacing, pos.y});
    }
    if (Lumen::MovieClip* select = main->Child("menu_select")) {
        Goto(select, kLabels[pauseSelected_]);
        select->SetText("text_mc", "text_menu", kTexts[pauseSelected_]);
        const Vector2 pos = select->Position();
        select->SetPosition({float(pauseSelected_ - 1) * kSpacing, pos.y});
    }
}

void EnsoScene::DrawPauseMenu() {
    DrawRectangle(0, 0, 1920, 1080, Color{0, 0, 0, 160});
    pauseMenu_.Draw();
}

// スコアランク（lua: ResultMain の scoreRank。50万点から 10万点ごと、95万点・100万点で極）
static int ScoreRank(int score) {
    static const int kBorders[] = {500000, 600000, 700000, 800000, 900000, 950000, 1000000};
    int rank = 0;
    for (int border : kBorders) {
        if (score >= border) ++rank;
    }
    return rank;
}

void EnsoScene::StoreResults() {
    PlayDataManager& pd = PlayDataManager::Get();
    pd.Result(0) = PlayDataManager::EnsoResult();
    pd.Result(1) = PlayDataManager::EnsoResult();
    for (const Player& p : players_) {
        PlayDataManager::EnsoResult& r = pd.Result(p.index);
        const bool clear = p.hp >= p.fumen.hpClear;
        const bool fullCombo = clear && p.bad == 0 && !p.notes.empty();
        const bool perfect = fullCombo && p.ok == 0;
        r.valid = true;
        r.score = p.score;
        r.good = p.good;
        r.ok = p.ok;
        r.bad = p.bad;
        r.drumroll = p.rolls;
        r.maxCombo = p.maxCombo;
        r.gauge = p.fumen.hpMax > 0 ? std::clamp(p.hp * 50 / p.fumen.hpMax, 0, 50) : 0;
        r.resultType = perfect ? 3 : fullCombo ? 2 : clear ? 1 : 0;
        r.crown = r.resultType;
        r.scoreRank = ScoreRank(p.score);
        r.course = p.course;
        // 自己ベストと王冠・スコアランクを記録する（オートと、演奏スキップで途中で終えたぶんは残さない）
        const std::string owner = PlayRecords::Owner(p.index);
        const ChartRecord* best = PlayRecords::Get().Find(owner, song_.RecordId(), p.course);
        r.hiscore = best ? best->score : 0;
        // サンプルの譜面（TJA のない曲）は記録しない
        if (!autoUsed && !skipped_ && !song_.sample) PlayRecords::Get().Add(owner, song_.RecordId(), p.course, ChartRecord{r.score, r.crown, r.scoreRank});
    }
}

// ===========================================================================
// 段位道場
// ===========================================================================
void EnsoScene::SetupDani() {
    PlayDataManager& pd = PlayDataManager::Get();
    DaniRun& run = pd.Dani();
    SoundManager::Get().Preload(kBankDaniPlay);
    // 襖が開くときに曲名を切り替えても止まらないよう、3曲の曲名の文字を先に用意しておく
    for (const DaniSong& ds : daniCourse_->songs) {
        if (const SongInfo* info = SongDatabase::Get().FindSong(ds.uniqueId)) {
            GameFont::Get().Preload(WordList::Get().Text("song_" + info->id).c_str());
        }
    }

    // 3曲の音符の数（最初の曲で数える）。魂ゲージの重みと、お題に届くかの見込みに使う
    if (run.songIndex == 0) {
        run.totalNotes = 0;
        for (int i = 0; i < kDaniSongCount; ++i) {
            const DaniSong& ds = daniCourse_->songs[size_t(i)];
            const SongInfo* info = SongDatabase::Get().FindSong(ds.uniqueId);
            Fumen fumen;
            int count = 0;
            if (info && LoadTja(info->tjaPath, ds.course, fumen)) {
                for (const FumenMeasure& m : fumen.measures) {
                    for (const FumenNote& n : m.notes[0]) count += n.IsHit() ? 1 : 0;
                }
            }
            run.notes[size_t(i)] = count;
            run.totalNotes += count;
        }
    }
    // 後の曲の変換を始めておく（曲のあいだで待たないように）
    for (int i = run.songIndex + 1; i < kDaniSongCount; ++i) {
        if (const SongInfo* info = SongDatabase::Get().FindSong(daniCourse_->songs[size_t(i)].uniqueId)) {
            SoundManager::Get().PrepareSong(info->SoundBank());
        }
    }

    // 下の帯（背景・お題の板・段位の札）
    daniBg_.Load(std::string(kDaniDir) + "dani_enso/dani_enso", {0.0f, 0.0f});
    daniPlate_.Load(std::string(kDaniDir) + "dani_enso/dani_enso_dani", {0.0f, 0.0f});
    Goto(daniPlate_.Clip("main/dani_mc"), DaniLabel(daniCourse_->level));
    daniDetail_.Load(std::string(kDaniDir) + "dani_enso/dani_enso_detail", kDaniDetailPos);
    if (daniDetail_.stage) daniDetail_.stage->SetTextFace(FontFace::Large);
    for (int i = 0; i < kDaniExamCount; ++i) {
        const DaniExam& exam = daniCourse_->exams[size_t(i)];
        Lumen::MovieClip* gage = daniDetail_.Clip("main/gage" + std::to_string(i + 1));
        if (!gage) continue;
        if (exam.type == DaniExamType::None) {
            gage->GotoAndStop("none");
            continue;
        }
        gage->GotoAndStop(exam.total ? "all" : "01");
        if (Lumen::MovieClip* c = gage->Find("txt_theme_name")) c->SetText("tx_detail_label", DaniExamTextKey(exam.type));
        const int s = exam.total ? 0 : run.songIndex;
        const std::string border = std::to_string(exam.red[size_t(s)]) + (exam.LessThan() ? " 未満" : " 以上");
        Lumen::MovieClip* body = gage->Find(exam.total ? "score_all_mc" : "score_01_mc");
        if (Lumen::MovieClip* c = Sub(body, "score_border_tx")) c->SetText("tx_border", border);
        if (!exam.total && body) {
            body->GotoAndStop(kDaniSongLabels[run.songIndex]);
            // 前の曲の小さい棒は、遊び終えた曲のぶんだけ
            for (int k = 0; k < 2; ++k) {
                if (Lumen::MovieClip* small = body->Find("score_gauge_s" + std::to_string(k + 1) + "_mc")) small->SetVisible(k < run.songIndex);
            }
        }
    }

    // 襖: 閉じたところから始め、曲名を見せてから開く
    daniBetween_.Load(std::string(kDaniDir) + "dani_enso/dani_enso_between", {0.0f, kLaneTop});
    if (daniBetween_.stage) daniBetween_.stage->SetTextFace(FontFace::Large);
    if (Lumen::MovieClip* names = daniBetween_.Clip("main/next_song_name")) {
        names->SetText("text_kanban_title_song", "song_" + song_.id);
        names->SetText("text_song_title_sub", "song_sub_" + song_.id);
    }
    Goto(daniBetween_.Clip("main"), "stay", true);   // 開いて曲名が出たら、曲の時刻まで止めて待つ（UpdateDani）
    clock_ = -(kLeadIn + kDaniLeadIn);
    UpdateDaniExams();
}

DaniSongResult EnsoScene::DaniCurrent() const {
    const Player& p = players_.front();
    DaniSongResult r;
    r.good = p.good;
    r.ok = p.ok;
    r.bad = p.bad;
    r.combo = p.maxCombo;
    r.roll = p.rolls;
    r.score = p.score - PlayDataManager::Get().Dani().score;
    r.hit = p.good + p.ok + p.rolls;   // たたけた数（良・可と連打）
    return r;
}

// 赤合格に届かなくなったか。songEnd: この曲を終えた（1曲ごとのお題が決まる） runEnd: 3曲を終えた（通しのお題が決まる）
bool EnsoScene::DaniExamLost(const DaniExam& exam, bool songEnd, bool runEnd) const {
    if (exam.type == DaniExamType::None) return false;
    const DaniRun& run = PlayDataManager::Get().Dani();
    const int s = exam.total ? 0 : run.songIndex;
    const int red = exam.red[size_t(s)];
    const int value = DaniExamValue(exam, run, run.songIndex);
    if (exam.LessThan()) return red > 0 && value >= red;   // 可・不可は「未満」なので、超えたら終わり
    if (exam.total ? runEnd : songEnd) return value < red;
    // 残りの音符を全部良で叩いても届かない（良の数・コンボ）
    const Player& p = players_.front();
    int remaining = 0;
    for (size_t i = p.first; i < p.notes.size(); ++i) remaining += (!p.notes[i].judged && p.notes[i].src.IsHit()) ? 1 : 0;
    if (exam.total) {
        for (int i = run.songIndex + 1; i < kDaniSongCount; ++i) remaining += run.notes[size_t(i)];
    }
    if (exam.type == DaniExamType::Good) return value + remaining < red;
    if (exam.type == DaniExamType::Combo) return std::max(value, p.combo + remaining) < red;
    return false;
}

// お題の棒と数（演奏中は lua がないので、段位リザルトの lua: DaniResultDetailBase の GaugeColorChange にならう）
//   以上: 棒は赤合格までの進み。0: empty 1〜50: up_50 51〜95: up_80 96〜99: up_95 100: up_100 金合格: max
//   未満: 棒は 100 から減り、数は赤合格までの残り（基準 − 値）。金合格の線より上: down_100 30〜: up_80 1〜29: down_80
//         残り 1: fail_soon 0: fail（達成失敗）
void EnsoScene::SetDaniBar(Lumen::MovieClip* bar, Lumen::MovieClip* num, const DaniExam& exam, int value, int s, bool lost,
                           std::string& shown, int& shownNumber) {
    const int red = std::max(1, exam.red[size_t(s)]);
    const int gold = exam.gold[size_t(s)];
    const bool down = exam.LessThan();
    int percent = 0;
    int shownValue = value;
    std::string state;
    if (down) {
        percent = std::clamp(100 - value * 100 / red, 0, 100);
        shownValue = std::max(0, red - value);
        const int goldLine = 100 - gold * 100 / red;   // これより上なら金合格の範囲
        if (lost || value >= red) state = "fail";
        else if (shownValue <= 1) state = "fail_soon";
        else if (percent > goldLine) state = "down_100";
        else if (percent >= 30) state = "up_80";
        else state = "down_80";
    } else {
        percent = std::clamp(int(int64_t(value) * 100 / red), 0, 100);
        if (lost) state = "fail";
        else if (gold >= red && value >= gold) state = "max";
        else if (value >= red) state = "up_100";
        else if (percent >= 96) state = "up_95";
        else if (percent >= 51) state = "up_80";
        else if (percent >= 1) state = "up_50";
        else state = "empty";
    }
    const bool restate = state != shown;   // 状態のラベルが変わると数字の枠が置き直されるので、数字も入れ直す
    if (restate) {
        shown = state;
        Goto(bar, state, true);
        Goto(num, state, true);
    }
    // 棒の長さ（以上は赤合格までの進み、未満は残り）
    if (Lumen::MovieClip* type = Sub(bar, "score_gauge_bar_type_mc")) {
        type->GotoAndStop(down ? "type_down" : "type_up");
        Goto(type->Child(down ? "score_gauge_bar_down_mc" : "score_gauge_bar_up_mc"), "gauge_" + std::to_string(percent));
    }
    // 数（表と裏と光の3枚）。桁の枠は左から digit7 … digit1 と並んでいるので、棒の左端（digit7）から左詰めで入れる。
    // 変わったときは数字を縮めて戻す（コンボの数字と同じ。数字の各ラベルの 10 フレームの動き）
    shownValue = std::clamp(shownValue, 0, 9999999);
    if (shownValue == shownNumber && !restate) return;
    const bool bump = shownNumber >= 0 && shownValue != shownNumber;
    shownNumber = shownValue;
    const std::string digits = std::to_string(shownValue);
    for (const char* layer : {"score_back_mc", "score_front_mc", "score_add_mc"}) {
        Lumen::MovieClip* clip = Sub(num, layer);
        if (!clip) continue;
        for (int d = 7; d >= 1; --d) {
            const size_t index = size_t(7 - d);
            if (index < digits.size()) Goto(clip->Child("digit" + std::to_string(d)), "num" + std::string(1, digits[index]), bump);
            else Goto(clip->Child("digit" + std::to_string(d)), "none");
        }
    }
}

void EnsoScene::UpdateDaniExams() {
    DaniRun& run = PlayDataManager::Get().Dani();
    for (int i = 0; i < kDaniExamCount; ++i) {
        const DaniExam& exam = daniCourse_->exams[size_t(i)];
        if (exam.type == DaniExamType::None) continue;
        Lumen::MovieClip* gage = daniDetail_.Clip("main/gage" + std::to_string(i + 1));
        Lumen::MovieClip* body = Sub(gage, exam.total ? "score_all_mc" : "score_01_mc");
        if (!body) continue;
        const int value = DaniExamValue(exam, run, run.songIndex);
        const bool lost = DaniExamLost(exam, false, false);
        SetDaniBar(body->Find("score_gauge_bar_mc"), body->Find("score_gauge_num_mc"), exam, value,
                   exam.total ? 0 : run.songIndex, lost, daniShown_[i][0], daniShownNumber_[i][0]);
        if (exam.total) continue;
        // 前の曲の成績
        for (int k = 0; k < std::min(run.songIndex, 2); ++k) {
            Lumen::MovieClip* small = body->Find("score_gauge_s" + std::to_string(k + 1) + "_mc");
            if (!small) continue;
            const int past = run.songs[size_t(k)].Value(exam.type);
            SetDaniBar(small->Find("score_gauge_bar_mc"), small->Find("score_gauge_num_mc"), exam, past, k,
                       DaniExamGrade(exam, past, k) == 0, daniShown_[i][k + 1], daniShownNumber_[i][k + 1]);
        }
    }
}

// 右上の曲名・ジャンルの板・「N曲目 / 3」を、daniCourse_ の songIndex 曲目のものにする。
// play: 板とジャンル名と「N曲目」を入れ替わりで出す動き（song_info の loop）を頭から流す（襖が開いたとき）
void EnsoScene::ShowDaniSongInfo(int songIndex, bool play) {
    if (!daniCourse_ || songIndex < 0 || songIndex >= kDaniSongCount) return;
    // ジャンルの板と「N曲目」は、movie の loop には任せず、UpdateDaniSongInfo で同じ場所に交互にフェードして出す
    SetSongNumber(songIndex + 1, kDaniSongCount);
    daniInfoTime_ = 0.0f;
    daniInfoRun_ = play;
    daniInfoGenreAlpha_ = play ? 0.0f : 1.0f;
    daniInfoNumberAlpha_ = 0.0f;
    if (const SongInfo* info = SongDatabase::Get().FindSong(daniCourse_->songs[size_t(songIndex)].uniqueId)) {
        if (Lumen::MovieClip* c = songInfo_.Clip("text_song_title_mc")) {
            c->SetText("song_name", "song_" + info->id);
            c->SetVisible(true);
        }
        if (Lumen::MovieClip* plate = songInfo_.Clip("genre")) {
            Goto(plate, SongDatabase::GenrePlateLabel(info->genreNo));
            daniInfoTint_ = SongDatabase::GenrePlateTint(info->genreNo);
            plate->SetTint({daniInfoTint_[0], daniInfoTint_[1], daniInfoTint_[2], daniInfoGenreAlpha_});
            plate->SetVisible(true);
        }
        if (Lumen::MovieClip* c = songInfo_.Clip("genre_name_mc")) {
            c->SetText("genre_name", SongDatabase::GenreTextKey(info->genreNo));
            c->SetTint({1.0f, 1.0f, 1.0f, daniInfoGenreAlpha_});
            c->SetVisible(true);
        }
    }
}

// 曲名の下の同じ場所に、ジャンルの板と「N曲目」「N曲」を交互に、フェードアウト → フェードインで出す
void EnsoScene::UpdateDaniSongInfo(float dt) {
    if (!daniInfoRun_) return;
    daniInfoTime_ += dt;
    constexpr float kFade = 0.25f, kHold = 2.0f;
    constexpr float kNumberOut = kFade + kHold;              // 「N曲目」が消え始める
    constexpr float kGenreIn = kNumberOut + kFade;           // ジャンルの板が出始める
    constexpr float kGenreOut = kGenreIn + kFade + kHold;    // ジャンルの板が消え始める
    constexpr float kCycle = kGenreOut + kFade;
    const float t = std::fmod(daniInfoTime_, kCycle);
    auto ramp = [](float v) { return std::clamp(v / kFade, 0.0f, 1.0f); };
    daniInfoNumberAlpha_ = t < kNumberOut ? ramp(t) : t < kGenreIn ? 1.0f - ramp(t - kNumberOut) : 0.0f;
    daniInfoGenreAlpha_ = t < kGenreIn ? 0.0f : t < kGenreOut ? ramp(t - kGenreIn) : 1.0f - ramp(t - kGenreOut);
    // movie 側で「N曲目」の板が見えている時間（loop の途中）と、ジャンルの板が見えている時間（loop の頭）が分かれているので、
    // どちらも見えていないときに止める時間を切り替える
    const bool numberPhase = t < kGenreIn;
    if (numberPhase != daniInfoNumberPhase_ && (numberPhase ? daniInfoGenreAlpha_ : daniInfoNumberAlpha_) <= 0.0f) {
        daniInfoNumberPhase_ = numberPhase;
        if (Lumen::MovieClip* root = songInfo_.Root()) root->GotoAndStop(numberPhase ? kInfoNumberFrame : kInfoGenreFrame);
    }
    if (Lumen::MovieClip* plate = songInfo_.Clip("genre")) {
        plate->SetTint({daniInfoTint_[0], daniInfoTint_[1], daniInfoTint_[2], daniInfoGenreAlpha_});
    }
    if (Lumen::MovieClip* c = songInfo_.Clip("genre_name_mc")) c->SetTint({1.0f, 1.0f, 1.0f, daniInfoGenreAlpha_});
    // 「N曲目」「N曲」の板は song_info の song_number（元の素材）を、同じ場所でフェードさせる
    if (Lumen::MovieClip* c = songInfo_.Clip("song_number")) {
        c->SetTint({1.0f, 1.0f, 1.0f, daniInfoNumberAlpha_});
        c->SetVisible(daniInfoNumberAlpha_ > 0.0f);
    }
}

// 「N曲目」「N曲」の文字を入れる（song_info の song_number）
void EnsoScene::SetSongNumber(int number, int total) {
    // 数字と「曲目」「曲」のあいだに半角スペースを入れる（数字を全角にするなら、数字を全角の数字にする）
    WordList::Get().Set("enso_song_current", std::to_string(number) + " 曲目");
    WordList::Get().Set("enso_song_total", std::to_string(total) + " 曲");
    if (Lumen::MovieClip* c = songInfo_.Clip("song_number")) {
        c->SetText("text_song_count", "enso_song_current");
        c->SetText("text_song_max", "enso_song_total");
    }
}

void EnsoScene::UpdateDani(float dt) {
    PlayDataManager& pd = PlayDataManager::Get();
    DaniRun& run = pd.Dani();
    Player& player = players_.front();

    // 襖: 開く音、開ききったら隠す
    if (Lumen::MovieClip* main = daniBetween_.Clip("main")) {
        // 曲名を出したまま、曲の時刻まで待つ
        if (daniPhase_ == DaniPhase::Play && main->CurrentFrame() >= kDaniTitleFrame && main->CurrentFrame() < main->LabelFrame("end")) {
            if (clock_ < -(kLeadIn + kDaniAfterTitle)) main->Stop();
            else main->Play();
        }
        const int frame = main->CurrentFrame();
        if (daniPhase_ == DaniPhase::Play && !daniOpened_ && frame >= main->LabelFrame("open")) {
            daniOpened_ = true;
            SoundManager::Get().Play(kBankDaniPlay, "fusuma_open");
            ShowDaniSongInfo(run.songIndex, true);   // 襖が開いたら、曲名・ジャンル・「N曲目」をこの曲のものにして、入れ替わりの動きを始める
        }
        if (daniPhase_ == DaniPhase::Play && daniOpened_ && frame >= main->LabelFrame("end")) {
            main->Stop();
            if (Lumen::MovieClip* root = daniBetween_.Root()) root->SetVisible(false);
        }
        // 閉じきったら次の曲の画面へ
        if (daniPhase_ == DaniPhase::Closing && !daniSwitched_ && frame >= main->LabelFrame("stay")) {
            main->Stop();
            daniSwitched_ = true;
            leaving_ = true;
            ++run.songIndex;
            const DaniSong& next = daniCourse_->songs[size_t(run.songIndex)];
            pd.SetSelectedSong(next.uniqueId, "dani");
            pd.SetSelectedCourse(player.index, next.course);
            SceneManager::GetInstance().ChangeScene(std::make_unique<EnsoScene>());
            return;
        }
    }

    // 成績とお題
    if (daniPhase_ == DaniPhase::Play) {
        run.songs[size_t(run.songIndex)] = DaniCurrent();
        run.combo = player.combo;
        if (!finished_) {
            for (const DaniExam& exam : daniCourse_->exams) {
                if (DaniExamLost(exam, false, false)) {
                    DaniFail();
                    break;
                }
            }
        }
    }
    UpdateDaniExams();

    // 魂ゲージ（50 目盛り）と、合格ライン・満タンの演出
    const int lamps = std::clamp(int(run.gauge * 50.0 + 1e-6), 0, 50);
    if (lamps != daniGaugeShown_) {
        daniGaugeShown_ = lamps;
        Goto(player.gauge.Clip("gauge_mc/gauge_lamp_mc"), "gage_" + std::to_string(lamps));
    }
    const int state = run.gauge >= 1.0 ? 2 : run.gauge * 100.0 + 1e-6 >= daniCourse_->gaugeRed ? 1 : 0;
    if (state != daniGaugeState_) {
        const int before = daniGaugeState_;
        daniGaugeState_ = state;
        const char* label = state == 2 ? "fever_start" : state == 1 ? (before == 2 ? "fever_end_clear" : "clear")
                                                                    : (before == 2 ? "fever_end_not_clear" : "not_clear");
        Goto(player.gauge.Clip("gauge_mc/tamashii_mc"), label, before >= 0);
        Goto(player.gauge.Clip("gauge_mc/gauge_lamp_mc/lamp"), state >= 1 ? "lamp_clear" : "lamp_1p");
    }

    if (daniPhase_ == DaniPhase::Ending) {
        daniTimer_ += dt;
        if (daniTimer_ >= kResultSeconds && !leaving_) DaniLeave();
    }
}

// お題に届かなくなった: 演奏を止め、不合格でリザルトへ
void EnsoScene::DaniFail() {
    DaniRun& run = PlayDataManager::Get().Dani();
    run.songs[size_t(run.songIndex)] = DaniCurrent();
    run.failed = true;
    run.arrival = run.songIndex + 1;
    finished_ = true;
    daniPhase_ = DaniPhase::Ending;
    daniTimer_ = 0.0f;
    SoundManager::Get().StopPreview(0.5f);
    SoundManager::Get().Play(kBankDaniPlay, "disqualify");
    if (Lumen::MovieClip* mc = result_.Clip("fail_dani_mc")) {
        mc->SetVisible(true);
        mc->GotoAndPlay("start");
    }
}

// 曲の終わり（最後の音符のあと、曲が終わった）
void EnsoScene::DaniSongEnd() {
    PlayDataManager& pd = PlayDataManager::Get();
    DaniRun& run = pd.Dani();
    const Player& player = players_.front();
    finished_ = true;
    run.songs[size_t(run.songIndex)] = DaniCurrent();
    run.combo = player.combo;
    run.score = player.score;
    run.arrival = run.songIndex + 1;
    const bool last = run.songIndex >= kDaniSongCount - 1;

    // 1曲ごとのお題はここで、通しのお題は最後の曲で決まる
    for (const DaniExam& exam : daniCourse_->exams) {
        if (DaniExamLost(exam, true, last)) {
            DaniFail();
            return;
        }
    }

    if (!last) {
        // 次の曲へ: 襖を閉じて次の曲名を出す
        daniPhase_ = DaniPhase::Closing;
        const DaniSong& next = daniCourse_->songs[size_t(run.songIndex + 1)];
        if (const SongInfo* info = SongDatabase::Get().FindSong(next.uniqueId)) {
            if (Lumen::MovieClip* names = daniBetween_.Clip("main/next_song_name")) {
                names->SetText("text_kanban_title_song", "song_" + info->id);
                names->SetText("text_song_title_sub", "song_sub_" + info->id);
            }
        }
        if (Lumen::MovieClip* root = daniBetween_.Root()) root->SetVisible(true);
        Goto(daniBetween_.Clip("main"), "start", true);
        SoundManager::Get().Play(kBankDaniPlay, "fusuma_close");
        return;
    }

    // 3曲を終えた: 合格（赤・金）か
    bool red = run.gauge * 100.0 + 1e-6 >= daniCourse_->gaugeRed;
    bool gold = run.gauge * 100.0 + 1e-6 >= daniCourse_->gaugeGold;
    bool fullCombo = true, perfect = true;
    for (int i = 0; i < kDaniSongCount; ++i) {
        fullCombo = fullCombo && run.songs[size_t(i)].bad == 0;
        perfect = perfect && run.songs[size_t(i)].bad == 0 && run.songs[size_t(i)].ok == 0;
    }
    for (const DaniExam& exam : daniCourse_->exams) {
        if (exam.type == DaniExamType::None) continue;
        for (int s = 0; s < (exam.total ? 1 : kDaniSongCount); ++s) {
            const int grade = DaniExamGrade(exam, DaniExamValue(exam, run, s), s);
            red = red && grade >= 1;
            gold = gold && grade >= 2;
        }
    }
    gold = gold && red;
    daniPhase_ = DaniPhase::Ending;
    daniTimer_ = 0.0f;
    const char* clip = !red ? "fail_dani_mc" : perfect ? "dondafull_dani_mc" : fullCombo ? "fullcombo_dani_mc" : "success_dani_mc";
    if (Lumen::MovieClip* mc = result_.Clip(clip)) {
        mc->SetVisible(true);
        mc->GotoAndPlay("start");
    }
    SoundManager::Get().Play(kBankDaniPlay, !red ? "notclear" : gold ? "clear_upper" : "clear_normal");
    if (red && fullCombo) SoundManager::Get().Play(kBankVoice, perfect ? "dondafullcombo_c" : "fullcombo_c");
    if (fullCombo) don_.SetNonLoopAnimation("full_combo", true);
}

void EnsoScene::DaniLeave() {
    leaving_ = true;
    SceneManager::GetInstance().ChangeScene(
        std::make_unique<LoadingScene>([] { return std::unique_ptr<Scene>(std::make_unique<DaniResultScene>()); }), true);
}

