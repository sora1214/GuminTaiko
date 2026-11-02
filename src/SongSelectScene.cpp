#include "SongSelectScene.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdlib>
#include <memory>

#include "CommonParts.hpp"
#include "EntryScene.hpp"
#include "GameSettings.hpp"
#include "LoadingScene.hpp"
#include "PlaceholderScene.hpp"
#include "PlayData.hpp"
#include "PlayRecord.hpp"
#include "SceneManager.hpp"
#include "SoundManager.hpp"
#include "TaikoInput.hpp"
#include "TestMenu.hpp"
#include "WordList.hpp"
#include "raymath.h"

using namespace GuminTaiko;

namespace {

constexpr float kFrame = 1.0f / 60.0f;
constexpr const char* kDir = "lumen/000_default/enso_normal/song_select/";
constexpr int kBoardCount = 8;

// 看板の枠と、選んでいる看板からの位置の対応（lua: songPanelIndexOffset）。並びは 7 5 3 1 0 2 4 6
//   0: 待機・右へ動かしたとき（1 番目が中央） 1: 左へ動かしたとき（2 番目が中央）
constexpr int kOffsets[2][kBoardCount] = {{0, -1, 1, -2, 2, -3, 3, -4}, {1, 0, 2, -1, 3, -2, 4, -3}};

constexpr int kOpenPanelWait = 61;         // 看板が止まってから開くまで（lua: kopenPanelWaitCount）
constexpr int kFocusSoundWait = 36;        // 看板が止まってから音（曲のプレビュー）を流し始めるまで
constexpr int kVoiceWait = 60;             // ジャンル名を読み上げるまで（lua: wait_voice_cnt）
constexpr int kStartWait = 48;             // 操作を受け付けるまで（lua: wait_input_cnt 0.8 秒）
constexpr int kOpenFolderChangeFrame = 114;
constexpr int kCloseFolderChangeFrame = 219;
constexpr int kSongsBetweenBack = 6;       // 「もどる」の看板を 7 枚ごとに入れる
constexpr int kOpenUraCount = 10;          // 右端でこの回数ふちを叩くと、おに裏に切り替える
constexpr int kCourseEndWait = 120;        // 難易度を決めてから次へ行くまで（lua: wait_end_cnt 2 秒）
constexpr int kTimerRedLimit = 9;

// ---- サウンド ----
constexpr int kSlotBgm = 0;
constexpr int kSlotVoice = 2;
constexpr const char* kBankBgm = "bgm_senkyoku_v12a";
constexpr const char* kBankSe = "se_common_v12a";
constexpr const char* kBankSeSenkyoku = "se_senkyoku_v12a";
// 曲をとばす（lua: kSkipping_input_hit_count / kSkipping_input_frame_count / kSkipping_ignore_frame_count）
constexpr int kSkipSongs = 7;
constexpr int kSkipHitCount = 2;
constexpr int kSkipInputFrames = 7;
constexpr int kSkipIgnoreFrames = 40;   // とばしたあと、ふつうの1曲ずつの移動を受け付けない長さ（本家は 60。少し短くしてある）
constexpr const char* kBankVoice = "voice_senkuoku_v12a";

// 難易度選択で選べる板（lua: tbl_CourseNameLabel = もどる, 演奏オプション, かんたん, ふつう, むずかしい, おに）
constexpr int kIndexBack = 0;
constexpr int kIndexOption = 1;
constexpr int kIndexEasy = 2;              // ここから難易度（かんたん〜おに）
constexpr int kIndexOni = 5;
const char* const kCourseCursorSolo[] = {"pos_center_1", "pos_center_2", "pos_center_3", "pos_center_4", "pos_center_5", "pos_center_6"};
const char* const kCourseCursorDuo[] = {"pos_1", "pos_2", "pos_3", "pos_4", "pos_5", "pos_6"};
const char* const kCourseNames[] = {"easy", "normal", "hard"};
const char* const kCourseTextKeys[] = {"course_easy", "course_normal", "course_hard", "course_mania", "course_ura"};

// 差し込み枠に描くどんちゃん
constexpr int kDonTextureWidth = 1920;
constexpr int kDonTextureHeight = 1080;

void Goto(Lumen::MovieClip* clip, const std::string& label, bool play = false) {
    if (!clip) return;
    if (play) clip->GotoAndPlay(label);
    else clip->GotoAndStop(label);
}

Lumen::MovieClip* Sub(Lumen::MovieClip* root, const std::string& path) {
    return root ? root->Find(path) : nullptr;
}

// lua: mc:GotoAndStop("a/b/c", label)
void GotoPath(Lumen::MovieClip* root, const std::string& path, const std::string& label, bool play = false) {
    Goto(Sub(root, path), label, play);
}

// lua: mc:SetText("a/b/c", textName, key)
void TextPath(Lumen::MovieClip* root, const std::string& path, const std::string& textName, const std::string& key) {
    if (Lumen::MovieClip* clip = Sub(root, path)) clip->SetText(textName, key);
}

void Visible(Lumen::MovieClip* clip, bool visible) {
    if (clip) clip->SetVisible(visible);
}

// 譜面のない難易度（TJA に書かれていない難易度）の板・★の色。本家の部品に非活性の見た目がないので暗くする
constexpr Lumen::ColorF kDisabledTint{0.35f, 0.35f, 0.35f, 1.0f};
constexpr float kGenreTitleOffsetY = 14.0f;   // ジャンルの看板の名前を下げる量（看板の座標）

std::string StarLabel(int star) {
    return star >= 1 && star <= 11 ? "diff_" + std::to_string(star) : "none";
}

// ---- 成績 ----
const char* const kRecordCourses[kCourseCount] = {"easy", "normal", "hard", "oni", "ura"};
const char* const kBoardCourses[kCourseCount] = {"easy", "normal", "hard", "oni", "oniura"};   // 総合成績の板
const char* const kCrownLabels[] = {"none", "clear", "fullcombo", "perfect"};
// 看板のスコアランク（lua: SetScoreRank。粋の白・銀・金 → white / bronze / silver、雅の白・銀・金 → gold / pink / violet）
const char* const kRankLabels[] = {"none", "white", "bronze", "silver", "gold", "pink", "violet", "rainbow"};
constexpr int kBestScoreSwapFrames = 90;   // おにと裏のベストスコアを入れ替える間隔（lua: Common.FPS * 1.5）

ChartRecord FindRecord(const std::string& owner, const SongInfo& song, int course) {
    const ChartRecord* record = PlayRecords::Get().Find(owner, song.RecordId(), course);
    return record ? *record : ChartRecord();
}

// 数字（lua: PlayerInfo:SetCounter。n1_ins が1の位で、桁数は bs_N で切り替える）
void SetBoardCounter(Lumen::MovieClip* clip, int number, int digits) {
    if (!clip) return;
    int limit = 1;
    for (int i = 0; i < digits; ++i) limit *= 10;
    int rest = std::clamp(number, 0, limit - 1);
    int count = 1;
    for (int n = rest / 10; n > 0; n /= 10) ++count;
    Goto(clip, "bs_" + std::to_string(count));
    for (int i = 1; i <= count; ++i) {
        Goto(clip->Child("n" + std::to_string(i) + "_ins"), "ns_0" + std::to_string(rest % 10));
        rest /= 10;
    }
}

} // namespace

