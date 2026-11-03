#pragma once
#include <map>
#include <memory>
#include <string>
#include <vector>

#include "DonModel.hpp"
#include "Fumen.hpp"
#include "LumenPlayer.hpp"
#include "PlayData.hpp"
#include "Scene.hpp"
#include "SongDatabase.hpp"
#include "raylib.h"

// 演奏ゲーム画面
// 元のゲームでは C++ 側が組み立てている画面なので lua はない。lumen/000_default/enso_normal/enso の部品
// （レーン、音符、太鼓、スコア、コンボ、魂ゲージ、背景など）を、それぞれの舞台の大きさから決まる帯に並べる:
//   上 276px: どんちゃんの背景（donbg）、中 264px: レーン（lane / lane_left）、下 540px: 背景と踊り子
// 音符は onp_all の onp0 を種類ごとに1つ用意し、流れる位置に何度も描く。
// 演出の動きは遊び方説明（lua/attract/tutorial.lua）が同じ部品を動かしている手順に合わせる
//   （スコアは加点の表示から 32 フレーム後に跳ねて増える、風船・くす玉のどんちゃんの動きなど）。
// 終わったら黒いフェード（loading_kuro_result）でリザルト画面（ResultScene）へ。
// 演奏オプション（はやさ・ドロン・あべこべ・ランダム・演奏スキップ・音符位置調整・ボイス・音色）を使う。
// 移植していないもの: 譜面分岐（普通譜面で遊ぶ）、2人のときの踊り子・背景の切り替え、演奏中のオプションのアイコン
class EnsoScene : public Scene {
public:
    // 確認用: 音符をちょうどの時刻に自動で叩く（main の --auto 1）
    static inline bool autoPlay = false;
    // この演奏（段位道場は挑戦ぜんぶ）のあいだに、一度でもオートにした（記録を残さない。リザルトに知らせる）
    static inline bool autoUsed = false;
    // 判定のずらし（ms）。正にすると音符が遅れて届く（main の --offset）
    static inline float offsetMs = 0.0f;
    // 確認用: 曲の再生位置に合わせず、フレームの経過時間だけで進める（main の --step 1。画面の保存で止まっても進みがずれない）
    static inline bool fixedStep = false;
    // 確認用: 時刻（音符の位置）の進みのむらをログに出す（main の --fps 1）
    static inline bool logClock = false;
    // 演奏ゲームの画面があるか（main が演奏中だけ描く速さの上限を外すのに使う）
    static bool IsActive() { return activeCount_ > 0; }
    EnsoScene() { ++activeCount_; }
    ~EnsoScene() override { --activeCount_; }

    void Initialize() override;
    void Update(float deltaTime) override;
    void Draw() override;
    void Finalize() override;

private:
    enum class Judge { Good, Ok, Bad };

    // 画面の部品（1つの Lumen ムービー）
    struct Part {
        std::unique_ptr<Lumen::Stage> stage;
        Vector2 pos{0.0f, 0.0f};
        bool Load(const std::string& path, Vector2 position);
        Lumen::MovieClip* Clip(const std::string& path) const;
        Lumen::MovieClip* Root() const { return stage ? stage->Root() : nullptr; }
        void Update(float dt) const;
        void Draw() const;
    };

    struct Note {
        GuminTaiko::FumenNote src;
        bool judged = false;       // 叩いた・見逃した（連打・風船は終わった）
        bool missed = false;       // 見逃した（そのまま流れていき、レーン左の太鼓の板の裏に消える）
        int count = 0;             // 連打・風船を叩いた回数
        double brokeAt = -1.0;     // 風船・くす玉が割れた時刻（特訓モードの吹き出しの色）
    };

