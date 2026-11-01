#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <string>
#include <vector>

#include "raylib.h"
#include "rlgl.h"
#include "SceneManager.hpp"
#include "EntryScene.hpp"
#include "GameFont.hpp"
#include "AssetCache.hpp"
#include "AppGuard.hpp"
#include "DaniResultScene.hpp"
#include "DaniSelectScene.hpp"
#include "PlayData.hpp"
#include "PlayRecord.hpp"
#include "AttractScene.hpp"
#include "EnsoScene.hpp"
#include "LoadingScene.hpp"
#include "GameSettings.hpp"
#include "ResultScene.hpp"
#include "TestModeScene.hpp"
#include "SongDatabase.hpp"
#include "SongSelectScene.hpp"
#include "SoundManager.hpp"
#include "TaikoInput.hpp"

// OpenGL（opengl32 に入っている）。raylib のヘッダーには出ていないので自分で宣言する
extern "C" __declspec(dllimport) void __stdcall glFinish(void);
extern "C" void glfwSwapInterval(int interval);                   // raylib の中の GLFW
extern "C" __declspec(dllimport) long __stdcall DwmFlush(void);   // dwmapi: 次の画面の合成まで待つ
extern "C" void glfwPollEvents(void);                              // raylib に入っている GLFW

namespace {

// 確認用の起動オプション
//   （指定なし）                 起動時のアトラクト（NOTICE）から始める
//   --scene attract / entry / test  アトラクト（タイトルから）・エントリー画面・テストモードから始める
//   --scene songselect          1P をコインで参加させた状態で曲選択画面から始める（--players 2 で2人）
//   --scene enso --song ID --course N   演奏画面から始める（N: 0 かんたん〜4 おに裏。--auto 1 で自動演奏）
//   --scene result [--score 点]  確認用の結果でリザルト画面から始める（--stage N で N 曲目として扱う）
//   --input "秒:P:ボタン,…"    指定した時刻に叩いたことにする（P: 1/2、ボタン: kl/dl/dr/kr = 左ふち/左面/右面/右ふち）
//                              筐体のボタンは P を 0 にして test / service / coin / up / down / enter / card
//   --shot 出力.png --after 秒  指定秒後に画面を保存する（--shot は「名前@秒」で何枚でも指定できる）
//   --quit 秒                   指定秒後に終了する
//   --vsync 0                   垂直同期を切る（既定は垂直同期ありで、モニターの書き換えごとに1枚描く）
//   --target-fps N              垂直同期を切ったときの描く速さの上限（既定 240、0 で上限なし）
//   --fps 1                     1秒ごとにフレーム数・いちばん長かったフレーム・処理時間をログに出す
struct InputEvent {
    float time;
    int player;
    TaikoInput::Pad pad;
};
struct Shot {
    float time;
    std::string path;
};

std::vector<std::string> Split(const std::string& text, char separator) {
    std::vector<std::string> out;
    size_t start = 0;
    while (start <= text.size()) {
        const size_t end = text.find(separator, start);
        out.push_back(text.substr(start, end == std::string::npos ? std::string::npos : end - start));
        if (end == std::string::npos) break;
        start = end + 1;
    }
    return out;
}

} // namespace

// 全画面にする・ウィンドウに戻す。画面は 1920x1080 で描く。全画面のあいだはマウスのカーソルを出さない
//   モニターが 1920x1080 なら、枠のないウィンドウをモニターより1ドットだけ縦に大きく置く（下の1ドットは画面の外）。
//   ぴったり同じ大きさにすると Windows が画面の合成を飛ばして直接表示に切り替え、垂直同期が効かないドライバーで
//   画面の合成に合わせて描く（DwmFlush）待ちが乱れて 30FPS 以下に落ちる。1ドット大きければ合成されたまま
//   （タスクバーは全画面のときと同じく隠れる）で、描く速さもティアリングの無さもウィンドウのときと同じ。
//   ちがう解像度のモニターでは、モニターの解像度を 1920x1080 にした全画面にする
constexpr int kScreenW = 1920;
constexpr int kScreenH = 1080;
static bool g_borderless = false;