// ===========================================================================
// 読み込み（lua: SongSelectAllMain "Begin" 〜 "SetUp"）
// ===========================================================================
void SongSelectScene::Initialize() {
    PlayDataManager& pd = PlayDataManager::Get();
    for (int p = 0; p < 2; ++p) {
        joined_[p] = pd.Player(p).userType != UserType::None;
        if (joined_[p]) ++playerCount_;
    }
    if (playerCount_ == 0) {
        joined_[0] = true;
        playerCount_ = 1;
    }

    for (const char* bank : {kBankBgm, kBankSe, kBankSeSenkyoku, kBankVoice}) SoundManager::Get().Preload(bank);

    BuildGenrePanels();
    if (panels_.empty() || !stage_.Load(std::string(kDir) + "song_select_main_genre")) {
        TraceLog(LOG_WARNING, "SongSelectScene: 曲選択画面を読み込めません");
        return;
    }

    // 選曲画面の文字はすべてジャンルの看板と同じ字形（jp_64）で描く
    stage_.SetTextFace(FontFace::Large);

    // ---- 部品の読み込み ----
    for (int i = 1; i <= kBoardCount; ++i) {
        stage_.LoadMovie(std::string(kDir) + "song_select_main_genre_board", "kanban_genre_" + std::to_string(i));
        stage_.LoadMovie(std::string(kDir) + "song_select_main_song_board", "kanban_song_" + std::to_string(i));
    }
    stage_.LoadMovie(std::string(kDir) + "song_select_main_diff", "course_select");
    stage_.LoadMovie(std::string(kDir) + "song_select_bg", "bg_instance_1");
    stage_.LoadMovie(std::string(kDir) + "song_select_bg", "bg_instance_2");
    stage_.LoadMovie(std::string(kDir) + "song_select_number_of_songs", "song_of_number_instance");
    stage_.LoadMovie("lumen/000_default/common/control_guide", "control_guide_instance");
    stage_.LoadMovie("lumen/000_default/common/timer", "timer_instance");
    stage_.LoadMovie("lumen/000_default/common/name_plate", "plate_1p_instance");
    stage_.LoadMovie("lumen/000_default/common/name_plate", "plate_2p_instance");
    stage_.LoadMovie("lumen/000_default/common/player_board", "playerinfo_instance_1");
    stage_.LoadMovie("lumen/000_default/common/player_board", "playerinfo_instance_2");
    // 演奏オプションの板と、名前の横のオプションのアイコン（lua: SongSelectOptionMain:LoadMovieOptionMain）
    stage_.LoadMovie(std::string(kDir) + "song_select_main_diff_option", "main/option");
    stage_.LoadMovie("lumen/000_default/common/option", "dummy_option_icon_1p");
    stage_.LoadMovie("lumen/000_default/common/option", "dummy_option_icon_2p");

    main_ = stage_.GetMovieClip("main");
    kanban_ = stage_.GetMovieClip("main/kanban");
    course_ = stage_.GetMovieClip("course_select");
    bg_[0] = stage_.GetMovieClip("bg_instance_1");
    bg_[1] = stage_.GetMovieClip("bg_instance_2");
    timeCount_ = stage_.GetMovieClip("timer_instance/timer_main_instance/time_count_instance");
    guide_ = stage_.GetMovieClip("control_guide_instance");
    // 選曲画面のタイマー（テストモードの GUMIN SETTINGS → SONG SELECT TIMER）。切っているときは止めたまま出す
    timerEnabled_ = GameSettings::Get().Value(TestMenu::kSongSelectTimerItem) != 0;
    for (int i = 0; i < kBoardCount; ++i) {
        Board& board = boards_[i];
        board.genreRoot = stage_.GetMovieClip("kanban_genre_" + std::to_string(i + 1));
        board.songRoot = stage_.GetMovieClip("kanban_song_" + std::to_string(i + 1));
        board.genre = Sub(board.genreRoot, "main/board");
        board.song = Sub(board.songRoot, "main/board");
    }
    loaded_ = main_ && kanban_ && course_ && boards_[0].genre && boards_[0].song;
    if (!loaded_) {
        TraceLog(LOG_WARNING, "SongSelectScene: 曲選択画面の部品が足りません");
        return;
    }

    // 使わない部品（途中参加、コラボキャラ、ショップ）
    for (const char* name : {"credit_side_instance_1", "credit_side_instance_2", "event1p", "event2p", "shop",
                             "songselectui_instance"}) {
        Visible(stage_.GetMovieClip(name), false);
    }

    // ---- 何曲目か・操作ガイド（lua: SongSelectUi） ----
    // 数字と「曲目」「曲」のあいだに半角スペースを入れる（演奏画面の「N 曲目」と同じ）
    WordList::Get().Set("attract_numberofsong", std::to_string(PlayDataManager::Get().PlaySongCount()) + " 曲目");
    WordList::Get().Set("attract_numberofstage", std::to_string(PlayDataManager::Get().StageCount()) + " 曲");
    if (Lumen::MovieClip* number = stage_.GetMovieClip("song_of_number_instance")) {
        TextPath(number, "main/number_of_songs", "text_total_songs", "attract_numberofstage");
        TextPath(number, "main/number_of_songs", "text_current_songs", "attract_numberofsong");
        // 「N 曲目」「N 曲」の字形は、演奏画面（song_info）と同じ、小さい文字用の字形にする（この画面は文字をすべて太い字形にしている）。色と縁取りは元のまま
        if (Lumen::MovieClip* songs = Sub(number, "main/number_of_songs")) {
            Lumen::MovieClip::TextStyle style;
            style.face = FontFace::Small;
            style.colors = false;
            songs->SetTextStyle("text_current_songs", style);
            songs->SetTextStyle("text_total_songs", style);
        }
    }
    if (guide_) {
        if (Lumen::MovieClip* all = Sub(guide_, "main/taiko_small/all")) all->SetText("guide_text_instance", "text_guide", "decide");
        if (Lumen::MovieClip* d = Sub(guide_, "main/taiko_small/decide")) d->SetText("guide_text_instance", "text_guide", "decide");
        if (Lumen::MovieClip* d = Sub(guide_, "main/taiko_large/decide")) d->SetText("guide_text_instance", "text_guide", "decide");
        if (Lumen::MovieClip* base = Sub(guide_, "main/large_base")) base->SetText("text_title", "text_title", "guide_title");
    }

    // ---- ネームプレート・どんちゃん ----
    // それぞれのプレイヤーがエントリーで選んだきせかえ
    for (int p = 0; p < 2; ++p) {
        const PlayerData& data = PlayDataManager::Get().Player(p);
        don3d_.SetCostume(p, DonModel::FromEntry(data.costume, data.kigurumi, data.dress));
    }
    don3d_.Load();
    donAnim_.SetLoopAnimation("result_clear_loop");
    for (int p = 0; p < 2; ++p) {
        const std::string side = std::to_string(p + 1);
        Lumen::MovieClip* plate = stage_.GetMovieClip("plate_" + side + "p_instance");
        Visible(plate, joined_[p]);
        if (joined_[p]) CommonParts::SetNamePlate(plate, p);

        // 総合成績の板（lua: SongSelectAllMain "SetUp" の player_info_:SetPlayerInfo）
        RecordView& record = record_[p];
        record.owner = PlayRecords::Owner(p);
        record.dispCourse = PlayRecords::Get().DispCourse(record.owner);
        record.info = stage_.GetMovieClip("playerinfo_instance_" + side + "/main_instance");
        Visible(stage_.GetMovieClip("playerinfo_instance_" + side), joined_[p]);
        if (joined_[p]) SetPlayerInfo(p);

        // 演奏オプション（前に決めた設定から始める）。1P は左、2P は右の板
        if (joined_[p]) pd.Player(p).options = PlayRecords::Get().Options(record.owner);
        optionBoard_[p].Setup(stage_.GetMovieClip(p == 0 ? "main/option/main/board_left" : "main/option/main/board_right"), p, p == 1,
                              playerCount_ >= 2);
        optionIcon_[p] = stage_.GetMovieClip("dummy_option_icon_" + side + "p");
        Visible(optionIcon_[p], joined_[p]);
        if (joined_[p]) SetOptionIcon(p);

        Lumen::MovieClip* don = stage_.GetMovieClip("don_" + side + "p");
        Visible(don, joined_[p]);
        Goto(don, "framein", true);
        donTexture_[p] = LoadRenderTexture(kDonTextureWidth, kDonTextureHeight);
        SetTextureFilter(donTexture_[p].texture, TEXTURE_FILTER_BILINEAR);
        Lumen::SetExternalTexture(p == 0 ? "don1p" : "don2p", &donTexture_[p].texture, true);
    }

    // ---- 看板の初期状態（lua: SongSelectSongMain "Loading"） ----
    // 2曲目からは前の曲のジャンルに合わせる（lua: SetDefaultFocusGenre）
    std::string focusGenre = pd.PlaySongCount() >= 2 && !pd.SelectedGenre().empty() ? pd.SelectedGenre() : "pops";
    if (focusGenre.rfind("level", 0) == 0) focusGenre = "difficulty";   // ★N のフォルダから遊んだときは、その外の「むずかしさをえらぶ」
    for (int i = 0; i < int(panels_.size()); ++i) {
        if (panels_[size_t(i)].genre->id == focusGenre) current_ = i;
    }
    SetBoards();
    Goto(kanban_, "wait");
    Goto(boards_[0].genre, "select_on", true);
    focusOpen_ = true;
    UpdateBackground();

    stage_.Root()->GotoAndPlay("start_song_select");
    for (Lumen::MovieClip* bg : bg_) Goto(bg, "start", true);

    SoundManager::Get().PlaySlot(kBankVoice, "senkyoku_loop", kSlotVoice);
    PlayFocusSound();

    timer_ = 100.0f;
    SetState(State::StartWait);
}

void SongSelectScene::Finalize() {
    SoundManager::Get().StopAll();
    for (RenderTexture2D& texture : donTexture_) {
        if (texture.id != 0) UnloadRenderTexture(texture);
        texture = RenderTexture2D{};
    }
    don3d_.Unload();
    Lumen::ClearExternalTextures();
}

// ===========================================================================
// 進行
// ===========================================================================
void SongSelectScene::Update(float deltaTime) {
    if (!loaded_) {
        if (TaikoInput::AnyDon()) SceneManager::GetInstance().ChangeScene(std::make_unique<PlaceholderScene>());
        return;
    }
    CommonParts::ToggleAutoPlay();   // F3: オートプレイの入り切り
    // 画面は 120fps で描くが、lua の Proc と Lumen の再生は 60fps で進む。
    // 進まないフレームに叩いた入力も落とさないよう、次に進むときまで覚えておく
    for (int p = 0; p < 2; ++p) {
        input_[p].don = input_[p].don || TaikoInput::IsDon(p);
        input_[p].kaLeft = input_[p].kaLeft || TaikoInput::IsKaLeft(p);
        input_[p].kaRight = input_[p].kaRight || TaikoInput::IsKaRight(p);
        skipInput_[p].kaLeft = skipInput_[p].kaLeft || TaikoInput::IsKaLeft(p);
        skipInput_[p].kaRight = skipInput_[p].kaRight || TaikoInput::IsKaRight(p);
    }
    back_ = back_ || TaikoInput::IsBackPressed();
    donAnim_.Update(deltaTime);
    accumulator_ = std::min(accumulator_ + deltaTime, kFrame * 4.0f);
    bool first = true;
    while (accumulator_ >= kFrame) {
        accumulator_ -= kFrame;
        if (first) {
            keepInput_ = false;
            Step();   // 入力はそのフレームで一度だけ見る
            if (!keepInput_) {
                for (Input& input : input_) input = Input();
            }
            for (Input& input : skipInput_) input = Input();
        } else if (state_ != State::End) {
            ++stateFrame_;
        }
        first = false;
        stage_.Update(kFrame);
    }
}