    // 譜面分岐の進み具合。本家どおり、分岐の1小節前までの成績で、分岐の頭に入る前に譜面を決める
    struct BranchEvent {
        enum class Kind { Hold, Decide, Show, Section };   // 同じ時刻なら、この順に処理する
        double time = 0.0;
        Kind kind = Kind::Section;
        size_t index = 0;          // 何番目の分岐か（Decide・Show）
    };
    struct BranchRun {
        std::vector<BranchEvent> events;   // 時刻の順
        size_t next = 0;
        std::vector<int> decided;  // 分岐ごとに決めた譜面（0 普通 1 玄人 2 達人。まだなら -1）
        int level = 0;             // いま流している譜面
        int shown = -1;            // レーンに出している譜面（-1: まだ分岐に入っていない）
        bool hold = false;         // #LEVELHOLD を過ぎた（以降は譜面を動かさない）
        // 判定に使う成績の数え始め（#SECTION のたびに、そのときの値を控える）
        int baseGood = 0, baseOk = 0, baseBad = 0, baseRolls = 0, baseScore = 0;
    };

    struct Player {
        bool active = false;
        int index = 0;             // 0: 1P 1: 2P
        int course = GuminTaiko::kCourseEasy;
        GuminTaiko::Fumen fumen;
        std::vector<Note> notes;   // 叩く時刻の順
        std::vector<double> bars;  // 小節線の時刻
        std::vector<double> barBpm, barScroll;
        std::vector<char> barBranch;   // 分岐の頭の小節線（黄色く描く）
        BranchRun branch;
        std::vector<std::pair<double, bool>> gogo;   // ゴーゴータイムの切り替わり
        float laneY = 276.0f;      // レーンの帯の上端

        size_t first = 0;          // まだ終わっていない最初の音符
        int score = 0;
        int combo = 0;
        int maxCombo = 0;
        int hp = 0;
        int good = 0, ok = 0, bad = 0, rolls = 0;
        int shinuti = 1000;
        bool gogoNow = false;
        GuminTaiko::PlayOptions options;   // 演奏オプション（選曲画面で決めたもの）
        std::string hitBank;       // 叩いた音（音色の se_neiro_XX）
        double drawOffset = 0.0;   // 音符位置調整: 音符を描く位置を、この時間（ms）ぶん遅らせる（判定は変えない）
        int activeRoll = -1;       // 叩いている最中の連打・風船

        Part lane, laneHit, laneLeft, taiko, scorePart, comboPart, course2, gauge, hitEffect, plate, renda;
        int shownScore = -1, shownCombo = -1, shownGauge = -1;
        bool gaugeFull = false;   // 魂ゲージが満タン（虹色と魂の炎を出している）

        // 叩いた音符が魂ゲージへ飛んでいく演出（onp_jump）。同時にいくつも飛ぶので使い回す
        struct Jump {
            Part part;
            float remain = 0.0f;   // 表示している残り時間（秒）
            float elapsed = 0.0f;  // 飛び始めてからの時間（秒）
            float offsetX = 0.0f;  // 叩いたときの音符の位置と判定枠の真ん中のずれ（飛ぶあいだに 0 にしていく）
        };
        std::vector<Jump> jumps;
        size_t nextJump = 0;
        int rendaShown = -1;       // 連打数の表示
        bool rendaOpen = false;

        // 加点の表示（lua: tutorial の addScore_mc_。score を4つ読み込み、加点の表示を順に使い回す）
        std::vector<Part> addScores;
        int nextAddScore = 0;
        // スコアの表示は加点の表示から 32 フレーム後に増える（lua: TutorialScore.Score_ListUpdate）
        struct PendingScore {
            int points = 0;
            float remain = 0.0f;
        };
        std::vector<PendingScore> pendingScores;
        int displayScore = 0;
    };

