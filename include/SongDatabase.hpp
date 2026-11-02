#pragma once
#include <array>
#include <string>
#include <vector>

// 楽曲とジャンルの情報
//   musicinfo.bin        … 曲ごとの情報（ジャンル、難易度の★、分岐の有無など）
//   music_order.bin      … ジャンルごとの曲の並び順
//   music_attribute.bin  … 新曲フラグなど
//   genre_folderinfo.bin … ジャンルフォルダ（並び順、フォーカス時のボイス）
// 曲名は wordlist の "song_<id>" / "song_sub_<id>" / "song_detail_<id>"。
// Songs フォルダ（下のフォルダも含む）の TJA も曲として並べる（id は "tja0001" など。ジャンルは GENRE: などから決める）。
// ジャンルフォルダの中の並びは datatable/songs_index/<ジャンル>.json（インデックスの大きい順）。
// その曲名と一致する TJA を Data/x64/fumen から探して使う（Songs の本家の譜面は一覧に出さない）。
// どちらにもなければサンプルの譜面（datatable/sample/sample.tja）の曲として並べる。
namespace GuminTaiko {

// 難易度（lua: EnsoLevelType / C++ 側のコース番号）
enum Course { kCourseEasy = 0, kCourseNormal, kCourseHard, kCourseOni, kCourseUra, kCourseCount };

// ジャンルの番号（SongInfo::genreNo）。0: pops 1: anime 2: kids 3: vocaloid 4: game（ゲームミュージック）5: namco 6: バラエティ 7: クラシック
//   8: 創作譜面（本家の譜面とは別に、自作の譜面を入れる Songs/創作譜面 フォルダ）
constexpr int kGenreVariety = 6;
constexpr int kGenreClassic = 7;
constexpr int kGenreCustom = 8;
constexpr int kGenreCount = kGenreCustom + 1;
// 「むずかしさをえらぶ」フォルダ。中に ★1〜★10 のフォルダが並び、その★の譜面（かんたん〜おに裏のどれか）がある曲が入る。
// ジャンルの番号は、ふつうのジャンルとは別（root は kGenreLevelRoot、★N のフォルダは kGenreLevelBase + N）
// 「お気に入り」と「最近遊んだ曲」のフォルダ。曲はプレイヤーごとの記録（PlayRecords）から並べる。ジャンルの番号は通常のジャンルとは別
constexpr int kGenreRecent = 95;
constexpr int kGenreFavorite = 96;
constexpr int kGenreLevelRoot = 99;
constexpr int kGenreLevelBase = 100;
constexpr int kLevelFolderMax = 10;

struct SongInfo {
    std::string id;            // "10tai" など
    int uniqueId = -1;
    int genreNo = 0;           // 0: pops 1: anime 2: kids 3: vocaloid 4: game 5: namco 6: バラエティ 7: クラシック 8: 創作譜面
    std::array<int, kCourseCount> stars{};
    std::array<bool, kCourseCount> branch{};
    std::array<int, kCourseCount> shinuti{};   // 真打の配点（良1つの点数）
    bool papamama = false;
    bool isNew = false;
    bool closeDispType = false;   // 閉じた板では曲名とサブ表記を入れ替える
    std::string tjaPath;          // TJA の譜面の曲（Songs フォルダ）なら、その TJA のパス（UTF-8）
    bool fromFumen = false;       // Data/x64/fumen の TJA（songs_index の曲名と一致したときに使う）
    // TJA が見つからない songs_index の曲。ジャンルフォルダには並べ、遊ぶとサンプルの譜面（kSampleTja）を流す。記録は残さない
    bool sample = false;
    std::string soundId;          // 音の名前（空なら id。サンプルの曲はみな同じ音を使う）
    // プレイの記録に使う id（空なら id）。fumen の TJA が同じ曲名の Songs の TJA の代わりに並ぶときは、
    // その Songs の曲の id を入れて、これまでの記録（スコア・王冠）をそのまま引き継ぐ
    std::string recordId;
    const std::string& RecordId() const { return recordId.empty() ? id : recordId; }

    bool IsTja() const { return !tjaPath.empty(); }
    std::string SoundBank() const { return "song_" + (soundId.empty() ? id : soundId); }
};

struct GenreInfo {
    int uniqueId = -1;
    std::string id;            // "pops" など
    int order = 0;
    std::string voiceTone;     // フォーカスしたときのボイス（voice_senkuoku_v12a）
    int genreNo = -1;          // 通常のジャンルなら 0〜8、それ以外は -1
    int level = 0;             // 「むずかしさをえらぶ」の中の ★N のフォルダなら N（それ以外は 0）
    bool levelRoot = false;    // 「むずかしさをえらぶ」のフォルダ
};

class SongDatabase {
public:
    static SongDatabase& Get() {
        static SongDatabase instance;
        return instance;
    }

    // 選曲画面に並べるジャンル（曲が入っている通常のジャンルだけ。並び順どおり）
    const std::vector<GenreInfo>& Genres();
    // 「むずかしさをえらぶ」の中の ★1〜★10 のフォルダ（曲が入っているものだけ。★の小さい順）
    const std::vector<GenreInfo>& LevelFolders();
    // ジャンルに入っている曲（music_order の並び順）
    const std::vector<const SongInfo*>& SongsInGenre(int genreNo);
    const SongInfo* FindSong(int uniqueId);
    // 記録の id（SongInfo::RecordId）の並びから曲を引く（お気に入り・最近遊んだ曲。なくなった曲は飛ばす。並びはそのまま）
    std::vector<const SongInfo*> SongsByRecordIds(const std::vector<std::string>& ids);
    // fumen からの相対パス（"曲名.tja"）の TJA の曲（段位道場のお題が使う。Songs からの相対パスも探す）
    const SongInfo* FindSongByTja(const std::string& relative);
    static std::string TjaRelativePath(const SongInfo& song);
    const std::vector<SongInfo>& AllSongs();

    static const char* GenreIdFromNo(int genreNo);
    // ジャンル名の文言のキー（wordlist の genre_pops / genre_vocalo など。バラエティは genre_event3）
    static const char* GenreTextKey(int genreNo);
    // ジャンルの色の板のラベル（演奏画面の song_info、アトラクトの曲紹介は6色しかない）。
    // バラエティ・クラシック・創作譜面は白っぽいボーカロイドの板を GenrePlateTint の色に染めて使う
    static const char* GenrePlateLabel(int genreNo);
    // ジャンルの色の板に掛ける色（乗算。染めないジャンルは白）
    static std::array<float, 3> GenrePlateTint(int genreNo);

private:
    SongDatabase() = default;
    void Load();
    void LoadTjaSongs();
    void LoadFumenSongs();
    void BuildGenreOrder();

    bool loaded_ = false;
    std::vector<SongInfo> songs_;
    std::vector<GenreInfo> genres_;
    std::vector<std::vector<const SongInfo*>> order_;
    std::vector<GenreInfo> levelFolders_;
    std::vector<std::vector<const SongInfo*>> levelSongs_;   // ★N の曲（levelFolders_ と同じ順）
};

} // namespace GuminTaiko