void SongSelectScene::SetState(State state) {
    state_ = state;
    stateFrame_ = 0;
}

void SongSelectScene::Step() {
    // タイマー（曲・難易度を選んでいる間だけ進める）。テストモードの GUMIN SETTINGS で切っていれば進めない
    if (timerEnabled_ && timerRunning_ && timer_ > 0.0f) {
        timer_ = std::max(0.0f, timer_ - kFrame);
        if (timer_ <= 0.0f) {
            timeUp_ = true;
            PlaySe("don_big", -1);
        }
    }
    const int shown = int(std::ceil(timer_));
    if (shown != timerShown_) {
        timerShown_ = shown;
        CommonParts::SetTimerCount(timeCount_, shown, kTimerRedLimit);
    }
    // タイマーの影（暗くする）は止まっているときだけ。進んでいるあいだは白い（本家の選曲画面）
    if (timeCount_) {
        if (Lumen::MovieClip* shadow = timeCount_->Child("shadow")) shadow->SetVisible(!timerRunning_ || !timerEnabled_);
    }
    if (back_) {
        back_ = false;
        if (StepBack()) return;
    }
    if (state_ != State::StartWait) UpdateBestScore();

    switch (state_) {
    case State::StartWait:
        if (stateFrame_ >= kStartWait) {
            timerRunning_ = true;
            if (guide_) guide_->GotoAndPlay("start");
            SetState(State::SongMain);
            return;
        }
        break;
    case State::SongMain: StepSongMain(); break;
    case State::OpenFolder: StepOpenFolder(); break;
    case State::CloseFolder: StepCloseFolder(); break;
    case State::SongDecide: StepSongDecide(); break;
    case State::CourseIn:
    case State::CourseMain:
    case State::CourseDecide:
    case State::CourseWaitEnd: StepCourse(); break;
    case State::End: return;
    }
    ++stateFrame_;
}

// ===========================================================================
// 看板の並び
// ===========================================================================
void SongSelectScene::BuildGenrePanels() {
    panels_.clear();
    for (const GenreInfo& genre : SongDatabase::Get().Genres()) {
        Panel panel;
        panel.type = Panel::Type::Genre;
        panel.genre = &genre;
        panels_.push_back(panel);
    }
}

// ジャンルの看板を、その中の曲の看板に置き換える（lua: InsertBackPanel / InsertBackPanelSingle / InsertSongPanel）
//   もどる, 曲1〜6, もどる, 曲7〜12, もどる, …
void SongSelectScene::OpenFolderPanels(int genreIndex) {
    const Panel folder = panels_[size_t(genreIndex)];
    std::vector<Panel> songs;
    Panel back;
    back.type = Panel::Type::Back;
    back.genre = folder.genre;
    int count = 0;
    if (folder.genre->levelRoot) {
        // 「むずかしさをえらぶ」の中は、★N のフォルダの看板
        for (const GenreInfo& level : SongDatabase::Get().LevelFolders()) {
            if (count % kSongsBetweenBack == 0) songs.push_back(back);
            Panel panel;
            panel.type = Panel::Type::Genre;
            panel.genre = &level;
            songs.push_back(panel);
            ++count;
        }
    }
    for (const SongInfo* song : SongDatabase::Get().SongsInGenre(folder.genre->genreNo)) {
        if (count % kSongsBetweenBack == 0) songs.push_back(back);
        Panel panel;
        panel.type = Panel::Type::Song;
        panel.genre = folder.genre;
        panel.song = song;
        songs.push_back(panel);
        ++count;
    }
    if (songs.empty()) songs.push_back(back);   // 曲の入っていないジャンルは「もどる」だけ
    panels_.erase(panels_.begin() + genreIndex);
    panels_.insert(panels_.begin() + genreIndex, songs.begin(), songs.end());
}

// 看板・背景の絵のラベル。「むずかしさをえらぶ」と ★N のフォルダには専用の絵がないので、使っていない recent（青緑）を使う
std::string SongSelectScene::BoardLabel(const std::string& genreId) {
    return genreId == "difficulty" || genreId.rfind("level", 0) == 0 ? "recent" : genreId;
}

int SongSelectScene::FolderItemCount(const GenreInfo& genre) const {
    if (genre.levelRoot) return int(SongDatabase::Get().LevelFolders().size());
    return int(SongDatabase::Get().SongsInGenre(genre.genreNo).size());
}

int SongSelectScene::Wrap(int index) const {
    const int count = PanelCount();
    if (count <= 0) return 0;
    return ((index % count) + count) % count;
}

// すべての枠に看板の中身を入れる（lua: SetSongDataAll）
void SongSelectScene::SetBoards() {
    for (int slot = 0; slot < kBoardCount; ++slot) {
        const Board& board = boards_[slot];
        const Panel& panel = PanelAt(current_ + kOffsets[offsetType_][slot]);
        const bool isGenre = panel.type == Panel::Type::Genre;
        Visible(board.genreRoot, isGenre);
        Visible(board.songRoot, !isGenre);
        if (isGenre) SetGenreBoard(board, *panel.genre);
        else SetSongBoard(board, panel);
    }
}

// lua: GenreDispData:AdaptationData
void SongSelectScene::SetGenreBoard(const Board& board, const GenreInfo& genre) {
    Lumen::MovieClip* root = board.genreRoot;
    const std::string& id = genre.id;
    const std::string label = BoardLabel(id);
    GotoPath(root, "main/board/text_kanban_title_genre", label);
    GotoPath(root, "main/board/text_kanban_intro_genre", label);
    TextPath(root, "main/board/text_kanban_intro_genre/text_kanban_intro_genre", "text_kanban_intro_genre", "folder_intro_" + id);
    TextPath(root, "main/board/text_kanban_title_genre/text_kanban_title_genre", "text_kanban_title_genre", "folder_" + id);
    // ジャンル名は枠の中で少し上寄りに出るので、枠の真ん中に来るよう下げる（本家の看板の見た目に合わせた量）
    if (Lumen::MovieClip* title = Sub(root, "main/board/text_kanban_title_genre/text_kanban_title_genre")) {
        title->SetTextOffsetY(kGenreTitleOffsetY);
    }
    // ジャンル名と説明は、白い文字にジャンルの色の縁取り（本家の看板）
    for (const char* path : {"main/board/text_kanban_title_genre/text_kanban_title_genre",
                             "main/board/text_kanban_intro_genre/text_kanban_intro_genre"}) {
        if (Lumen::MovieClip* text = Sub(root, path)) text->SetTextSwapColors(true);
    }
    for (const char* part : {"board_top", "board_center", "board_bottom", "pattern", "genre_kanban_chara_left",
                             "genre_kanban_chara_right"}) {
        GotoPath(root, std::string("main/board/") + part, label);
    }
    GotoPath(root, "main/board/genre_kanban_icon", "wait");
    GotoPath(root, "main/board/genre_kanban_icon/genre_kanban_icon", "none");
}

// lua: SongDispData:AdaptationSongData
void SongSelectScene::SetSongBoard(const Board& board, const Panel& panel) {
    Lumen::MovieClip* root = board.songRoot;
    const std::string genre = BoardLabel(openGenre_.empty() && panel.genre ? panel.genre->id : openGenre_);
    const bool isBack = panel.type == Panel::Type::Back;

    // ---- 文字 ----
    Visible(Sub(root, "main/board/text_kanban_title_song"), !isBack);
    Visible(Sub(root, "main/board/text_song_title_sub"), !isBack);
    Visible(Sub(root, "main/board/text_song_title_ruby"), !isBack);
    Visible(Sub(root, "main/board/text_kanban_title_back"), isBack);
    for (const char* text : {"text_kanban_title_song", "text_song_title_sub", "text_song_title_ruby"}) {
        GotoPath(root, std::string("main/board/") + text, genre);
    }
    if (isBack) {
        GotoPath(root, "main/board/text_kanban_title_back", "back");
        TextPath(root, "main/board/text_kanban_title_back/text_kanban_title_back", "text_kanban_title_back", "select_back");
    } else {
        SetSongTitle(board, *panel.song, panel.song->closeDispType);
        TextPath(root, "main/board/text_song_title_ruby/text_song_title_ruby", "text_song_title_ruby",
                 "song_detail_" + panel.song->id);
    }

    // ---- 色 ----
    for (const char* part : {"board_top", "board_center", "board_bottom"}) {
        GotoPath(root, std::string("main/board/") + part, isBack ? "back" : genre);
    }
    for (const char* part : {"board_over_top", "board_over_center", "board_over_bottom"}) {
        GotoPath(root, std::string("main/board/") + part, "off");
    }

    // ---- 難易度の★（おには開いている扱い。裏譜面があれば、おに⇔おに裏を切り替えて見せる） ----
    Lumen::MovieClip* info = Sub(root, "main/board/song_kanban_info");
    if (isBack) {
        Goto(info, "none");
    } else {
        const SongInfo& song = *panel.song;
        if (song.stars[kCourseUra] > 0) Goto(info, "ura", true);
        else Goto(info, "oni");
        const char* const kInfoCourses[kCourseCount] = {"easy", "normal", "hard", "oni", "ura"};
        for (int c = 0; c < kCourseCount; ++c) {
            Lumen::MovieClip* course = Sub(info, kInfoCourses[c]);
            Goto(course, StarLabel(song.stars[size_t(c)]));
            // 譜面のない難易度は暗くする（看板は曲ごとに使い回すので毎回戻す）
            if (course) course->SetTint(song.stars[size_t(c)] > 0 ? Lumen::ColorF{1.0f, 1.0f, 1.0f, 1.0f} : kDisabledTint);
            Goto(Sub(course, "branch"), song.branch[size_t(c)] ? "on" : "off");
            if (course) course->SetText("text_course_" + std::string(kInfoCourses[c]), kCourseTextKeys[c]);
        }
        Lumen::MovieClip* support = Sub(info, "easy/support");
        Goto(support, song.papamama ? "on" : "off");
        if (support && song.papamama) support->SetText("text_kanban_support", "songselect_papamama_window_text");
    }

    SetSongRecord(board, panel);

    // ---- 鍵・アイコン（新曲だけアイコンを出す） ----
    for (const char* part : {"lock_small_1", "lock_normal_1", "lock_small_2", "lock_normal_2"}) {
        GotoPath(root, std::string("main/board/") + part, "off");
    }
    GotoPath(root, "main/board/shop_info", "off");
    GotoPath(root, "main/board/icon", "wait");
    GotoPath(root, "main/board/icon/icon", !isBack && panel.song->isNew ? "icon_new" : "none");
}