    // ラベルの遷移を少し後に予約する（例: normal_fever の後に fever へ）
    struct Pending {
        Lumen::MovieClip* clip = nullptr;
        std::string label;
        float remain = 0.0f;
        bool play = true;
        bool hide = false;         // 時間が来たら隠す
        int frame = -1;            // label の代わりにフレーム番号で止める
    };
    void Schedule(Lumen::MovieClip* clip, const std::string& label, float seconds, bool play = true, bool hide = false,
                  int frame = -1);
    // ラベルから frames フレームだけ再生して止める（このゲームのムービーは区切りごとに止まらないので、
    // 放っておくと次のラベルの演出まで流れてしまう）。止める先は restLabel、空なら restFrame
    void PlayOnce(Lumen::MovieClip* clip, const std::string& label, int frames, const std::string& restLabel, int restFrame = 0);
    void ShowJudge(Player& player, const Note& note, Judge judge);
    // offsetX: 飛び立つ位置の判定枠の真ん中からのずれ（叩いたときの音符の位置。早いと右、遅いと左）
    // seconds: 出しておく時間（風船の geki は虹が消えるまで長い）
    void LaunchJump(Player& player, const std::string& type, float offsetX = 0.0f, float seconds = 0.8f);
    void UpdatePending(float dt);

    // ---- 魂ゲージに合わせた演出 ----
    void UpdateStage(const Player& player);
    void SetClear(bool clear);
    void SetFever(bool fever);
    void SetDancers(int count);
    void ShowAddScore(Player& player, int points);
    void ShowFukidashi(int combo);
    void UpdateRenda(Player& player, bool hit);

    // ---- 準備 ----
    bool SetupPlayer(Player& player, int index, int players);
    void SetupNoteSprites();

    // ---- 進行 ----
    void UpdateClock(float dt);
    void UpdatePlayer(Player& player);
    void Hit(Player& player, bool don, bool right);
    // missed: 見逃した（判定の表示を出さない）
    void ApplyJudge(Player& player, Note& note, Judge judge, bool missed = false);
    void UpdateDisplays(Player& player);
    void Finish();

    // ---- 描画 ----
    float NoteX(const Player& player, double time, double bpm, double scroll) const;
    void DrawNotes(const Player& player);
    void DrawNote(const Player& player, const Note& note, float x, float y);
    void RenderDon();

    // ---- どんちゃん（lua: Don.SetLoopAnimation / Don.SetNonLoopAnimation） ----
    void UpdateDonAnimation(float dt);
    double CurrentBpm() const;   // 曲のいまの BPM（いまの時刻の小節の BPM）
    // 風船・くす玉の演出には専用のどんちゃんの枠があるので、そのあいだはふだんの枠を隠す
    void SetDonSlotHidden(bool hidden, float showAfter = 0.0f);

    // ---- 風船・くす玉演出 ----
    void StartBalloon(Player& player, int noteIndex);
    void HitBalloon(Player& player);
    void BreakBalloon(Player& player);
    void MissBalloon(Player& player);
    void StartKusudama(Player& player, int noteIndex);
    void HitKusudama(Player& player);
    void BreakKusudama(Player& player);
    void MissKusudama(Player& player);

    // ---- 特訓モード（演奏中に F2。暗転してから切り替わる） ----
    //   本家（レッドVer. 以降の特訓モード。太鼓チームのブログ 2016/9/1 の画面）にならう:
    //   止めているあいだ、下の帯に 1P の太鼓（ふち左: 早戻し、面: 再生、ふち右: 早送り）と
    //   2P の太鼓（ふち左: テンポ遅、面: メニュー、ふち右: テンポ速）、曲テンポ・小節数（今/全体）・進み具合の帯
    //   （ゴーゴータイムの開始位置の印つき）、直前の演奏の成績（たたけた率・良可不可のうちわけ・連打数）を出し、
    //   譜面には小節線の右下に小節の番号、連打音符の上に叩いた数の吹き出し（風船・くす玉は 打数/割れる数 を色分け）を出す。
    //   演奏中: 2P の面か Space で止める。曲の最後まで行くと最初の小節で止まる。成績はリザルトに残さない
    // 次の EnsoScene を特訓モードで始める（F2 の暗転のあとに作る画面が使う）
    static inline bool startTraining = false;
    static inline int startTrainingMeasure = 0;
    void EnterTraining();
    void UpdateTraining(float deltaTime);
    void PauseTraining();
    void ResumeTraining();
    void SetTrainingTempo(float tempo);
    void DrawTraining();
    void RenderTrainingTopBackground();            // 特訓モードの上の背景を一度テクスチャに描く
    void DrawTrainingTopBackground();              // その背景を、色相を回して（紫にして）描く
    RenderTexture2D trainingTopTexture_{};
    Shader trainingHue_{};
    int trainingHueLocation_ = -1;
    bool trainingTopTried_ = false;
    void DrawTrainingLane(const Player& player);   // 譜面の上の小節の番号・連打数の吹き出し（止めているとき）
    int MeasureAt(double time) const;   // time を含む小節（trainingMeasures_ の番号）
    double Lag() const;                 // 曲の位置と譜面の時刻の差（ms。テンポを変えると聞こえるまでの遅れも伸び縮みする）
    // F2 で暗転して別の画面（特訓モード・ふつうの演奏）に切り替える
    void FadeToEnso(bool training, int measure);

