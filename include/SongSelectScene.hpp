#pragma once
#include <map>
#include <string>
#include <vector>

#include "DonModel.hpp"
#include "LumenPlayer.hpp"
#include "PlayOptionBoard.hpp"
#include "Scene.hpp"
#include "SongDatabase.hpp"
#include "raylib.h"

// 曲選択画面
// Data/x64/lua/song_select の song_select_all / song_select_song_main / song_select_course_main を移植したもの。
//   ジャンルの看板 →（ドンでフォルダを開く）→ 曲の看板（プレビュー再生）→ 難易度選択 → 次の画面へ
// 見た目は lumen/000_default/enso_normal/song_select の Lumen を lua と同じ手順で動かす。
// 成績（王冠・スコアランク・総合成績）と演奏オプションは本家ではカードユーザーだけだが、ここではコインでも使える。
// 移植していないもの: ショップ、QR、段位などの特別なフォルダ、
// 途中参加、連打でのスキップ
class SongSelectScene : public Scene {
public:
    void Initialize() override;
    void Update(float deltaTime) override;
    void Draw() override;
    void Finalize() override;

private:
    enum class State {
        StartWait,      // 画面が出てから操作を受け付けるまで
        SongMain,       // 看板を選ぶ
        OpenFolder,     // ジャンルのフォルダを開く演出
        CloseFolder,    // 「もどる」でフォルダを閉じる演出
        SongDecide,     // 曲を決めた演出
        CourseIn,       // 難易度選択の板が出てくる
        CourseMain,     // 難易度を選ぶ
        CourseDecide,   // 難易度を決めた演出
        CourseWaitEnd,  // 決めてから次の画面へ行くまで
        End,
    };

    // 並んでいる看板1枚分（lua: PanelData）
    struct Panel {
        enum class Type { Genre, Song, Back };
        Type type = Type::Genre;
        const GuminTaiko::GenreInfo* genre = nullptr;
        const GuminTaiko::SongInfo* song = nullptr;
    };

    // 画面上の看板の枠（lua: SongSelectMultiBoard）。ジャンル用と曲用を重ねて置き、片方だけ見せる
    struct Board {
        Lumen::MovieClip* genreRoot = nullptr;   // kanban_genre_N（genre_board を読み込んだもの）
        Lumen::MovieClip* songRoot = nullptr;    // kanban_song_N（song_board を読み込んだもの）
        Lumen::MovieClip* genre = nullptr;       // その main/board（開く・閉じるのアニメーション）
        Lumen::MovieClip* song = nullptr;
    };

    struct CoursePlayer {
        bool joined = false;
        int index = 0;          // courseLabels_ の位置（0: もどる 1: 演奏オプション 2〜5: かんたん〜おに）
        bool decided = false;
        int rightCount = 0;     // 右端でふちを叩いた回数（おに裏に切り替える）
    };

    // ---- 進行 ----
    void Step();                                  // 1フレーム分（60fps）
    void SetState(State state);
    void StepSongMain();
    void StepOpenFolder();
    void StepCloseFolder();
    void StepSongDecide();
    void StepCourse();

    // ---- 看板の並び（lua: song_select_song_main） ----
    void BuildGenrePanels();
    void OpenFolderPanels(int genreIndex);
    int PanelCount() const { return int(panels_.size()); }
    int Wrap(int index) const;
    const Panel& PanelAt(int index) const { return panels_[size_t(Wrap(index))]; }
    const Panel& Current() const { return PanelAt(current_); }
    int FocusSlot() const { return scrollDirection_ < 0 ? 1 : 0; }   // lua: kSelectNumber + openOffset
    void SetBoards();
    void SetGenreBoard(const Board& board, const GuminTaiko::GenreInfo& genre);
    void SetSongBoard(const Board& board, const Panel& panel);
    void SetSongTitle(const Board& board, const GuminTaiko::SongInfo& song, bool closed);
    void MoveCursor(int direction);
    void SelectGenre();
    void DecideSong();
    void CloseFolder();
    void UpdateBackground();

    // ---- 難易度選択（lua: song_select_course_main） ----
    void StartCourse();
    void ReturnFromCourse();
    void CourseMove(int player, int direction);
    void CourseDecide(int player);
    void CourseCursor(int player, bool move);
    int CourseValue(int player) const;            // 決めた難易度（GuminTaiko::Course）
    // カーソルの位置（2〜5: かんたん〜おに）の難易度に譜面があるか。TJA に書かれていない難易度は非活性
    bool CourseEnabled(int index) const;
    void SetCourseBoardsEnabled();                // 非活性の難易度の板を暗くする
    Lumen::MovieClip* CourseBoard(const std::string& path) const;

    // ---- 成績（lua: SongDispData:SetCrown / SetScoreRank、SongSelectCourseBoard、common/PlayerInfo） ----
    void SetSongRecord(const Board& board, const Panel& panel);
    void SetCourseRecord();
    void SetPlayerInfo(int player);
    void UpdateBestScore();

    // ---- 演奏オプション（lua: song_select_option_main） ----
    void OpenOption(int player);
    void SaveOption(int player);                  // 閉じた板の設定を残す（lua: SaveOptionParam）
    void SetOptionIcon(int player);               // 名前の横のオプションのアイコン（lua: SetOptionIcon）

    // ---- 音 ----
    void PlayFocusSound();
    void StopFocusSound();
    void PlaySe(const std::string& tone, int player) const;

    // ---- どんちゃん ----
    void RenderDons();