// 閉じた看板では曲名とサブ表記を入れ替えるものがある（lua: song_panelCloseDispType）
void SongSelectScene::SetSongTitle(const Board& board, const SongInfo& song, bool closed) {
    const std::string title = "song_" + song.id;
    const std::string sub = "song_sub_" + song.id;
    TextPath(board.songRoot, "main/board/text_kanban_title_song/text_kanban_title_song", "text_kanban_title_song",
             closed ? sub : title);
    TextPath(board.songRoot, "main/board/text_song_title_sub/text_song_title_sub", "text_song_title_sub", closed ? title : sub);
    // 曲名もジャンルの看板と同じく、白い文字にジャンルの色の縁取りで、枠の真ん中に来るよう下げる
    if (Lumen::MovieClip* c = Sub(board.songRoot, "main/board/text_kanban_title_song/text_kanban_title_song")) {
        c->SetTextSwapColors(true);
        c->SetTextOffsetY(kGenreTitleOffsetY);
    }
    if (Lumen::MovieClip* c = Sub(board.songRoot, "main/board/text_song_title_sub/text_song_title_sub")) c->SetTextSwapColors(true);
}

// ===========================================================================
// 成績
// ===========================================================================
// 曲の看板の王冠とスコアランク（lua: SongDispData:SetCrown / SearchAnyCrown / SetScoreRank）
void SongSelectScene::SetSongRecord(const Board& board, const Panel& panel) {
    for (int p = 0; p < 2; ++p) {
        const std::string side = std::to_string(p + 1);
        Lumen::MovieClip* crown = Sub(board.songRoot, "main/board/crown_" + side);
        Lumen::MovieClip* rank = Sub(board.songRoot, "main/board/rank_" + side);
        Goto(crown, "none");
        Goto(rank, "none");
        if (!joined_[p] || panel.type != Panel::Type::Song) continue;
        const RecordView& view = record_[p];
        std::array<ChartRecord, kCourseCount> records;
        for (int c = 0; c < kCourseCount; ++c) records[size_t(c)] = FindRecord(view.owner, *panel.song, c);

        // 王冠: 見せる難易度の王冠。なければ、ほかの難易度の王冠（かんたんから順に見て最後に見つかったもの）
        int crownCourse = records[size_t(view.dispCourse)].crown > 0 ? view.dispCourse : -1;
        for (int c = kCourseCount - 1; c >= 0 && crownCourse < 0; --c) {
            if (records[size_t(c)].crown > 0) crownCourse = c;
        }
        if (crownCourse >= 0) {
            const char* label = kCrownLabels[std::clamp(records[size_t(crownCourse)].crown, 1, 3)];
            Goto(crown, label);
            GotoPath(crown, label, kRecordCourses[crownCourse]);
        }

        // スコアランク: 見せる難易度のもの。おに裏でまだ取っていなければ、おにのもの
        int rankCourse = view.dispCourse;
        if (rankCourse == kCourseUra && records[kCourseUra].scoreRank <= 0) rankCourse = kCourseOni;
        const int scoreRank = std::clamp(records[size_t(rankCourse)].scoreRank, 0, 7);
        if (scoreRank > 0) {
            Goto(rank, kRankLabels[scoreRank]);
            GotoPath(rank, kRankLabels[scoreRank], kRecordCourses[rankCourse]);
        }
    }
}

// 難易度の板の王冠とスコアランク（lua: SongSelectCourseBoard:SearchSetCrown / SearchSetScoreRank）。
// 王冠はすべての難易度に、スコアランクは見せる難易度の板にだけ出す
void SongSelectScene::SetCourseRecord() {
    const SongInfo& song = *Current().song;
    for (int p = 0; p < 2; ++p) {
        const std::string side = p == 0 ? "1p" : "2p";
        const int disp = record_[p].dispCourse;
        for (int c = 0; c < kCourseCount; ++c) {
            Lumen::MovieClip* board = c < kCourseOni ? CourseBoard("board_" + std::to_string(c + 1))
                                                     : CourseBoard(c == kCourseOni ? "board_4/board_oni" : "board_4/board_ura");
            Lumen::MovieClip* crown = Sub(board, "crown_" + side);
            Lumen::MovieClip* rank = Sub(board, "rank_" + side);
            Visible(crown, joined_[p]);
            Visible(rank, joined_[p]);
            Goto(crown, "none");
            Goto(rank, "none");
            if (!joined_[p]) continue;
            const ChartRecord record = FindRecord(record_[p].owner, song, c);
            if (record.crown > 0) Goto(crown, "badge_crown_" + std::to_string(std::clamp(record.crown, 1, 3)));            // おにの板は、おに裏を見せるときも出す
            const bool rankShown = c < kCourseOni ? c == disp : c == kCourseOni ? disp >= kCourseOni : disp == kCourseUra;
            if (rankShown && record.scoreRank > 0) Goto(rank, "badge_rank_" + std::to_string(std::clamp(record.scoreRank, 1, 7)));
        }
    }
}

// 総合成績の板（lua: PlayerInfo:SetPlayerInfoParam）。見せる難易度で王冠・スコアランクを取った譜面の数
void SongSelectScene::SetPlayerInfo(int p) {
    const RecordView& view = record_[p];
    Lumen::MovieClip* info = view.info;
    if (!info) return;
    Goto(Sub(info, "player_board_instance/bg_instance"), kBoardCourses[view.dispCourse]);
    const RecordTotals totals = PlayRecords::Get().Totals(view.owner, view.dispCourse);
    for (int i = 1; i <= 3; ++i) {
        const std::string n = std::to_string(i);
        SetBoardCounter(Sub(info, "player_board_instance/num_crown_instance_" + n), totals.crown[size_t(i)], 4);
        SetBoardCounter(Sub(info, "player_board_instance/num_iki_instance_" + n), totals.scoreRank[size_t(i)], 4);
        SetBoardCounter(Sub(info, "player_board_instance/num_miyabi_instance_" + n), totals.scoreRank[size_t(i + 3)], 4);
    }
    SetBoardCounter(Sub(info, "player_board_instance/num_kiwami_instance"), totals.scoreRank[7], 4);

    // トークンはないので出さない。ベストスコアは曲を選んでいるときだけ出す
    Visible(Sub(info, "token_instance"), false);
    Visible(Sub(info, "token_event_instance"), false);
    if (Lumen::MovieClip* best = Sub(info, "bestscore_instance")) {
        best->SetText("text_score_title", "playerboard_scoretitle");
        best->SetVisible(false);
    }
}

// 選んでいる曲の自己ベスト（lua: SongSelectAllMain:UpdateBestScore → PlayerInfo:UpdateBestScoreInfo / Update）。
// 見せる難易度がおにかおに裏で、両方の譜面がある曲は 1.5 秒ごとに入れ替える
void SongSelectScene::UpdateBestScore() {
    const Panel& panel = Current();
    const SongInfo* song = panel.type == Panel::Type::Song ? panel.song : nullptr;
    for (int p = 0; p < 2; ++p) {
        RecordView& view = record_[p];
        Lumen::MovieClip* best = Sub(view.info, "bestscore_instance");
        if (!joined_[p] || !best) continue;
        bool changed = false;
        if (song != view.bestSong) {
            view.bestSong = song;
            view.bestCourse = view.dispCourse;
            view.bestHasUra = song && view.dispCourse >= kCourseOni && song->stars[kCourseOni] > 0 && song->stars[kCourseUra] > 0;
            view.bestCounter = 0;
            changed = true;
        } else if (view.bestHasUra && ++view.bestCounter >= kBestScoreSwapFrames) {
            view.bestCounter = 0;
            view.bestCourse = view.bestCourse == kCourseOni ? kCourseUra : kCourseOni;
            changed = true;
        }
        if (!changed) continue;
        best->SetVisible(song != nullptr);
        if (!song) continue;
        Goto(best->Child("score_icon_instance"), kBoardCourses[view.bestCourse]);
        SetBoardCounter(best->Child("score_instance"), FindRecord(view.owner, *song, view.bestCourse).score, 8);
    }
}