    // ---- ポーズメニュー ----
    void TogglePause();
    void UpdatePauseMenu();
    void DrawPauseMenu();
    void LayoutPauseMenu();

    // 結果を PlayData に残す（リザルト画面が使う）
    void StoreResults();

    // ---- 段位道場（PlayDataManager::Dani() が挑戦中のとき。1曲ごとにこの画面を作り直し、成績は DaniRun に持ち越す） ----
    //   下の帯は背景と踊り子の代わりに、お題の板（dani_enso_detail）と段位の札（dani_enso_dani）、
    //   上はどんちゃんの背景を道場（donbg_dojo_1p）、魂ゲージは合格ラインつきの段位用（tamashii_gauge）にする。
    //   曲のあいだはレーンに襖（dani_enso_between）が閉じて次の曲名を出し、次の曲の画面で開く
    void SetupDani();
    void UpdateDani(float dt);
    void UpdateDaniExams();
    // お題の棒（本体と、1曲ごとのお題の前の曲の小さい棒）。value はお題の値、s は赤・金の基準の曲、lost は達成失敗
    void SetDaniBar(Lumen::MovieClip* bar, Lumen::MovieClip* num, const GuminTaiko::DaniExam& exam, int value, int s,
                    bool lost, std::string& shown, int& shownNumber);
    GuminTaiko::DaniSongResult DaniCurrent() const;   // いまの曲の成績
    bool DaniExamLost(const GuminTaiko::DaniExam& exam, bool songEnd, bool runEnd) const;   // 赤合格に届かなくなった
    void DaniFail();                  // 途中で不合格（演奏を止めてリザルトへ）
    void DaniSongEnd();               // 曲の終わり: 次の曲へ（襖を閉じる）か、最後ならリザルトへ
    void DaniLeave();                 // 段位道場のリザルトへ
    bool dani_ = false;
    const GuminTaiko::DaniCourse* daniCourse_ = nullptr;
    Part daniBg_, daniDetail_, daniPlate_, daniBetween_;
    std::string daniShown_[3][3];     // お題の棒の状態（変わったときだけ流し直す）: 本体・前の曲1・前の曲2
    int daniShownNumber_[3][3] = {{-1, -1, -1}, {-1, -1, -1}, {-1, -1, -1}};   // お題の棒に出している数
    int daniGaugeShown_ = -1;
    int daniGaugeState_ = -1;         // 0: 合格ラインの下 1: 上 2: 満タン
    // Play: 演奏中 Closing: 次の曲へ襖を閉じている Ending: 3曲終えた・不合格になった（リザルトへ）
    enum class DaniPhase { Play, Closing, Ending } daniPhase_ = DaniPhase::Play;
    float daniTimer_ = 0.0f;
    bool daniSwitched_ = false;       // 次の曲の画面に切り替えた
    int warmupFrames_ = 0;            // 画面を作った直後のフレーム数（長くなった最初の1フレームで襖や時刻が飛ばないように）
    bool daniOpened_ = false;         // 始めの襖を開けた
    void ShowDaniSongInfo(int songIndex, bool play);   // 右上の曲名と「N曲目」を、その曲のものにする（襖が開いたとき）
    void UpdateDaniSongInfo(float dt);                 // ジャンルの板と「N曲目 / N曲」を、同じ場所でフェードして入れ替える
    void SetSongNumber(int number, int total);
    void DrawAutoBadge(const Player& player) const;
    bool daniInfoRun_ = false;        // 入れ替えの動きを始めた
    float daniInfoTime_ = 0.0f;
    bool daniInfoNumberPhase_ = false;   // song_info を「N曲目」が見える時間で止めている
    float daniInfoGenreAlpha_ = 1.0f;
    float daniInfoNumberAlpha_ = 0.0f;
    std::array<float, 3> daniInfoTint_ = {1.0f, 1.0f, 1.0f};   // ジャンルの板の色