static void SetFullscreenMode(bool on) {
    if (on) {
        const int monitor = GetCurrentMonitor();
        if (GetMonitorWidth(monitor) == kScreenW && GetMonitorHeight(monitor) == kScreenH) {
            const Vector2 origin = GetMonitorPosition(monitor);
            SetWindowState(FLAG_WINDOW_UNDECORATED);
            SetWindowPosition(int(origin.x), int(origin.y));
            SetWindowSize(kScreenW, kScreenH + 1);
            g_borderless = true;
        } else if (!IsWindowFullscreen()) {
            ToggleFullscreen();
        }
        HideCursor();
    } else {
        if (g_borderless) {
            ClearWindowState(FLAG_WINDOW_UNDECORATED);
            SetWindowSize(kScreenW, kScreenH);
            const Vector2 origin = GetMonitorPosition(GetCurrentMonitor());
            SetWindowPosition(int(origin.x) + 40, int(origin.y) + 40);
            g_borderless = false;
        }
        if (IsWindowFullscreen()) ToggleFullscreen();
        ShowCursor();
    }
}

static bool IsFullscreenMode() { return g_borderless || IsWindowFullscreen(); }

int main(int argc, char** argv) {
    // 保護付きのビルド: 証明書と、プログラム・素材が書き換えられていないかを確かめる（ふだんのビルドでは何もしない）
    if (!AppGuard::CheckAtStartup()) return 1;
    std::string startScene;
    int players = 1;
    int testCostume = -1;   // --costume N: 確認用のきせかえ（0〜3 は組、100 以上はきぐるみの番号）
    bool testCard = false;  // --card 1: 1P を開発者のカード（Backup/players の JSON）でエントリーする
    int daniLevel = 6;      // --scene danienso / daniresult の段位（--dani）
    int daniSong = 0;       // --scene danienso で始める曲（--danisong 0〜2）
    bool windowed = false;  // --windowed 1: 全画面にせずウィンドウで開く（確認用）
    std::string songId;
    int course = 3;
    float quitAfter = -1.0f;
    int songCount = 1;          // --stage N: N 曲目から始める
    int testScore = 912340;     // --scene result のスコア
    bool logFps = false;
    int targetFps = 240;        // --target-fps N: 描く速さの上限（0 で上限なし。--vsync 0 のときだけ使う）
    bool vsync = true;          // --vsync 0: 垂直同期を切り、targetFps で描く
    // --play-fps N: 演奏中の描く速さ（既定 120 で固定。0 で上限なし、-1 で演奏中もほかの画面と同じ垂直同期）
    int playFps = 120;
    bool fixedStep = false;   // --step 1: 1フレームを必ず 1/60 秒として進める（画面の保存を連続で撮る確認用）
    std::vector<InputEvent> inputs;
    std::vector<std::pair<float, int>> keyInputs;   // 筐体のボタン（時刻, キー）
    std::vector<Shot> shots;
    std::string pendingShot;
    for (int i = 1; i + 1 < argc; i += 2) {
        const std::string key = argv[i], value = argv[i + 1];
        if (key == "--scene") startScene = value;
        else if (key == "--players") players = std::atoi(value.c_str());
        else if (key == "--song") songId = value;
        else if (key == "--course") course = std::atoi(value.c_str());
        else if (key == "--auto") EnsoScene::autoPlay = EnsoScene::autoUsed = std::atoi(value.c_str()) != 0;
        else if (key == "--fps") logFps = EnsoScene::logClock = std::atoi(value.c_str()) != 0;
        else if (key == "--target-fps") targetFps = std::max(0, std::atoi(value.c_str()));
        else if (key == "--vsync") vsync = std::atoi(value.c_str()) != 0;
        else if (key == "--play-fps") playFps = std::atoi(value.c_str());
        else if (key == "--offset") EnsoScene::offsetMs = float(std::atof(value.c_str()));
        else if (key == "--step") fixedStep = std::atoi(value.c_str()) != 0;
        else if (key == "--quit") quitAfter = float(std::atof(value.c_str()));
        else if (key == "--stage") songCount = std::atoi(value.c_str());
        else if (key == "--score") testScore = std::atoi(value.c_str());
        else if (key == "--costume") testCostume = std::atoi(value.c_str());
        else if (key == "--card") testCard = std::atoi(value.c_str()) != 0;
        else if (key == "--dani") daniLevel = std::atoi(value.c_str());
        else if (key == "--danisong") daniSong = std::atoi(value.c_str());
        else if (key == "--windowed") windowed = std::atoi(value.c_str()) != 0;
        else if (key == "--shot") {
            const size_t at = value.find('@');
            if (at == std::string::npos) pendingShot = value;
            else shots.push_back({float(std::atof(value.c_str() + at + 1)), value.substr(0, at)});
        } else if (key == "--after" && !pendingShot.empty()) {
            shots.push_back({float(std::atof(value.c_str())), pendingShot});
            pendingShot.clear();
        } else if (key == "--input") {
            for (const std::string& item : Split(value, ',')) {
                const std::vector<std::string> parts = Split(item, ':');
                if (parts.size() != 3) continue;
                static const char* const kPads[] = {"kl", "dl", "dr", "kr"};
                for (int p = 0; p < 4; ++p) {
                    if (parts[2] == kPads[p]) {
                        inputs.push_back({float(std::atof(parts[0].c_str())), std::atoi(parts[1].c_str()) - 1, TaikoInput::Pad(p)});
                    }
                }
                // 筐体のボタン（P は 0）: test / service / coin / up / down / enter / card
                // キーボード（P は 0）: f2 / space / pgup / pgdn / home（特訓モードの確認用）
                // 筐体のボタンは今の割り当ての1つ目のキーを押したことにする
                using TaikoInput::Action;
                static const std::pair<const char*, Action> kActions[] = {
                    {"test", Action::Test}, {"service", Action::Service}, {"coin", Action::Coin}, {"card", Action::Card},
                    {"f2", Action::Training}};
                for (const auto& a : kActions) {
                    if (parts[2] == a.first) keyInputs.push_back({float(std::atof(parts[0].c_str())), TaikoInput::BoundKey(a.second, 0)});
                }
                static const std::pair<const char*, int> kKeys[] = {{"up", KEY_UP},      {"down", KEY_DOWN},        {"enter", KEY_ENTER},
                                                                    {"space", KEY_SPACE}, {"pgup", KEY_PAGE_UP},     {"pgdn", KEY_PAGE_DOWN},
                                                                    {"home", KEY_HOME},   {"esc", KEY_ESCAPE}};
                for (const auto& k : kKeys) {
                    if (parts[2] == k.first) keyInputs.push_back({float(std::atof(parts[0].c_str())), k.second});
                }
                // 任意のキー（確認用）: key<raylib のキー番号>
                if (parts[2].rfind("key", 0) == 0) keyInputs.push_back({float(std::atof(parts[0].c_str())), std::atoi(parts[2].c_str() + 3)});
            }
        }
    }

    // 画面サイズの解像度設定 (1920x1080)
    const int screenWidth = 1920;
    const int screenHeight = 1080;

    // ウィンドウ初期化（図形のふちを滑らかにするため MSAA を有効化）
    // 垂直同期（既定）: モニターの書き換え1回につき1枚ちょうどを描く。書き換えより速く描くと、1回の書き換えに
    // 2枚ぶんが上下に分かれて映り（ティアリング）、描く間隔もばらつくので、音符の動きがなめらかに見えない。
    // 描き終わるのを glFinish で待つので、遅れは1フレーム（120Hz なら約 8ms）で済む
    SetConfigFlags(FLAG_MSAA_4X_HINT | (vsync ? FLAG_VSYNC_HINT : 0));
    InitWindow(screenWidth, screenHeight, "GuminTaiko - Arcade Engine");
    // 全画面にする（ウィンドウのままだとタイトルバーのぶん下がはみ出し、タスクバーに重なる）。Alt+Enter でウィンドウと切り替える
    if (!windowed) SetFullscreenMode(true);
    TaikoInput::InstallTestSwitch();   // F12 で raylib が画面を保存しないようにする（テストスイッチは F1）
    // raylib は ESC でゲームを終わらせるので止める。ESC は「もどる」（演奏中はポーズ）に使う（TaikoInput::IsBackPressed）
    SetExitKey(KEY_NULL);
    // 垂直同期を切ったとき（--vsync 0）の描く速さの上限（既定 240FPS、--target-fps で変える。0 なら上限なし）。
    // Lumen の演出は 60fps のデータなので、それぞれの舞台が経過時間から 60fps で進める。音符の位置は毎フレーム時刻から求める
    SetTargetFPS(vsync ? 0 : targetFps);
    if (vsync) glfwSwapInterval(1);
    // ドライバーの設定で垂直同期が切られていると、上の指定は効かない。そのときは描くたびに Windows の画面の合成（DWM。
    // モニターの書き換えごとに1回）を待って、書き換え1回につき1枚にそろえる（起動直後の速さで判断する）
    bool dwmPacing = false;
    int pacingFrames = 0;
    double pacingStart = 0.0;
    TraceLog(LOG_INFO, "画面: %d Hz、垂直同期 %s", GetMonitorRefreshRate(GetCurrentMonitor()), vsync ? "あり" : "なし");
    SoundManager::Get().Init();
    // 筐体の設定（テストモード）を読み込んで反映する
    GameSettings::Get().Load();

    // 曲の一覧（TJA の読み込み。数秒かかる）は、起動のときに済ませておく。遊んでいる途中の画面の切り替えで、
    // 最初に曲を調べた画面が止まってしまわないように。そのあいだ「起動中」を出しておく
    {
        BeginDrawing();
        ClearBackground(BLACK);
        GameFont::Get().Draw("起動中...", float(screenWidth) * 0.5f, float(screenHeight) * 0.5f - 24.0f, 48.0f, RAYWHITE,
                             TextAlign::Center);
        EndDrawing();
        GuminTaiko::SongDatabase::Get().AllSongs();
    }

    EnsoScene::fixedStep = fixedStep;
    // 起動したらアトラクトから（--scene で途中の画面から始められる）
    if (startScene == "entry") {
        SceneManager::GetInstance().ChangeScene(std::make_unique<EntryScene>());
    } else if (startScene == "test") {
        SceneManager::GetInstance().ChangeScene(std::make_unique<TestModeScene>());
    } else if (startScene == "attract") {
        SceneManager::GetInstance().ChangeScene(std::make_unique<AttractScene>(false));
    } else if (startScene == "songselect" || startScene == "enso" || startScene == "loading" || startScene == "result" || startScene == "dani" ||
               startScene == "danienso" || startScene == "daniresult") {
        GuminTaiko::PlayDataManager& pd = GuminTaiko::PlayDataManager::Get();
        for (int p = 0; p < std::min(players, 2); ++p) {
            GuminTaiko::CardProfile card;
            if (p == 0 && testCard && GuminTaiko::PlayRecords::Get().Card(GuminTaiko::PlayRecords::kDeveloperCardId, card)) {
                pd.EntryCard(p, card);
            } else {
                pd.EntryCoin(p);
            }
            // 演奏から始めるときも、記録にある演奏オプションで遊ぶ
            pd.Player(p).options = GuminTaiko::PlayRecords::Get().Options(GuminTaiko::PlayRecords::Owner(p));
            if (testCostume >= 0 && testCostume < 100) pd.Player(p).costume = testCostume;
            if (testCostume >= 100) {
                pd.Player(p).costume = 4;
                pd.Player(p).kigurumi = testCostume;
            }
        }
        for (int s = 1; s < songCount; ++s) pd.NextSong();
        if (startScene == "result") {
            // 確認用の結果（--score で点数を変える）
            for (int genre = GuminTaiko::kGenreCount - 1; genre >= 0; --genre) {
                for (const GuminTaiko::SongInfo* song : GuminTaiko::SongDatabase::Get().SongsInGenre(genre)) {
                    if (song->id == songId || songId.empty()) pd.SetSelectedSong(song->uniqueId, GuminTaiko::SongDatabase::GenreIdFromNo(genre));
                }
            }
            for (int p = 0; p < std::min(players, 2); ++p) {
                GuminTaiko::PlayDataManager::EnsoResult& r = pd.Result(p);
                r.valid = true;
                r.score = testScore - p * 123450;
                r.good = 512; r.ok = 31; r.bad = testScore >= 800000 ? 0 : 12;
                r.drumroll = 87; r.maxCombo = r.bad == 0 ? 543 : 301;
                r.gauge = testScore >= 800000 ? 50 : 32;
                r.resultType = r.bad == 0 ? 2 : testScore >= 600000 ? 1 : 0;
                r.crown = r.resultType;
                r.scoreRank = r.score >= 1000000 ? 7 : r.score >= 950000 ? 6 : r.score >= 900000 ? 5 : r.score >= 800000 ? 4 : r.score >= 700000 ? 3 : r.score >= 600000 ? 2 : r.score >= 500000 ? 1 : 0;
                r.course = course;
                pd.SetSelectedCourse(p, course);
            }
            SceneManager::GetInstance().ChangeScene(std::make_unique<ResultScene>());
        } else if (startScene == "enso" || startScene == "loading") {
            // --song <曲ID> --course <0〜4> の曲で演奏から始める
            for (int genre = GuminTaiko::kGenreCount - 1; genre >= 0; --genre) {
                for (const GuminTaiko::SongInfo* song : GuminTaiko::SongDatabase::Get().SongsInGenre(genre)) {
                    if (song->id == songId || songId.empty()) pd.SetSelectedSong(song->uniqueId, GuminTaiko::SongDatabase::GenreIdFromNo(genre));
                }
            }
            for (int p = 0; p < 2; ++p) pd.SetSelectedCourse(p, course);
            if (startScene == "loading") SceneManager::GetInstance().ChangeScene(std::make_unique<LoadingScene>());
            else SceneManager::GetInstance().ChangeScene(std::make_unique<EnsoScene>());
        } else if (startScene == "dani") {
            // 段位道場の段位選択から（--card 1 と一緒に使う）
            pd.SetDecidedMode(GuminTaiko::GameMode::Dani);
            SceneManager::GetInstance().ChangeScene(std::make_unique<DaniSelectScene>());
        } else if (startScene == "danienso" || startScene == "daniresult") {
            // 段位道場の演奏（--dani <段位> の --danisong <0〜2> 曲目から）・リザルト（--score 80万以上で合格の成績）
            pd.SetDecidedMode(GuminTaiko::GameMode::Dani);
            GuminTaiko::DaniRun& run = pd.Dani();
            run = GuminTaiko::DaniRun{};
            run.active = true;
            run.level = daniLevel;
            const GuminTaiko::DaniCourse* dani = GuminTaiko::DaniDatabase::Get().Course(daniLevel);
            if (!dani) {
                TraceLog(LOG_WARNING, "段位 %d のお題がありません", daniLevel);
            } else if (startScene == "danienso") {
                run.songIndex = std::clamp(daniSong, 0, 2);
                pd.SetSelectedSong(dani->songs[size_t(run.songIndex)].uniqueId, "dani");
                pd.SetSelectedCourse(0, dani->songs[size_t(run.songIndex)].course);
                SceneManager::GetInstance().ChangeScene(std::make_unique<EnsoScene>());
            } else {
                EnsoScene::autoPlay = EnsoScene::autoUsed = true;   // 確認用の成績は記録しない
                const bool pass = testScore >= 800000;
                run.arrival = pass ? 3 : 2;
                run.failed = !pass;
                run.gauge = pass ? 0.96 : 0.55;
                for (int s = 0; s < 3; ++s) {
                    GuminTaiko::DaniSongResult& r = run.songs[size_t(s)];
                    if (s >= run.arrival) break;
                    r.good = pass ? 600 : 420; r.ok = pass ? 12 : 90; r.bad = pass ? 3 : 45;
                    r.combo = pass ? 380 : 120; r.roll = 41; r.score = pass ? 980000 : 720000; r.hit = r.good + r.ok + r.roll;
                }
                SceneManager::GetInstance().ChangeScene(std::make_unique<DaniResultScene>());
            }
        } else {
            SceneManager::GetInstance().ChangeScene(std::make_unique<SongSelectScene>());
        }
    } else {
        SceneManager::GetInstance().ChangeScene(std::make_unique<AttractScene>(true));
    }

    // メインゲームループ
    float time = 0.0f;
    bool unlocked = false;   // 演奏中なので、描く速さの上限（垂直同期）を外している
    while (!WindowShouldClose()) {
        // Alt+Enter: 全画面とウィンドウを切り替える
        if ((IsKeyDown(KEY_LEFT_ALT) || IsKeyDown(KEY_RIGHT_ALT)) && IsKeyPressed(KEY_ENTER)) SetFullscreenMode(!IsFullscreenMode());
        // 演奏中は垂直同期を切り、120FPS で固定して描く（--play-fps で変える）。モニターの書き換えより速く描くので、
        // 画面に出るのは叩いた直後の新しい絵になり、見た目の遅れが減る。ほかの画面はこれまでどおり書き換えに合わせる
        // 演奏中の描く速さがモニターの書き換えと同じ（120Hz のモニターで 120FPS など）なら、垂直同期に合わせて描く。
        // 書き換えと無関係に 120 枚描くと、描く間隔と書き換えの間隔がずれて、揺れやテアリングが出るため
        const int refreshRate = GetMonitorRefreshRate(GetCurrentMonitor());
        const bool playOnRefresh = vsync && playFps > 0 && refreshRate > 0 && std::abs(playFps - refreshRate) <= 1;
        const bool wantUnlocked = playFps >= 0 && EnsoScene::IsActive() && !fixedStep && !playOnRefresh;
        if (wantUnlocked != unlocked) {
            unlocked = wantUnlocked;
            glfwSwapInterval(unlocked ? 0 : (vsync ? 1 : 0));
            SetTargetFPS(unlocked ? playFps : (vsync ? 0 : targetFps));
            if (pacingFrames > 0) pacingFrames = 0;   // 垂直同期が効くかの測り直し（演奏中をはさんだ時間は測らない）
        }
        // raylib は入力を EndDrawing の中で読むが、そのあと画面の書き換えを待つ（最大1フレーム）ので、
        // そのあいだに叩いた入力は次の次のフレームまで遅れる。処理の直前にもう一度読んで、叩いたフレームで判定する。
        // （raylib の「押された」は前回 EndDrawing で読んだ状態との比較なので、ここで読み足しても取りこぼさない）
        glfwPollEvents();
        float deltaTime = fixedStep ? 1.0f / 60.0f : GetFrameTime();
        // 書き換えに合わせて描いているときは、画面に出る間隔はちょうど書き換えの間隔（の整数倍）なので、測った時間の
        // ばらつき（OS の待ちの誤差）をそのまま使わず、書き換えの間隔にそろえる（音符が1フレームごとに同じだけ進む）。
        // 曲の再生位置とのずれは EnsoScene がゆっくり直す
        if (!fixedStep && vsync && !unlocked && pacingFrames < 0) {
            const int refresh = GetMonitorRefreshRate(GetCurrentMonitor());
            if (refresh > 0) {
                const float period = 1.0f / float(refresh);
                deltaTime = std::max(1.0f, std::round(deltaTime / period)) * period;
            }
        }
        time += deltaTime;
        const double frameStart = GetTime();

        for (const InputEvent& e : inputs) {
            if (e.player >= 0 && e.player < 2 && time >= e.time && time - deltaTime < e.time) TaikoInput::Inject(e.player, e.pad);
        }
        for (const auto& k : keyInputs) {
            if (time >= k.first && time - deltaTime < k.first) TaikoInput::InjectKey(k.second);
        }

        // 筐体のスイッチ: テストスイッチでテストモードへ、コイン・サービスはどの画面でもクレジットに足す
        GuminTaiko::PlayDataManager& pd = GuminTaiko::PlayDataManager::Get();
        if (!TestModeScene::IsActive()) {
            // テストモードへは暗転で切り替える（切り替えの途中にもう一度押しても重ねない）
            if (TaikoInput::IsTestPressed() && !LoadingScene::IsActive()) {
                SoundManager::Get().StopAll();
                SceneManager::GetInstance().ChangeScene(
                    std::make_unique<LoadingScene>([] { return std::unique_ptr<Scene>(std::make_unique<TestModeScene>()); }), true);
            }
            if (TaikoInput::IsServicePressed()) {
                pd.AddServiceCredit();
                GameSettings::Get().AddService();
            }
        }
        if (TaikoInput::IsCoinInserted()) {
            pd.InsertCoin();
            GameSettings::Get().AddCoin();
        }
        GameSettings::Get().Update(deltaTime);

        // 1. ロジック更新
        SceneManager::GetInstance().Update(deltaTime);
        SoundManager::Get().Update(deltaTime);
        TaikoInput::ClearInjected();
        TaikoInput::ClearInjectedKeys();

        // 2. 描画処理
        BeginDrawing();
        SceneManager::GetInstance().Draw();
        rlDrawRenderBatchActive();
        const double workEnd = GetTime();
        EndDrawing();
        // ドライバーがフレームを溜めて表示が遅れないよう、描き終わるのを待つ
        glFinish();
        if (vsync && !unlocked) {
            if (dwmPacing) {
                DwmFlush();
            } else if (pacingFrames >= 0 && ++pacingFrames == 30) {
                pacingStart = GetTime();
            } else if (pacingFrames == 150) {
                const double fps = 120.0 / (GetTime() - pacingStart);
                const int refresh = GetMonitorRefreshRate(GetCurrentMonitor());
                if (refresh > 0 && fps > refresh * 1.5) {
                    dwmPacing = true;
                    TraceLog(LOG_INFO, "垂直同期が効いていない（%.0f FPS）ので、画面の合成に合わせて描きます", fps);
                }
                pacingFrames = -1;
            }
        }

        for (const Shot& shot : shots) {
            if (time >= shot.time && time - deltaTime < shot.time) TakeScreenshot(shot.path.c_str());
        }
        if (quitAfter > 0.0f && time >= quitAfter) break;
        // 1秒ごとに、実際に描いたフレーム数・いちばん長かったフレーム・処理時間の最大を出す
        if (logFps) {
            static int frames = 0;
            static float worstFrame = 0.0f, worstWork = 0.0f, sumWork = 0.0f;
            ++frames;
            worstFrame = std::max(worstFrame, deltaTime * 1000.0f);
            worstWork = std::max(worstWork, float(workEnd - frameStart) * 1000.0f);
            sumWork += float(workEnd - frameStart) * 1000.0f;
            if (int(time) != int(time - deltaTime)) {
                TraceLog(LOG_WARNING, "fps %d  worst frame %.1f ms  update+draw avg %.2f / max %.1f ms", frames, worstFrame,
                         sumWork / float(frames), worstWork);
                frames = 0;
                worstFrame = worstWork = sumWork = 0.0f;
            }
        }
    }

    // ウィンドウ閉鎖・リソース解放
    SceneManager::GetInstance().Shutdown();
    AssetCache::Get().UnloadAll();
    SoundManager::Get().Shutdown();
    GameFont::Get().Unload();
    CloseWindow();
    return 0;
}