// ===========================================================================
// 看板を選ぶ（lua: SongSelectSongMain "Main"）
// ===========================================================================
void SongSelectScene::StepSongMain() {
    const Panel& panel = Current();

    // ジャンルにしばらく止まったら名前を読み上げる（一度でもふちを叩いてから）
    if (voiceWait_ > 0 && --voiceWait_ == 0 && firstKatsu_ && panel.type == Panel::Type::Genre &&
        !panel.genre->voiceTone.empty()) {
        SoundManager::Get().PlaySlot(kBankVoice, panel.genre->voiceTone, kSlotVoice);
    }

    // ---- 入力（lua: ProcessSkipping / PlayerInput） ----
    ProcessSkipping();
    if (inputEnable_) {
        int don = -1, ka = 0, kaPlayer = -1;
        for (int p = 0; p < 2; ++p) {
            if (!joined_[p]) continue;
            if (don < 0 && input_[p].don) don = p;
            if (ka == 0 && input_[p].kaRight) ka = 1, kaPlayer = p;
            if (ka == 0 && input_[p].kaLeft) ka = -1, kaPlayer = p;
        }
        // 時間切れ: ジャンルなら開き、曲なら決める。「もどる」は飛ばす
        if (timeUp_ && don < 0 && ka == 0) {
            if (panel.type == Panel::Type::Back) ka = 1;
            else don = joined_[0] ? 0 : 1;
        }

        if (don >= 0) {
            ResetSkipping();
            decidePlayer_ = don;
            if (panel.type == Panel::Type::Genre) SelectGenre();
            else if (panel.type == Panel::Type::Song) DecideSong();
            else CloseFolder();
            return;
        }
        // 先にとばす入力を見る（同じふちを 7 フレーム以内に2回。とばしたあと 60 フレームはふつうの移動をしない）
        if (!timeUp_ && PanelCount() > 1) {
            if (const int skip = SkipTriggered()) {
                SoundManager::Get().Play(kBankSeSenkyoku, "skip_songs");
                donAnim_.SetNonLoopAnimation("combo", true);
                donAnim_.SetLoopAnimation("result_clear_loop", true);
                MoveCursor(skip * kSkipSongs);
                return;
            }
        }
        if (skipIgnore_ > 0 && !timeUp_) ka = 0;
        if (ka != 0 && PanelCount() > 1) {
            if (!timeUp_) PlaySe("katsu", kaPlayer);
            MoveCursor(ka);
            return;
        }
    }

    // 看板が動いている間は入力を受け付けない
    inputEnable_ = !kanban_->IsPlay();
    // 看板が動いている間に叩いたぶんは捨てずに、動き終わったら受け付ける（先行入力）
    keepInput_ = !inputEnable_;

    // 止まってしばらくしたら、選んでいる看板を開く（lua: ProcKanbanWaitCountToSelectOn）。
    // 音は看板が開くより少し早く流し始める（曲のプレビューが鳴るまでの待ちを短くする）
    if (openWait_ > 0) {
        --openWait_;
        if (openWait_ == kOpenPanelWait - kFocusSoundWait) PlayFocusSound();
        if (openWait_ == 0) {
            focusOpen_ = true;
            const Board& board = boards_[FocusSlot()];
            Goto(panel.type == Panel::Type::Genre ? board.genre : board.song, "select_on", true);
            swapTitleDone_ = false;
        }
    }

    // 開いた看板では曲名とサブ表記を元に戻す（lua: SetSongPanelDispOpenType）
    if (focusOpen_ && !swapTitleDone_ && panel.type == Panel::Type::Song && panel.song->closeDispType) {
        const Board& board = boards_[FocusSlot()];
        if (board.song->CurrentFrame() >= 20) {
            SetSongTitle(board, *panel.song, false);
            swapTitleDone_ = true;
        }
    }
}

// ESC で1つ前へ戻る（演出の途中は受け付けない）
//   難易度選択 → 曲の一覧（「もどる」と同じ）、曲の一覧 → ジャンルの一覧（フォルダを閉じる）、ジャンルの一覧 → エントリー画面（暗転）
bool SongSelectScene::StepBack() {
    if (state_ == State::CourseMain) {
        if (courseChanging_ > 0) return false;
        // 演奏オプションを開いていたら、いまの設定で閉じる
        bool closed = false;
        for (int p = 0; p < 2; ++p) {
            if (!optionBoard_[p].IsOpen()) continue;
            optionBoard_[p].ForceClose();
            if (optionBoard_[p].TakeClosed()) SaveOption(p);
            closed = true;
        }
        if (closed) {
            PlaySe("primal_cancel", -1);
            return true;
        }
        for (const CoursePlayer& player : coursePlayer_) {
            if (player.joined && player.decided) return false;   // だれかが難易度を決めたあとは戻らない
        }
        ReturnFromCourse();
        return true;
    }
    if (state_ != State::SongMain || !inputEnable_) return false;
    if (!openGenre_.empty()) {
        decidePlayer_ = joined_[0] ? 0 : 1;
        CloseFolder();
        return true;
    }
    PlaySe("primal_cancel", -1);
    timerRunning_ = false;
    SoundManager::Get().StopPreview(0.3f);
    SetState(State::End);
    SceneManager::GetInstance().ChangeScene(
        std::make_unique<LoadingScene>([] { return std::unique_ptr<Scene>(std::make_unique<EntryScene>()); }), true);
    return true;
}

// 左右のふち（lua: MoveCursor）
void SongSelectScene::MoveCursor(int direction) {
    firstKatsu_ = true;
    SoundManager::Get().StopSlot(kSlotVoice);

    // 開いていた看板を閉じる
    if (focusOpen_) {
        const char* first = direction < 0 ? "select_off" : "off";
        const char* second = direction < 0 ? "off" : "select_off";
        Goto(boards_[0].genre, first, true);
        Goto(boards_[0].song, first, true);
        Goto(boards_[1].genre, second, true);
        Goto(boards_[1].song, second, true);
    }

    scrollDirection_ = direction;
    offsetType_ = direction < 0 ? 1 : 0;
    Goto(kanban_, direction < 0 ? "kanban_title_anim_u" : "kanban_title_anim_d", true);
    current_ = Wrap(current_ + direction);

    focusOpen_ = false;
    voiceWait_ = kVoiceWait;
    openWait_ = kOpenPanelWait;
    inputEnable_ = false;
    SetBoards();
    UpdateBackground();
    StopFocusSound();
}

// ---- 曲をとばす（lua: ResetSkippingVariables / ProcessSkipping / IsSkippingTriggeredLeft・Right） ----
void SongSelectScene::ResetSkipping() {
    for (int p = 0; p < 2; ++p) skipHits_[p] = skipFrames_[p] = 0;
    skipIgnore_ = 0;
}

void SongSelectScene::ProcessSkipping() {
    auto ready = [this](int p) { return std::abs(skipHits_[p]) >= kSkipHitCount; };
    // とばしたあとの無視期間が終わったらリセット（その間に続けて叩いていたら、もう一度とばす）
    if (skipIgnore_ > 0 && --skipIgnore_ == 0 && !ready(0) && !ready(1)) {
        ResetSkipping();
        skipDirection_ = 0;
    }
    for (int p = 0; p < 2; ++p) {
        if (!joined_[p]) continue;
        // しばらく叩かなければ数え直す
        if (skipIgnore_ == 0 && !ready(p) && skipFrames_[p] > 0 && --skipFrames_[p] == 0) skipHits_[p] = 0;
        for (const int direction : {1, -1}) {
            if (!(direction > 0 ? skipInput_[p].kaRight : skipInput_[p].kaLeft)) continue;
            if (skipHits_[p] * direction < 0) skipHits_[p] = 0;   // 反対のふちを叩いたら数え直す
            if (skipIgnore_ == 0) {
                skipHits_[p] += direction;
            } else if (skipDirection_ == direction) {
                skipHits_[p] = kSkipHitCount * direction;   // とばしたすぐあとは、同じ向きに1回叩けばまたすぐとばす
            } else {
                // 反対側のふちを叩いたら、とばすのはやめて1曲だけ動く（無視期間も終わる）。
                // この1回は反対向きの1回目として数えるので、続けてすぐ叩けば、待たずに反対向きにとべる
                ResetSkipping();
                skipDirection_ = 0;
                skipHits_[p] = direction;
            }
            skipFrames_[p] = kSkipInputFrames;
        }
    }
}

int SongSelectScene::SkipTriggered() {
    for (const int direction : {1, -1}) {
        if (skipHits_[0] * direction >= kSkipHitCount || skipHits_[1] * direction >= kSkipHitCount) {
            ResetSkipping();
            skipDirection_ = direction;
            skipIgnore_ = kSkipIgnoreFrames;
            return direction;
        }
    }
    return 0;
}

// ジャンルのフォルダを開く（lua: SelectGenreFolder → SongSelectAllMain:OpenGenreFolder）
void SongSelectScene::SelectGenre() {
    PlaySe("don", decidePlayer_);
    SoundManager::Get().StopSlot(kSlotVoice);

    const int genreIndex = current_;
    // ★N のフォルダは、「むずかしさをえらぶ」を開いたまま、その中で開く（閉じたらそこに戻る）
    if (Current().genre->level > 0) {
        parentGenre_ = openGenre_;
        parentIndex_ = openGenreIndex_;
    } else {
        parentGenre_.clear();
    }
    openGenre_ = Current().genre->id;
    openGenreIndex_ = genreIndex;

    const int slot = FocusSlot();
    Goto(boards_[slot].genre, "genre_deceide", true);
    Goto(boards_[0].song, "genre_deceide", true);
    Goto(kanban_, scrollDirection_ < 0 ? "genre_deceide2" : "genre_deceide", true);
    offsetType_ = 0;

    // 曲の看板を並べ、最初の曲を選ぶ。前に閉じたことがあれば、閉じた位置の次（lua: GetCloseGenreIndex() + 1）
    OpenFolderPanels(genreIndex);
    const bool emptyFolder = FolderItemCount(*Current().genre) == 0;
    current_ = emptyFolder ? genreIndex : genreIndex + 1;   // 曲がなければ「もどる」を選ぶ
    if (emptyFolder) {
        swapTitleDone_ = false;
        inputEnable_ = false;
        SetState(State::OpenFolder);
        return;
    }
    if (auto found = closeIndex_.find(openGenre_); found != closeIndex_.end()) {
        current_ = Wrap(found->second + 1);
    } else if (PlayDataManager::Get().PlaySongCount() >= 2) {
        // 2曲目からは前の曲に合わせる（lua: SetDefaultFocusSong）
        for (int i = 0; i < int(panels_.size()); ++i) {
            const SongInfo* song = panels_[size_t(i)].song;
            if (song && song->uniqueId == PlayDataManager::Get().SelectedSong()) current_ = i;
        }
    }
    swapTitleDone_ = false;
    inputEnable_ = false;
    SetState(State::OpenFolder);
}