    // ---- 演奏オプション ----
    void ApplyNoteOptions(Player& player, size_t from = 0);   // あべこべ・ランダム（音符の色を入れ替える。from 番目から）
    void SetupBranches(Player& player);             // 譜面分岐の判定と表示の予定を立てる
    void BuildTimeline(Player& player);             // 小節線とゴーゴーを、いま流す譜面で並べ直す
    void InsertBranchNotes(Player& player, size_t branch, int level);   // 決めた譜面の音符を差し込む
    void UpdateBranch(Player& player);              // 時刻が来た予定（判定・表示・成績の数え直し）を進める
    void DrawBranchLabel(const Player& player);     // 「普通譜面・玄人譜面・達人譜面」をレーンの右に出す
    void ShowBranch(Player& player, size_t branch); // レーンの色と「普通・玄人・達人」の表示を切り替える
    bool VoiceOn(const Player& player) const { return player.options.voice; }
    void HitFeedback(Player& player, bool don, bool right);   // 叩いた音と太鼓の動き（判定はしない）
    void UpdateResultVoice();                       // フルコンボの声を、文字が出る瞬間に鳴らす
    const char* resultVoice_ = nullptr;             // まだ鳴らしていない声（なければ nullptr）
    Lumen::MovieClip* resultVoiceClip_ = nullptr;   // その声に合わせる文字の動き
    // 演奏スキップ: つかっていない太鼓のフチを左右交互に 10 回叩くと演奏を終える（1人で「する」にしたときだけ）
    void UpdateEnsoSkip(float deltaTime);
    Part skipPart_;
    int skipCount_ = 0;
    int skipLastSide_ = -1;        // 前に叩いたフチ（0: 左 1: 右）
    float skipIdle_ = 0.0f;        // 最後に叩いてからの秒数（しばらく叩かなければ数え直す）
    bool skipped_ = false;         // 演奏スキップで終えた（成績は残さない）

    GuminTaiko::SongInfo song_;
    std::vector<Player> players_;
    bool loaded_ = false;

    // 画面全体の部品
    Part bgBottom_, bgDai_, dancer_, donBg_, donBgObj_, donEnso_, songInfo_, gogoEffect_, result_;
    Part bgFever_, feverEffect_, fukidashi_;
    Part fusenPart_, kusudamaPart_, rendaEffect_, branchEffect_, pauseMenu_;

    // ポーズ状態
    bool isPaused_ = false;
    int pauseSelected_ = 0;

    bool leaving_ = false;         // リザルト画面へ移り始めた