    bool loaded_ = false;
    Lumen::Stage stage_;
    Lumen::MovieClip* main_ = nullptr;
    Lumen::MovieClip* kanban_ = nullptr;
    Lumen::MovieClip* bg_[2] = {};
    Lumen::MovieClip* course_ = nullptr;      // main/course_select（song_select_main_diff を読み込んだもの）
    Lumen::MovieClip* timeCount_ = nullptr;
    Lumen::MovieClip* guide_ = nullptr;
    Board boards_[8];

    // 叩いた入力（次に進むフレームまで覚えておく）
    struct Input {
        bool don = false, kaLeft = false, kaRight = false;
    };
    Input input_[2];
    bool keepInput_ = false;       // 看板が動いている間の入力を、次のフレームまで持ち越す

    // 同じふちをすばやく2回叩くと7曲とばす（lua: SongSelectSongMain の「スキップ(早送り)機能」）
    Input skipInput_[2];           // そのフレームに叩いたふち（看板が動いている間も数える。持ち越さない）
    int skipHits_[2] = {};         // 叩いた数（右は +、左は −）
    int skipFrames_[2] = {};       // 次の入力を待つ残りフレーム
    int skipIgnore_ = 0;           // とばしたあと、ふつうの移動を受け付けない残りフレーム
    int skipDirection_ = 0;        // とばした向き（1: 右 −1: 左 0: なし）
    void ResetSkipping();
    void ProcessSkipping();
    int SkipTriggered();           // とばす向き（とばさないなら 0）
    bool favKey_ = false;          // TAB（お気に入りを入れる／はずす）を押した（次に進むフレームまで覚えておく）
    bool back_ = false;            // ESC（1つ前へ戻る）。難易度選択 → 曲の一覧 → ジャンルの一覧 → エントリー画面
    bool StepBack();               // ESC を処理した（状態が変わった）ら true

    State state_ = State::StartWait;
    int stateFrame_ = 0;
    float accumulator_ = 0.0f;
    bool joined_[2] = {};
    int playerCount_ = 0;

    std::vector<Panel> panels_;
    int current_ = 0;
    int scrollDirection_ = 0;
    int offsetType_ = 0;           // 0: 待機・右へ 1: 左へ（lua: songPanelIndexOffsetType）
    int openWait_ = 0;             // 看板が開くまでのフレーム
    bool focusOpen_ = false;       // 選んでいる看板が開いているか
    bool inputEnable_ = false;
    bool firstKatsu_ = false;
    int voiceWait_ = -1;           // ジャンル名を読み上げるまでのフレーム
    int decidePlayer_ = 0;
    bool swapTitleDone_ = false;
    std::string openGenre_;        // 開いているジャンルの id（lua: genreIdStr）
    int openGenreIndex_ = -1;
    // ★N のフォルダを開いているとき、その外の「むずかしさをえらぶ」の id と看板の位置（閉じたら、そこに戻る）
    std::string parentGenre_;
    int parentIndex_ = -1;
    static std::string BoardLabel(const std::string& genreId);   // 看板・背景の絵のラベル（「むずかしさ」関係は recent の色）
    int FolderItemCount(const GuminTaiko::GenreInfo& genre) const;
    std::vector<const GuminTaiko::SongInfo*> FolderSongs(const GuminTaiko::GenreInfo& genre) const;   // フォルダの曲（お気に入り・最近遊んだ曲は記録から）
    std::string ListOwner() const;                                                                     // お気に入り・最近遊んだ曲の持ち主（記録の owner）
    void DrawFavoriteHint();
    void ToggleFavorite();                                                                             // 選んでいる曲のお気に入りを入れる／はずす
    std::string favToast_;                                                                             // 画面に出す知らせ
    float favToastTime_ = -100.0f;   // フォルダの中の曲（「むずかしさをえらぶ」なら ★ のフォルダ）の数
    std::map<std::string, int> closeIndex_;   // フォルダを閉じたときの位置（lua: save_current_index）
    std::string bgGenre_;
    bool bgFront_ = true;          // 手前の背景（bg_instance_1）を見せているか

    std::vector<std::string> courseLabels_;
    CoursePlayer coursePlayer_[2];
    bool uraShown_ = false;
    int courseChanging_ = 0;       // おに・おに裏の切り替え中なら 1
    bool courseCursorIn_ = false;  // カーソルが出てくるアニメーションを始めたか

    // 成績を見せるプレイヤーごとの情報
    struct RecordView {
        std::string owner;                       // 記録の持ち主（GuminTaiko::PlayRecords::Owner）
        int dispCourse = 3;                      // 王冠と総合成績を見せる難易度（lua: disp_crown_level）
        Lumen::MovieClip* info = nullptr;        // 総合成績の板（playerinfo_instance_N/main_instance）
        const GuminTaiko::SongInfo* bestSong = nullptr;   // ベストスコアを出している曲
        int bestCourse = 3;
        bool bestHasUra = false;                 // おにと裏を交互に出す
        int bestCounter = 0;
    };
    RecordView record_[2];

    PlayOptionBoard optionBoard_[2];
    Lumen::MovieClip* optionIcon_[2] = {};       // dummy_option_icon_1p / 2p（common/option）
    int optionCount_[2] = {};                    // いま並んでいる演奏オプションのアイコンの数（そのとなりにオートのマークを出す）

    float timer_ = 100.0f;
    bool timerRunning_ = false;
    bool timerEnabled_ = true;     // テストモードで選曲画面のタイマーを切っていれば false
    int timerShown_ = -1;
    bool timeUp_ = false;

    DonModel don3d_;
    DonAnimator donAnim_;          // どんちゃんの動き（ふだんは result_clear_loop、とばしたときは combo）
    RenderTexture2D donTexture_[2] = {};
};