void SongSelectScene::StepOpenFolder() {
    const int slot = FocusSlot();
    // 開く途中で看板の中身を曲に入れ替える
    if (!swapTitleDone_ && boards_[slot].genre->CurrentFrame() >= kOpenFolderChangeFrame) {
        SetBoards();
        swapTitleDone_ = true;
    }
    if (kanban_->IsPlay() || boards_[slot].song->IsPlay()) return;

    if (!swapTitleDone_) SetBoards();
    Goto(boards_[0].song, "on", true);
    scrollDirection_ = 1;
    focusOpen_ = true;
    swapTitleDone_ = false;
    UpdateBackground();
    PlayFocusSound();
    SetState(State::SongMain);
}

// 「もどる」でフォルダを閉じる（lua: End の "back" → CloseGenreFolder）
void SongSelectScene::CloseFolder() {
    PlaySe("primal_cancel", decidePlayer_);
    const int slot = FocusSlot();
    Goto(boards_[slot].song, "return", true);
    Goto(boards_[0].genre, "return", true);
    Goto(kanban_, scrollDirection_ < 0 ? "return2" : "return", true);

    closeIndex_[openGenre_] = current_;
    swapTitleDone_ = false;
    inputEnable_ = false;
    SetState(State::CloseFolder);
}

void SongSelectScene::StepCloseFolder() {
    const int slot = FocusSlot();
    auto toGenres = [this]() {
        BuildGenrePanels();
        current_ = openGenreIndex_;
        if (!parentGenre_.empty()) {
            // ★N のフォルダを閉じた: 「むずかしさをえらぶ」を開いた状態に戻して、閉じた★N の看板を選ぶ
            OpenFolderPanels(parentIndex_);
            for (int i = 0; i < int(panels_.size()); ++i) {
                if (panels_[size_t(i)].type == Panel::Type::Genre && panels_[size_t(i)].genre->id == openGenre_) current_ = i;
            }
        }
        offsetType_ = 0;
        SetBoards();
    };
    if (!swapTitleDone_ && boards_[slot].song->CurrentFrame() >= kCloseFolderChangeFrame) {
        toGenres();
        swapTitleDone_ = true;
    }
    if (kanban_->IsPlay()) return;

    if (!swapTitleDone_) toGenres();
    if (!parentGenre_.empty()) {
        openGenre_ = parentGenre_;   // 「むずかしさをえらぶ」を開いた状態に戻った
        openGenreIndex_ = parentIndex_;
        parentGenre_.clear();
    } else {
        openGenre_.clear();
    }
    Goto(boards_[0].genre, "on", true);

    // lua: "ReLoading"
    scrollDirection_ = 0;
    Goto(boards_[1].genre, "off", true);
    Goto(boards_[1].song, "off", true);
    focusOpen_ = true;
    swapTitleDone_ = false;
    UpdateBackground();
    PlayFocusSound();
    SetState(State::SongMain);
}

// 曲を決める（lua: DecideSongPanelAnimation）
void SongSelectScene::DecideSong() {
    PlaySe("don", decidePlayer_);
    // プレビューが流れ始める前に決めたときは、ここで流す（難易度選択のあいだも曲を流す）
    if (SoundManager::Get().PreviewBank() != Current().song->SoundBank()) PlayFocusSound();
    openWait_ = 0;
    SoundManager::Get().StopSlot(kSlotVoice);
    Goto(boards_[FocusSlot()].song, "song_decide", true);
    inputEnable_ = false;
    SetState(State::SongDecide);
}

void SongSelectScene::StepSongDecide() {
    if (boards_[FocusSlot()].song->IsPlay()) return;
    StartCourse();
}

// 背景をジャンルに合わせて切り替える（lua: SwitchingBg。2枚を交互にフェードさせる）
void SongSelectScene::UpdateBackground() {
    const Panel& panel = Current();
    const std::string genre = BoardLabel(panel.type == Panel::Type::Genre ? panel.genre->id : openGenre_);
    if (genre.empty() || genre == bgGenre_) return;

    if (bgGenre_.empty()) {
        for (Lumen::MovieClip* bg : bg_) GotoPath(bg, "main/bg", genre);
    } else if (bgFront_) {
        Goto(bg_[0], "end", true);
        GotoPath(bg_[1], "main/bg", genre);
        bgFront_ = false;
    } else {
        GotoPath(bg_[0], "main/bg", genre);
        Goto(bg_[0], "start", true);
        bgFront_ = true;
    }
    bgGenre_ = genre;
}

// ===========================================================================
// 難易度選択（lua: SongSelectCourseMain）
// ===========================================================================
Lumen::MovieClip* SongSelectScene::CourseBoard(const std::string& path) const {
    return Sub(course_, "main/board/" + path);
}

void SongSelectScene::StartCourse() {
    const SongInfo& song = *Current().song;
    const PlayDataManager& pd = PlayDataManager::Get();
    Goto(main_, "change_courseselect", true);
    Goto(boards_[0].genre, "return", true);
    Visible(guide_, false);
    if (timer_ < 30.0f) timer_ = 30.0f;

    courseLabels_ = {"back", "option", "easy", "normal", "hard", "oni"};
    uraShown_ = false;
    courseChanging_ = 0;
    courseCursorIn_ = false;
    SoundManager::Get().PlaySlot(kBankVoice, "select_song", kSlotVoice);

    // ---- 曲名と背景 ----
    if (Lumen::MovieClip* c = CourseBoard("text_title_song")) c->SetText("text_title_song", "song_" + song.id);
    if (Lumen::MovieClip* c = CourseBoard("text_song_title_sub")) c->SetText("text_song_title_sub", "song_sub_" + song.id);
    if (Lumen::MovieClip* c = CourseBoard("text_song_title_ruby")) c->SetText("text_song_title_ruby", "song_detail_" + song.id);
    Goto(CourseBoard("background"), BoardLabel(openGenre_));
    Visible(CourseBoard("option"), true);
    Goto(CourseBoard("option"), "on");
    Goto(CourseBoard("back"), "on");

    // ---- 難易度の板（lua: SongSelectCourseBoard:AllBoardInitialize） ----
    for (int c = 0; c < 3; ++c) {
        Lumen::MovieClip* board = CourseBoard("board_" + std::to_string(c + 1));
        Goto(board, StarLabel(song.stars[size_t(c)]));
        Goto(Sub(board, "diff_background"), kCourseNames[c]);
        if (Lumen::MovieClip* title = Sub(board, "text_course_title")) title->SetText("text_course_title", kCourseTextKeys[c]);
        Goto(Sub(board, "branch"), song.branch[size_t(c)] ? "branch" : "none");
        Goto(Sub(board, "support"), c == kCourseEasy && song.papamama ? "support" : "none");
        Goto(Sub(board, "compe_icon/board_com_icon_mc/com_select"), "none");
    }
    Lumen::MovieClip* oni = CourseBoard("board_4");
    Visible(oni, true);
    Goto(oni, "course_oni");
    Goto(Sub(oni, "board_oni"), StarLabel(song.stars[kCourseOni]));
    Goto(Sub(oni, "board_ura"), StarLabel(song.stars[kCourseUra]));
    if (Lumen::MovieClip* t = Sub(oni, "board_oni/text_course_title_oni")) t->SetText("text_course_title", "course_mania");
    if (Lumen::MovieClip* t = Sub(oni, "board_ura/text_course_title_ura")) t->SetText("text_course_title", "course_ura");
    Goto(Sub(oni, "board_oni/branch_oni"), song.branch[kCourseOni] ? "branch" : "none");
    Goto(Sub(oni, "board_ura/branch_ura"), song.branch[kCourseUra] ? "branch" : "none");
    for (const char* sub : {"board_oni", "board_ura"}) {
        Goto(Sub(oni, std::string(sub) + "/compe_icon/board_com_icon_mc/com_select"), "none");
    }
    SetCourseRecord();

    // ---- 操作ガイド ----
    Lumen::MovieClip* guide = CourseBoard("guide_s_taiko");
    Goto(guide, "init");
    if (Lumen::MovieClip* s = Sub(guide, "select_instance")) s->SetText("text_guide_instance", "text_guide", "select");
    if (Lumen::MovieClip* d = Sub(guide, "decide_instance")) d->SetText("text_guide_instance", "text_guide", "decide");

    // おにがなく裏譜面だけある曲（TJA の Edit だけ）は、はじめから裏譜面の板を出す
    if (song.stars[kCourseOni] <= 0 && song.stars[kCourseUra] > 0) uraShown_ = true;
    SetCourseBoardsEnabled();

    // ---- カーソル（lua: InitializePlayerCursor） ----
    for (int p = 0; p < 2; ++p) {
        const std::string side = std::to_string(p + 1);
        CoursePlayer& player = coursePlayer_[p];
        player = CoursePlayer();
        player.joined = joined_[p];
        // 2曲目からは前の曲で遊んだ難易度にカーソルを置く（lua: SetDefaultCourse / SetCourseCursorLastDiff）
        if (player.joined && pd.PlaySongCount() >= 2) {
            const int last = pd.SelectedCourse(p);
            player.index = std::min(last, int(kCourseOni)) + kIndexEasy;
            if (last == kCourseUra && song.stars[kCourseUra] > 0 && !uraShown_) {
                uraShown_ = true;
                SetCourseBoardsEnabled();
            }
            // 前の難易度が非活性なら、近い難易度（下の難易度を先に）にずらす。どれもなければ「もどる」
            for (int step = 1; !CourseEnabled(player.index) && step <= 4; ++step) {
                if (player.index - step >= kIndexEasy && CourseEnabled(player.index - step)) player.index -= step;
                else if (player.index + step <= kIndexOni && CourseEnabled(player.index + step)) player.index += step;
            }
            if (!CourseEnabled(player.index)) player.index = kIndexBack;
        }
        Lumen::MovieClip* cursor = CourseBoard("player_cursor_" + side);
        Visible(cursor, player.joined);
        Visible(CourseBoard("panel_frame_" + side), player.joined);
        Visible(CourseBoard("course_frame_" + side), player.joined);
        Goto(Sub(cursor, "cursor"), "in");
        Goto(Sub(cursor, "cursor/player_icon"), playerCount_ >= 2 && p == 1 ? "2p" : "1p");
        Goto(Sub(CourseBoard("panel_frame_" + side), "frame"), "in");
        Goto(Sub(CourseBoard("course_frame_" + side), "frame"), "in");
        Goto(CourseBoard("mark_" + side), player.joined ? "start" : "init", player.joined);
        if (player.joined) CourseCursor(p, false);
    }
    if (uraShown_) Goto(oni, "course_ura");
    SetState(State::CourseIn);
}