    // 特訓モード
    bool training_ = false;
    bool trainingPaused_ = false;
    int trainingMeasure_ = 0;              // 選んでいる小節
    std::vector<double> trainingMeasures_; // 小節の頭の時刻（譜面の小節。小節線を消した小節も数える）
    std::vector<double> trainingMeasureBpm_, trainingMeasureScroll_;
    bool trainingCountIn_ = false;         // 曲の頭より前から始めたので、曲の頭まで音を止めたまま時刻を進めている
    float trainingTempo_ = 1.0f;           // 曲テンポ（0.5〜1.5 倍）
    double trainingRunStart_ = 0.0;        // 直前の演奏の範囲（吹き出しを出す連打音符）
    double trainingRunEnd_ = -1.0;
    std::vector<double> trainingBeats_;    // 演奏を始める前の1小節の拍（カウントの音を鳴らす時刻）
    int trainingMoveSound_ = 0;            // 早送り・早戻しの音を鳴らしている（1: 早送り -1: 早戻し）
    float trainingHitFlash_[2][4] = {};    // 叩いた面・ふちを光らせる残り時間（1P・2P × TaikoInput::Pad の順）
    float trainingButtonFlash_[6] = {};    // 押したボタンを光らせる残り時間（早戻し・再生・早送り・遅・メニュー・速）
    bool trainingSongReady_ = false;       // 特訓モードで始めた画面: 曲を読み込んで止めてある

    // 風船・くす玉
    int activeBalloon_ = -1;
    int activeKusudama_ = -1;
    float kusudamaTime_ = -1.0f;   // くす玉が始まってからの秒数（「連打」の文字を出すのに使う）
    int balloonPlayer_ = 0;        // 風船・くす玉を叩いているプレイヤー
    DonAnimator don_;
    float donRate_ = 1.0f;             // どんちゃんの踊りの速さ（曲のいまの BPM ÷ 120。BPM が変わるときはなめらかに寄せる）
    float donSlotShowTimer_ = -1.0f;   // ふだんのどんちゃんの枠を出し直すまでの秒数

    // 「ふだん ↔ フィーバー」の切り替えがあるムービー（in で入り、loop を繰り返し、out で抜ける）
    struct Cycle {
        Lumen::MovieClip* clip = nullptr;
        std::string offLoop;       // ふだんの繰り返し（空なら、抜けたら隠す）
        std::string in, loop, out;
        int outEnd = -1;           // out の終わりのフレーム（-1 なら最後まで）
        bool hideWhenOff = false;
        int phase = 0;             // 0: ふだん 1: 入り中 2: フィーバー 3: 抜け中
    };
    void SetCycle(Cycle& cycle, bool on);
    void UpdateCycle(Cycle& cycle);
    Cycle donBgCycle_, bgFeverCycle_, feverEffectCycle_;
    std::vector<Pending> pending_;
    bool clear_ = false;           // 魂ゲージがクリアのラインを超えている
    bool fever_ = false;           // 魂ゲージが満タン（入魂）
    int dancers_ = 0;              // 出ている踊り子の数（中央から）
    int dancerVariants_ = 1;       // 踊り子のムービーにある色違いの数（Dancer1〜N）
    double danceTime_ = 0.0;       // 踊り子の共通の時計（秒）。全員の踊りのフレームをこれで決める

    // 音符の見た目（種類ごとに onp_all を1つずつ）
    struct NoteSprite {
        std::unique_ptr<Lumen::Stage> stage;
        Lumen::MovieClip* clip = nullptr;   // onp_base/onp0
        Lumen::MovieClip* body = nullptr;   // 連打の胴（伸ばして描く）
        Lumen::MovieClip* tail = nullptr;   // 連打の尻尾
    };
    std::map<std::string, NoteSprite> sprites_;
    std::unique_ptr<Lumen::Stage> barStage_;
    Lumen::MovieClip* bar_ = nullptr;

    // 時刻（ms、曲の先頭が 0）
    double clock_ = -2000.0;
    double drift_ = 0.0;          // 曲の再生位置と時刻のずれ（ならしたもの、ms）
    bool songStarted_ = false;
    bool songLoading_ = false;    // 曲を読み込み始めた（止めたまま置いておく）
    double lastTime_ = 0.0;       // 最後の音符が終わる時刻
    float finishTimer_ = -1.0f;   // 終わってからの秒数
    bool finished_ = false;

    DonModel don3d_;
    RenderTexture2D donTexture_{};
    long long donRenderedFrame_ = -1;   // どんちゃんを最後に描いた 1/60 秒の区切り（RenderDon）
    static inline int activeCount_ = 0;
};