// カーソルと枠と難易度マークを今の位置に合わせる（lua: PlayerMoveSelect / DispCursorFrame / SetFocusCourseMark）
void SongSelectScene::CourseCursor(int p, bool move) {
    const std::string side = std::to_string(p + 1);
    const CoursePlayer& player = coursePlayer_[p];
    const bool duo = playerCount_ >= 2 && coursePlayer_[0].index == coursePlayer_[1].index;

    Lumen::MovieClip* cursor = CourseBoard("player_cursor_" + side);
    Goto(cursor, duo ? kCourseCursorDuo[player.index] : kCourseCursorSolo[player.index]);
    if (move) Goto(Sub(cursor, "cursor"), "move", true);
    // 同じ難易度を選んでいたら、もう片方も並べて表示する（lua: SameCursorCourse）
    if (playerCount_ >= 2) {
        const int other = 1 - p;
        Goto(CourseBoard("player_cursor_" + std::to_string(other + 1)),
             duo ? kCourseCursorDuo[coursePlayer_[other].index] : kCourseCursorSolo[coursePlayer_[other].index]);
    }

    Lumen::MovieClip* panelFrame = CourseBoard("panel_frame_" + side);
    Lumen::MovieClip* courseFrame = CourseBoard("course_frame_" + side);
    if (player.index < kIndexEasy) {
        Goto(courseFrame, "none");
        Goto(panelFrame, player.index == kIndexBack ? "back" : "option");
    } else {
        Goto(panelFrame, "none");
        Goto(courseFrame, "pos_" + std::to_string(player.index - kIndexEasy + 1));
    }

    std::string mark = "none";
    if (player.index >= kIndexEasy) {
        mark = "course_" + std::to_string(player.index == kIndexOni && uraShown_ ? 5 : player.index - kIndexEasy + 1);
    }
    for (const char* part : {"mark_course", "mark_course_white", "mark_course_white_2"}) {
        Goto(CourseBoard("mark_" + side + "/" + part), mark);
    }
    Goto(CourseBoard("mark_" + side), "start", true);
}

bool SongSelectScene::CourseEnabled(int index) const {
    if (index < kIndexEasy) return true;
    const SongInfo& song = *Current().song;
    if (index == kIndexOni) return song.stars[uraShown_ ? kCourseUra : kCourseOni] > 0;
    return song.stars[size_t(index - kIndexEasy)] > 0;
}

void SongSelectScene::SetCourseBoardsEnabled() {
    const SongInfo& song = *Current().song;
    auto tint = [](Lumen::MovieClip* clip, bool enabled) {
        if (clip) clip->SetTint(enabled ? Lumen::ColorF{1.0f, 1.0f, 1.0f, 1.0f} : kDisabledTint);
    };
    for (int c = 0; c < 3; ++c) tint(CourseBoard("board_" + std::to_string(c + 1)), song.stars[size_t(c)] > 0);
    tint(CourseBoard("board_4/board_oni"), song.stars[kCourseOni] > 0);
    tint(CourseBoard("board_4/board_ura"), song.stars[kCourseUra] > 0);
}

int SongSelectScene::CourseValue(int p) const {
    const int index = std::max(kIndexEasy, coursePlayer_[p].index);
    if (index == kIndexOni && uraShown_) return kCourseUra;
    return index - kIndexEasy;
}

void SongSelectScene::StepCourse() {
    switch (state_) {
    case State::CourseIn:
        // 板が出てきたらカーソルを出し（lua: waitBoardIn）、カーソルが出たら枠を出す（lua: waitCursorIn）
        if (stateFrame_ == 0 || main_->IsPlay()) return;
        if (!courseCursorIn_) {
            for (int p = 0; p < 2; ++p) {
                if (!coursePlayer_[p].joined) continue;
                const std::string side = std::to_string(p + 1);
                Goto(CourseBoard("player_cursor_" + side + "/cursor"), "in", true);
                Goto(CourseBoard((coursePlayer_[p].index < kIndexEasy ? "panel_frame_" : "course_frame_") + side + "/frame"), "in", true);
            }
            courseCursorIn_ = true;
            return;
        }
        for (int p = 0; p < 2; ++p) {
            Lumen::MovieClip* cursor = CourseBoard("player_cursor_" + std::to_string(p + 1) + "/cursor");
            if (coursePlayer_[p].joined && cursor && cursor->IsPlay()) return;
        }
        for (int p = 0; p < 2; ++p) {
            const std::string side = std::to_string(p + 1);
            Goto(CourseBoard("panel_frame_" + side + "/frame"), "select", true);
            Goto(CourseBoard("course_frame_" + side + "/frame"), "select", true);
        }
        Goto(CourseBoard("guide_s_taiko"), "fade_in", true);
        SetState(State::CourseMain);
        return;

    case State::CourseMain: {
        if (courseChanging_ > 0) {
            // おに⇔おに裏の切り替え中
            if (!CourseBoard("board_4")->IsPlay()) courseChanging_ = 0;
            return;
        }
        for (int p = 0; p < 2; ++p) {
            CoursePlayer& player = coursePlayer_[p];
            if (!player.joined || player.decided) continue;
            PlayOptionBoard& option = optionBoard_[p];
            if (timeUp_) {
                // 演奏オプションを開いていたら、いまの設定で閉じてから難易度を決める（lua: TimeUpOptionSequence）
                option.ForceClose();
                if (option.TakeClosed()) SaveOption(p);
                player.index = std::max(kIndexEasy, player.index);
                CourseDecide(p);
                continue;
            }
            // 演奏オプションを開いているあいだは、叩いた入力は板のほうで使う（lua: keyInput_1P の GetOpenOptionFlag）
            if (option.IsOpen()) {
                option.Step(input_[p].don, input_[p].kaLeft, input_[p].kaRight);
                if (option.TakeClosed()) SaveOption(p);
                continue;
            }
            if (input_[p].don) {
                CourseDecide(p);
                if (state_ != State::CourseMain) return;
            } else if (input_[p].kaRight) {
                PlaySe("katsu", p);
                CourseMove(p, 1);
            } else if (input_[p].kaLeft) {
                PlaySe("katsu", p);
                CourseMove(p, -1);
            }
        }
        bool all = true;
        for (const CoursePlayer& player : coursePlayer_) all = all && (!player.joined || player.decided);
        if (all) {
            timerRunning_ = false;
            if (playerCount_ >= 2) {
                SoundManager::Get().Play(kBankVoice, "select_difficulty_l");
                SoundManager::Get().Play(kBankVoice, "select_difficulty_r");
            } else {
                SoundManager::Get().PlaySlot(kBankVoice, "select_difficulty_c", kSlotVoice);
            }
            SetState(State::CourseDecide);
        }
        return;
    }

    case State::CourseDecide:
        // 難易度マークの決定アニメーションが終わるまで待つ
        for (int p = 0; p < 2; ++p) {
            if (coursePlayer_[p].joined && CourseBoard("mark_" + std::to_string(p + 1))->IsPlay()) return;
        }
        SetState(State::CourseWaitEnd);
        return;

    case State::CourseWaitEnd:
        if (stateFrame_ < kCourseEndWait) return;
        {
            PlayDataManager& pd = PlayDataManager::Get();
            pd.SetSelectedSong(Current().song->uniqueId, openGenre_);
            for (int p = 0; p < 2; ++p) pd.SetSelectedCourse(p, coursePlayer_[p].joined ? CourseValue(p) : 0);
        }
        Goto(stage_.Root(), "end_song_select", true);
        SoundManager::Get().StopPreview(0.5f);
        SceneManager::GetInstance().ChangeScene(std::make_unique<LoadingScene>(LoadingScene::Next::Enso), true);
        SetState(State::End);
        return;

    default:
        return;
    }
}

// 左右のふち（lua: MoveCursor）。右端で10回叩くと、裏譜面があればおに⇔おに裏を切り替える
void SongSelectScene::CourseMove(int p, int direction) {
    CoursePlayer& player = coursePlayer_[p];
    const int last = int(courseLabels_.size()) - 1;
    // 非活性の難易度（譜面がない）は飛ばす
    int next = player.index + direction;
    while (next >= 0 && next <= last && !CourseEnabled(next)) next += direction;
    bool limit = false;
    if (direction < 0) player.rightCount = 0;
    if (next > last) {
        next = player.index;
        limit = true;
        if (++player.rightCount >= kOpenUraCount) {
            player.rightCount = 0;
            const SongInfo& song = *Current().song;
            // おに⇔おに裏の切り替えは、両方の譜面があるときだけ
            if (song.stars[kCourseUra] > 0 && song.stars[kCourseOni] > 0) {
                uraShown_ = !uraShown_;
                Goto(CourseBoard("board_4"), uraShown_ ? "change_ura" : "change_oni", true);
                SoundManager::Get().Play(kBankSeSenkyoku, "appear_ura");
                courseChanging_ = 1;
                for (int i = 0; i < 2; ++i) {
                    if (coursePlayer_[i].joined && !coursePlayer_[i].decided) CourseCursor(i, false);
                }
            }
        }
    } else if (next < 0) {
        next = player.index;
        limit = true;
    }
    player.index = next;
    if (!limit) CourseCursor(p, true);
}

void SongSelectScene::CourseDecide(int p) {
    CoursePlayer& player = coursePlayer_[p];
    // 譜面のない難易度（TJA の曲で入っていない難易度）は選べない。時間切れのときは入っている難易度にする
    const SongInfo& song = *Current().song;
    if (player.index >= kIndexEasy && song.stars[size_t(CourseValue(p))] <= 0) {
        if (!timeUp_) return;
        for (int index = kIndexEasy; index <= kIndexOni; ++index) {
            if (CourseEnabled(index)) {
                player.index = index;
                break;
            }
        }
    }
    SoundManager::Get().Play(kBankSe, p == 0 ? "don_l" : "don_r");
    if (player.index == kIndexBack) {
        ReturnFromCourse();
        return;
    }
    if (player.index == kIndexOption) {
        OpenOption(p);
        return;
    }
    player.decided = true;
    const std::string side = std::to_string(p + 1);
    Goto(CourseBoard("course_frame_" + side + "/frame"), "choose", true);
    Goto(CourseBoard("mark_" + side), "course_decide_start", true);
}

// 「もどる」で曲選択に戻る（lua: CancelEnd → SongSelectAllMain / SongSelectSongMain "ReLoading"）
void SongSelectScene::ReturnFromCourse() {
    for (int p = 0; p < 2; ++p) {
        optionBoard_[p].ForceClose();
        if (optionBoard_[p].TakeClosed()) SaveOption(p);
    }
    PlaySe("primal_cancel", -1);
    Goto(main_, "change_songselect", true);
    if (timer_ <= 30.0f) timer_ = 30.0f;
    timerRunning_ = true;

    offsetType_ = 0;
    scrollDirection_ = 0;
    SetBoards();
    Goto(kanban_, "wait");
    Goto(boards_[0].genre, "select_on", true);
    Goto(boards_[0].song, "select_on", true);
    Goto(boards_[1].genre, "off", true);
    Goto(boards_[1].song, "off", true);
    focusOpen_ = true;
    Visible(guide_, true);
    inputEnable_ = false;
    SetState(State::SongMain);
}

// ===========================================================================
// 演奏オプション
// ===========================================================================
// 「演奏オプション」の板で面を叩いた（lua: keyInput_1P の kCourseOptionCard → Tween_SlideIn）
void SongSelectScene::OpenOption(int p) {
    optionBoard_[p].Open(PlayDataManager::Get().Player(p).options);
    if (playerCount_ >= 2) SoundManager::Get().Play(kBankVoice, "select_option_c");
    else SoundManager::Get().Play(kBankVoice, p == 0 ? "select_option_l" : "select_option_r");
}

void SongSelectScene::SaveOption(int p) {
    const PlayOptions options = optionBoard_[p].Options();
    PlayDataManager::Get().Player(p).options = options;
    PlayRecords::Get().SetOptions(record_[p].owner, options);
    SetOptionIcon(p);
}

// lua: SongSelectOptionMain:SetOptionIcon。はやさ・ドロン・あべこべ・ランダム・音符位置調整のうち、
// 初期値でないものを順に並べる（2P は右から）
void SongSelectScene::SetOptionIcon(int p) {
    Lumen::MovieClip* icon = optionIcon_[p];
    if (!icon) return;
    Goto(icon, "menu");
    for (int i = 0; i < 5; ++i) Goto(Sub(icon, "option/option" + std::to_string(i)), "none");
    const PlayOptions& options = PlayDataManager::Get().Player(p).options;
    static const char* const kSpeedLabels[PlayOptions::kSpeedCount] = {
        "", "speedx1.1", "speedx1.2", "speedx1.3", "speedx1.4", "speedx1.5", "speedx1.6", "speedx1.7",
        "speedx1.8", "speedx1.9", "speedx2", "speedx2.5", "speedx3", "speedx3.5", "speedx4"};
    std::vector<std::string> labels;
    if (options.speed > 0) labels.push_back(kSpeedLabels[std::clamp(options.speed, 0, PlayOptions::kSpeedCount - 1)]);
    if (options.doron) labels.push_back("doron");
    if (options.abekobe) labels.push_back("abekobe");
    if (options.random > 0) labels.push_back(options.random == 1 ? "kimagure" : "detarame");
    if (options.notePosition != 0) labels.push_back("note_pos");
    optionCount_[p] = int(labels.size());
    for (size_t i = 0; i < labels.size(); ++i) {
        const int slot = p == 1 ? 4 - int(i) : int(i);
        Goto(Sub(icon, "option/option" + std::to_string(slot)), labels[i]);    }
}

// ===========================================================================
// 音
// ===========================================================================
// 開いた看板の音を流す。ジャンルと「もどる」は選曲の BGM、曲はその曲のプレビュー（lua: UpdateSound）
void SongSelectScene::PlayFocusSound() {
    SoundManager& sound = SoundManager::Get();
    const Panel& panel = Current();
    if (panel.type == Panel::Type::Song) {
        sound.SetVolumeSlot(kSlotBgm, -90.0f, 0.33f);
        sound.PlayPreview(panel.song->SoundBank(), 0.5f);
    } else {
        sound.StopPreview(0.33f);
        if (!sound.IsSlotPlaying(kSlotBgm)) sound.PlaySlot(kBankBgm, "primal_loop", kSlotBgm);
        sound.SetVolumeSlot(kSlotBgm, 0.0f, 0.3f);
    }
}

// 選んでいる看板が変わったら今の曲を止める（lua: StopSound。同じ BGM なら続ける）
void SongSelectScene::StopFocusSound() {
    const Panel& panel = Current();
    SoundManager& sound = SoundManager::Get();
    if (panel.type == Panel::Type::Song) {
        if (sound.PreviewBank() != panel.song->SoundBank()) sound.StopPreview(0.33f);
        sound.SetVolumeSlot(kSlotBgm, -90.0f, 0.33f);
    } else {
        sound.StopPreview(0.33f);
    }
}

// 1人なら中央、2人なら叩いた側から鳴らす（lua: PlaySeDon など）
void SongSelectScene::PlaySe(const std::string& tone, int player) const {
    std::string suffix = "_c";
    if (tone == "don_big") suffix.clear();
    else if (playerCount_ >= 2 && player >= 0) suffix = player == 0 ? "_l" : "_r";
    SoundManager::Get().Play(kBankSe, tone + suffix);
}

// ===========================================================================
// 描画
// ===========================================================================
void SongSelectScene::Draw() {
    ClearBackground(BLACK);
    if (!loaded_) {
        DrawText("song select: failed to load", 40, 40, 40, RAYWHITE);
        return;
    }
    RenderDons();
    stage_.Draw();
    // オートのマーク: 演奏オプションのアイコンと同じ大きさで、並んでいるアイコンの次のところに出す
    //   （アイコンは 43px おき。1P は左から、2P は右から詰める。位置は、アイコンの部品の座標に画面の左上までのずれを足す）
    for (int p = 0; p < 2; ++p) {
        if (!joined_[p] || !optionIcon_[p]) continue;
        const int slot = p == 1 ? 4 - optionCount_[p] : optionCount_[p];
        const Vector2 base = optionIcon_[p]->Position();
        CommonParts::DrawAutoBadge(base.x + 941.0f + 43.0f * float(slot), base.y + 521.0f + 19.0f, 1.0f);
    }
}

// 3D のどんちゃんを差し込み枠用のテクスチャに描く（lua: Don.SetLoopAnimation(…, "result_clear_loop")）
void SongSelectScene::RenderDons() {
    if (!don3d_.IsLoaded()) return;
    donAnim_.Apply(don3d_);

    Camera3D camera{};
    camera.target = Vector3{0.0f, 0.14f, 0.0f};
    camera.position = Vector3{0.0f, 0.2f, 1.7f};
    camera.up = Vector3{0.0f, 1.0f, 0.0f};
    camera.fovy = 2.0f * 1.7f * std::tan(11.0f * DEG2RAD);
    camera.projection = CAMERA_ORTHOGRAPHIC;

    for (int p = 0; p < 2; ++p) {
        if (donTexture_[p].id == 0 || !joined_[p]) continue;
        BeginTextureMode(donTexture_[p]);
        ClearBackground(Color{0, 0, 0, 0});
        BeginMode3D(camera);
        don3d_.Draw(p, don3d_.Expression(), MatrixRotateY((p == 0 ? 30.0f : -30.0f) * DEG2RAD));
        EndMode3D();
        EndTextureMode();
    }
}
