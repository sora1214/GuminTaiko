#include "SongDatabase.hpp"

#include <algorithm>
#include <array>
#include <cctype>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <map>
#include <sstream>
#include <system_error>

#include "DataTable.hpp"
#include "Json.hpp"
#include "SoundManager.hpp"
#include "Tja.hpp"
#include "WordList.hpp"
#include "raylib.h"

namespace GuminTaiko {

namespace {

constexpr const char* kTableDir = "Data/x64/datatable/";
// ジャンルの id（選曲画面などのムービーのラベル名）。
// ニジイロの「ゲーム＆バラエティ」（game・紫）はゲームミュージックとして使い、バラエティは分ける。
// バラエティは本家のデータに特集フォルダとして入っている event3（緑、文言「バラエティ」）の絵を使う。
// クラシックはニジイロにないジャンルなので、同じく特集フォルダの event4（黄色）の絵を使う。
// 創作譜面（自作の譜面のフォルダ）は、選曲画面では使っていない dani（紺色）の絵を使う
constexpr const char* kGenreIds[kGenreCount] = {"pops", "anime", "kids", "vocaloid", "game", "namco", "event3", "event4", "dani"};
constexpr const char* kTjaDir = "Songs";
// Songs 直下のジャンルフォルダ（kGenreIds と同じ順。名前はゲーム内のジャンル名）
constexpr const char* kGenreFolders[kGenreCount] = {"ポップス", "アニメ", "キッズ", "ボーカロイド曲", "ゲームミュージック", "ナムコオリジナル",
                                                    "バラエティ", "クラシック", "創作譜面"};
constexpr const char* kGameTitle = "ゲームミュージック";
constexpr const char* kVarietyTitle = "バラエティ";
constexpr const char* kClassicTitle = "クラシック";
constexpr const char* kCustomTitle = "創作譜面";
constexpr int kTjaUniqueIdBase = 100000;   // 本家の曲のユニーク ID と重ならない番号

// TJA のジャンル（GENRE: やフォルダ名）を、このゲームのジャンルに読み替える。わからなければポップス
int GenreFromText(const std::string& text) {
    std::string upper = text;
    std::transform(upper.begin(), upper.end(), upper.begin(), [](char c) { return char(std::toupper(static_cast<unsigned char>(c))); });
    struct Rule {
        int genre;
        std::vector<const char*> words;
    };
    static const std::vector<Rule> kRules = {
        {3, {"ボーカロイド", "ボカロ", "VOCALOID"}},
        {1, {"アニメ", "ANIME"}},
        {2, {"キッズ", "どうよう", "童謡", "KIDS"}},
        {4, {"ゲーム", "GAME"}},   // 「ゲーム＆バラエティ」もゲームミュージックに入れる
        {kGenreVariety, {"バラエティ", "VARIETY"}},
        {kGenreCustom, {"創作"}},
        {kGenreClassic, {"クラシック", "CLASSIC"}},
        {5, {"ナムコ", "NAMCO"}},
        {0, {"ポップス", "J-POP", "POP"}},
    };
    for (const Rule& rule : kRules) {
        for (const char* word : rule.words) {
            if (upper.find(word) != std::string::npos) return rule.genre;
        }
    }
    return 0;
}

constexpr const char* kFumenDir = "Data/x64/fumen";
constexpr const char* kFumenSoundDir = "Data/x64/sound";   // fumen の TJA の音源（ogg）を置くフォルダ
constexpr int kFumenUniqueIdBase = 200000;   // fumen の TJA の曲のユニーク ID（Songs の TJA と重ならない番号）
// TJA が見つからない曲を遊んだときのサンプルの譜面（音は全部の曲で共通の "song_sample"）
constexpr const char* kSampleTja = "Data/x64/datatable/sample/sample.tja";
constexpr const char* kSampleSound = "sample";
constexpr int kSampleUniqueIdBase = 300000;
constexpr int kCustomUniqueIdBase = 400000;   // 創作譜面のユニーク ID
// ジャンルフォルダの中の曲の並び（<ジャンル>.json。kGenreIds と同じ順）
constexpr const char* kSongIndexDir = "Data/x64/datatable/songs_index";
constexpr const char* kSongIndexFiles[kGenreCount] = {"ポップス", "アニメ", "キッズ", "ボーカロイド", "ゲームミュージック",
                                                      "ナムコオリジナル", "バラエティ", "クラシック", "創作譜面"};

// フォルダの中（下のフォルダも含む）の TJA をファイル名の順に
std::vector<std::filesystem::path> TjaFiles(const char* dir) {
    namespace fs = std::filesystem;
    std::vector<fs::path> files;
    std::error_code ec;
    if (!fs::is_directory(dir, ec)) return files;
    for (fs::recursive_directory_iterator it(dir, fs::directory_options::skip_permission_denied, ec), end; it != end;
         it.increment(ec)) {
        if (ec) break;
        std::string extension = it->path().extension().u8string();
        std::transform(extension.begin(), extension.end(), extension.begin(), [](char c) { return char(std::tolower(c)); });
        if (it->is_regular_file(ec) && extension == ".tja") files.push_back(it->path());
    }
    std::sort(files.begin(), files.end());
    return files;
}

bool ReadTja(const std::filesystem::path& file, TjaInfo& info) {
    std::string error;
    if (ReadTjaInfo(file.u8string(), info, &error)) return true;
    TraceLog(LOG_WARNING, "SongDatabase: %s", error.c_str());
    return false;
}

// 曲名・難易度・音を登録する（id は決めてから呼ぶ）
void RegisterTjaSong(const std::filesystem::path& file, const TjaInfo& info, SongInfo& song) {
    song.tjaPath = file.u8string();
    for (int c = 0; c < kCourseCount; ++c) {
        song.stars[size_t(c)] = info.levels[size_t(c)];
        song.branch[size_t(c)] = info.branch[size_t(c)];
    }
    WordList::Get().Set("song_" + song.id, info.title);
    WordList::Get().Set("song_sub_" + song.id, info.subtitle);
    WordList::Get().Set("song_detail_" + song.id, "");
    if (!info.wave.empty()) SoundManager::Get().RegisterSongFile(song.SoundBank(), info.wave, float(info.demoStart));
}

// fumen の TJA の音源。TJA は Data/x64/fumen、音源（ogg など）は Data/x64/sound に分けて置いてあるので、
//   TJA の隣（WAVE: のとおり）→ sound フォルダの WAVE: のファイル名 → sound フォルダの「TJA のファイル名.ogg など」の順に探す
std::string FumenWave(const std::filesystem::path& tja, const std::string& wave) {
    namespace fs = std::filesystem;
    std::error_code ec;
    if (!wave.empty() && fs::is_regular_file(fs::u8path(wave), ec)) return wave;
    const fs::path soundDir = kFumenSoundDir;
    if (!wave.empty()) {
        const fs::path byName = soundDir / fs::u8path(wave).filename();
        if (fs::is_regular_file(byName, ec)) return byName.u8string();
    }
    for (const char* extension : {".ogg", ".wav", ".mp3"}) {
        fs::path byStem = soundDir / tja.stem();
        byStem += extension;
        if (fs::is_regular_file(byStem, ec)) return byStem.u8string();
    }
    TraceLog(LOG_WARNING, "SongDatabase: 音源が見つかりません: %s", tja.u8string().c_str());
    return std::string();
}

// パスから決まる番号（FNV-1a）
unsigned PathHash(const std::string& text) {
    unsigned hash = 2166136261u;
    for (const unsigned char c : text) {
        hash ^= c;
        hash *= 16777619u;
    }
    return hash;
}

// 曲名を比べるための形。全角の英数字・記号と全角スペースは半角に、英字は小文字にし、
// ファイル名に使えない文字（\ / : * ? " < > |）と空白を除く（ファイル名と曲名を比べられるように）。波ダッシュは ~ にそろえる
std::string NormalizeTitle(const std::string& text) {
    std::string out;
    for (size_t i = 0; i < text.size();) {
        const unsigned char c = static_cast<unsigned char>(text[i]);
        unsigned cp = c;
        int bytes = 1;
        if (c >= 0xF0 && i + 3 < text.size()) {
            cp = ((c & 0x07u) << 18) | ((text[i + 1] & 0x3Fu) << 12) | ((text[i + 2] & 0x3Fu) << 6) | (text[i + 3] & 0x3Fu);
            bytes = 4;
        } else if (c >= 0xE0 && i + 2 < text.size()) {
            cp = ((c & 0x0Fu) << 12) | ((text[i + 1] & 0x3Fu) << 6) | (text[i + 2] & 0x3Fu);
            bytes = 3;
        } else if (c >= 0xC0 && i + 1 < text.size()) {
            cp = ((c & 0x1Fu) << 6) | (text[i + 1] & 0x3Fu);
            bytes = 2;
        }
        const std::string original = text.substr(i, size_t(bytes));
        i += size_t(bytes);
        if (cp >= 0xFF01 && cp <= 0xFF5E) cp -= 0xFEE0;   // 全角 → 半角
        if (cp == 0x3000) cp = ' ';
        if (cp == 0x301C) cp = '~';
        if (cp < 0x80) {
            const char ascii = char(std::tolower(int(cp)));
            if (std::strchr("\\/:*?\"<>| \t", ascii)) continue;
            out += ascii;
        } else {
            out += original;
        }
    }
    return out;
}

// 記号の違いを無視して比べるための形（NormalizeTitle の結果から、記号をすべて除く）。
//   songs_index の曲名とファイル名で「‐ と -」「’ と '」「♡ と ・」のように記号だけが違う曲を見つける
std::string LooseTitle(const std::string& normalized) {
    std::string out;
    for (size_t i = 0; i < normalized.size();) {
        const unsigned char c = static_cast<unsigned char>(normalized[i]);
        unsigned cp = c;
        int bytes = 1;
        if (c >= 0xF0 && i + 3 < normalized.size()) {
            cp = ((c & 0x07u) << 18) | ((normalized[i + 1] & 0x3Fu) << 12) | ((normalized[i + 2] & 0x3Fu) << 6) | (normalized[i + 3] & 0x3Fu);
            bytes = 4;
        } else if (c >= 0xE0 && i + 2 < normalized.size()) {
            cp = ((c & 0x0Fu) << 12) | ((normalized[i + 1] & 0x3Fu) << 6) | (normalized[i + 2] & 0x3Fu);
            bytes = 3;
        } else if (c >= 0xC0 && i + 1 < normalized.size()) {
            cp = ((c & 0x1Fu) << 6) | (normalized[i + 1] & 0x3Fu);
            bytes = 2;
        }
        const bool symbol = cp < 0x80 ? !std::isalnum(int(cp))
                                      : (cp >= 0xA0 && cp <= 0xBF) || (cp >= 0x2000 && cp <= 0x206F) || (cp >= 0x2190 && cp <= 0x2BFF) ||
                                            (cp >= 0x3000 && cp <= 0x303F) || cp == 0x30FB || (cp >= 0xFF00 && cp <= 0xFF65) ||
                                            (cp >= 0x1F000 && cp <= 0x1FAFF);
        if (!symbol) out.append(normalized, i, size_t(bytes));
        i += size_t(bytes);
    }
    return out;
}

// songs_index の曲（1つ）
struct IndexEntry {
    int index = 0;
    std::string title;
    std::string composer;
    std::array<int, kCourseCount> stars{};   // 「-」（その難易度がない）は 0
};

// songs_index/<ジャンル>.json を読む
//   [{"インデックス": 1, "曲名": "…", "作曲者": "…", "各難易度の星の数": {"かんたん": "3", …, "おに裏": "-"}}, …]
bool LoadSongIndex(const std::filesystem::path& file, std::vector<IndexEntry>& entries) {
    std::ifstream in(file, std::ios::binary);
    if (!in) return false;
    std::stringstream buffer;
    buffer << in.rdbuf();
    std::string text = buffer.str();
    if (text.compare(0, 3, "\xEF\xBB\xBF") == 0) text.erase(0, 3);
    Json::Value root;
    std::string error;
    if (!Json::Parse(text, root, &error) || !root.IsArray()) {
        TraceLog(LOG_WARNING, "SongDatabase: %s を読めません（%s）", file.u8string().c_str(), error.c_str());
        return false;
    }
    static const char* const kCourseNames[kCourseCount] = {"かんたん", "ふつう", "むずかしい", "おに", "おに裏"};
    for (const Json::Value& item : root.Items()) {
        IndexEntry entry;
        entry.title = item["曲名"].AsString();
        if (entry.title.empty()) continue;
        entry.index = item["インデックス"].AsInt();
        entry.composer = item["作曲者"].AsString();
        const Json::Value& stars = item["各難易度の星の数"];
        for (int c = 0; c < kCourseCount; ++c) {
            const Json::Value& value = stars[kCourseNames[c]];
            entry.stars[size_t(c)] = value.GetType() == Json::Value::Type::Number ? value.AsInt() : std::atoi(value.AsString().c_str());
        }
        entries.push_back(std::move(entry));
    }
    return true;
}

} // namespace

const char* SongDatabase::GenreIdFromNo(int genreNo) {
    return genreNo >= 0 && genreNo < kGenreCount ? kGenreIds[genreNo] : "";
}

const char* SongDatabase::GenreTextKey(int genreNo) {
    static const char* const kKeys[kGenreCount] = {"genre_pops", "genre_anime", "genre_kids", "genre_vocalo",
                                                   "genre_game", "genre_namco", "genre_event3", "genre_event4", "genre_dani"};
    return genreNo >= 0 && genreNo < kGenreCount ? kKeys[genreNo] : "genre_pops";
}

const char* SongDatabase::GenrePlateLabel(int genreNo) {
    static const char* const kLabels[kGenreCount] = {"pops", "anime", "kids", "vocalo", "game", "namco", "vocalo", "vocalo", "vocalo"};
    return genreNo >= 0 && genreNo < kGenreCount ? kLabels[genreNo] : "none";
}

std::array<float, 3> SongDatabase::GenrePlateTint(int genreNo) {
    if (genreNo == kGenreVariety) return {0.45f, 0.95f, 0.45f};   // 緑
    if (genreNo == kGenreClassic) return {1.0f, 0.85f, 0.2f};     // 黄色（選曲の看板 event4 の色）
    if (genreNo == kGenreCustom) return {0.45f, 0.55f, 0.95f};    // 紺色（選曲の看板 dani の色）
    return {1.0f, 1.0f, 1.0f};
}

const std::vector<GenreInfo>& SongDatabase::Genres() {
    if (!loaded_) Load();
    return genres_;
}

const std::vector<const SongInfo*>& SongDatabase::SongsInGenre(int genreNo) {
    static const std::vector<const SongInfo*> kEmpty;
    if (!loaded_) Load();
    if (genreNo >= kGenreLevelBase) {
        for (size_t i = 0; i < levelFolders_.size(); ++i) {
            if (levelFolders_[i].genreNo == genreNo) return levelSongs_[i];
        }
        return kEmpty;
    }
    return genreNo >= 0 && size_t(genreNo) < order_.size() ? order_[size_t(genreNo)] : kEmpty;
}

const std::vector<GenreInfo>& SongDatabase::LevelFolders() {
    if (!loaded_) Load();
    return levelFolders_;
}

const SongInfo* SongDatabase::FindSong(int uniqueId) {
    if (!loaded_) Load();
    for (const SongInfo& song : songs_) {
        if (song.uniqueId == uniqueId) return &song;
    }
    return nullptr;
}

// 段位のお題の曲を探す。relative は fumen（Data/x64/fumen）の TJA の相対パス（"曲名.tja"）。
// 古いお題の Songs からの相対パス（"ナムコオリジナル/…/曲.tja"）は、同じファイル名の TJA が fumen にあればそちらを使う。
// どちらにもなければ、Songs の TJA（創作譜面など）を探す
const SongInfo* SongDatabase::FindSongByTja(const std::string& relative) {
    if (!loaded_) Load();
    namespace fs = std::filesystem;
    auto normal = [](const fs::path& path) { return path.lexically_normal().generic_u8string(); };
    const std::string wantFumen = normal(fs::path(kFumenDir) / fs::u8path(relative));
    const std::string wantSongs = normal(fs::path(kTjaDir) / fs::u8path(relative));
    const std::string name = fs::u8path(relative).filename().u8string();
    const SongInfo* byName = nullptr;
    const SongInfo* inSongs = nullptr;
    for (const SongInfo& song : songs_) {
        if (!song.IsTja() || song.sample) continue;
        const std::string have = normal(fs::u8path(song.tjaPath));
        if (song.fromFumen) {
            if (have == wantFumen) return &song;
            if (!byName && fs::u8path(song.tjaPath).filename().u8string() == name) byName = &song;
        } else if (!inSongs && have == wantSongs) {
            inSongs = &song;
        }
    }
    return byName ? byName : inSongs;
}

// お題に書く TJA の相対パス。fumen の曲は fumen からの、Songs の曲（創作譜面）は Songs からの
std::string SongDatabase::TjaRelativePath(const SongInfo& song) {
    namespace fs = std::filesystem;
    return fs::u8path(song.tjaPath).lexically_relative(song.fromFumen ? kFumenDir : kTjaDir).generic_u8string();
}

const std::vector<SongInfo>& SongDatabase::AllSongs() {
    if (!loaded_) Load();
    return songs_;
}

void SongDatabase::Load() {
    loaded_ = true;

    // ---- 曲 ----
    // 曲は Songs フォルダの TJA だけを使う（Data の本家の曲 musicinfo / music_order は読み込まない）
    LoadTjaSongs();
    LoadFumenSongs();
    BuildGenreOrder();

    // ---- ジャンル（並び順とフォーカスしたときのボイスは本家の genre_folderinfo を使う） ----
    for (const DataTable::Item& item : DataTable::Load(std::string(kTableDir) + "genre_folderinfo.bin")) {
        GenreInfo genre;
        genre.uniqueId = item.Int("uniqueId", -1);
        genre.id = item.Text("id");
        genre.order = item.Int("order");
        genre.voiceTone = item.Text("vo_toneId");
        for (int g = 0; g < kGenreCount; ++g) {
            if (genre.id == kGenreIds[g]) genre.genreNo = g;
        }
        // イベント・お気に入りなどのフォルダは中身を組み立てられないので出さない。曲の入っていないジャンルも出す
        // バラエティ・クラシックの特集フォルダ（event3 / event4）は下で自分で足す
        if (genre.genreNo < 0 || genre.genreNo == kGenreVariety || genre.genreNo == kGenreClassic || genre.genreNo == kGenreCustom) continue;
        genres_.push_back(std::move(genre));
    }
    // バラエティは genre_folderinfo にないので、ゲームミュージックのすぐ後ろに置く
    {
        GenreInfo variety;
        variety.uniqueId = 106;
        variety.id = kGenreIds[kGenreVariety];
        variety.order = 4050;
        variety.voiceTone = "focus_variety_loop";
        variety.genreNo = kGenreVariety;
        genres_.push_back(std::move(variety));
    }
    // クラシックも genre_folderinfo にないので、ナムコオリジナルのすぐ前に置く
    {
        GenreInfo classic;
        classic.uniqueId = 107;
        classic.id = kGenreIds[kGenreClassic];
        classic.order = 5999;
        for (const GenreInfo& genre : genres_) {
            if (genre.genreNo == 5) classic.order = genre.order - 1;
        }
        classic.voiceTone = "focus_classic_loop";
        classic.genreNo = kGenreClassic;
        genres_.push_back(std::move(classic));
    }
    // 創作譜面（Songs/創作譜面 の TJA）はいちばん最後に置く。読み上げるボイスはない
    //   ジャンルは輪になっていて、最初に選ばれているポップス（order がいちばん大きい）から下へ アニメ … キッズ と並ぶので、
    //   ポップスのすぐ前（キッズの次）に入れる
    {
        GenreInfo custom;
        custom.uniqueId = 108;
        custom.id = kGenreIds[kGenreCustom];
        for (const GenreInfo& genre : genres_) custom.order = std::max(custom.order, genre.order + 1);
        for (const GenreInfo& genre : genres_) {
            if (genre.genreNo == 0) custom.order = genre.order - 1;
        }
        custom.genreNo = kGenreCustom;
        genres_.push_back(std::move(custom));
    }
    // ゲーム＆バラエティをゲームミュージックとバラエティに分けたので、ジャンル名を差し替える
    WordList::Get().Set("folder_game", kGameTitle);
    WordList::Get().Set("genre_game", kGameTitle);
    WordList::Get().Set("genre_event3", kVarietyTitle);
    WordList::Get().Set("folder_event4", kClassicTitle);
    WordList::Get().Set("genre_event4", kClassicTitle);
    WordList::Get().Set("folder_dani", kCustomTitle);
    WordList::Get().Set("genre_dani", kCustomTitle);
    // 「むずかしさをえらぶ」（ジャンルの一覧の、ポップスのあと）
    {
        GenreInfo root;
        root.uniqueId = 109;
        root.id = "difficulty";
        root.order = 7500;
        root.voiceTone = "focus_recent_loop";
        root.genreNo = kGenreLevelRoot;
        root.levelRoot = true;
        genres_.push_back(std::move(root));
    }
    WordList::Get().Set("folder_difficulty", "むずかしさをえらぶ");
    WordList::Get().Set("folder_intro_difficulty", "★の数からすきな曲をえらべるよ！");
    std::sort(genres_.begin(), genres_.end(), [](const GenreInfo& a, const GenreInfo& b) { return a.order < b.order; });

    // ★N のフォルダ。曲は、ジャンルの並び順 → ジャンルの中の並び順。かんたん〜おに裏のどれかが★N の曲を入れる
    levelFolders_.clear();
    levelSongs_.clear();
    levelFolders_.reserve(kLevelFolderMax);
    for (int level = 1; level <= kLevelFolderMax; ++level) {
        std::vector<const SongInfo*> songs;
        for (const GenreInfo& genre : genres_) {
            if (genre.genreNo < 0 || genre.genreNo >= kGenreCount) continue;
            for (const SongInfo* song : order_[size_t(genre.genreNo)]) {
                bool has = false;
                for (int c = 0; c < kCourseCount; ++c) has = has || song->stars[size_t(c)] == level;
                if (has && std::find(songs.begin(), songs.end(), song) == songs.end()) songs.push_back(song);
            }
        }
        if (songs.empty()) continue;
        GenreInfo folder;
        folder.uniqueId = 200 + level;
        folder.id = "level" + std::to_string(level);
        folder.order = 7500 + level;
        folder.voiceTone = "focus_recent_loop";
        folder.genreNo = kGenreLevelBase + level;
        folder.level = level;
        levelFolders_.push_back(std::move(folder));
        levelSongs_.push_back(std::move(songs));
        WordList::Get().Set("folder_level" + std::to_string(level), "★" + std::to_string(level));
        WordList::Get().Set("folder_intro_level" + std::to_string(level), "★" + std::to_string(level) + "の曲をあつめたよ！");
    }
    // ジャンルの看板の説明は「<ジャンル名>の曲をあつめたよ!」（本家の看板。名前が「曲」で終わるものは「<名前>をあつめたよ!」）
    for (const GenreInfo& genre : genres_) {
        if (genre.levelRoot) continue;   // 「むずかしさをえらぶ」は専用の説明文
        const std::string name = WordList::Get().Text("folder_" + genre.id);
        const std::string suffix = "曲";
        const bool endsWithSong = name.size() >= suffix.size() && name.compare(name.size() - suffix.size(), suffix.size(), suffix) == 0;
        WordList::Get().Set("folder_intro_" + genre.id, name + (endsWithSong ? "" : "の曲") + "をあつめたよ!");
    }

    TraceLog(LOG_INFO, "SongDatabase: 曲 %zu / ジャンル %zu", songs_.size(), genres_.size());
}

// Songs フォルダの TJA を曲として加える。曲名は wordlist に、音声は SoundManager に、曲の id で登録する
//   ジャンルは Songs 直下のジャンルフォルダ（kGenreFolders）で決める。
//   それ以外の場所の TJA は GENRE: などから読み替える（わからなければポップス）
void SongDatabase::LoadTjaSongs() {
    namespace fs = std::filesystem;
    std::error_code ec;
    // ジャンルフォルダがなければ作っておく
    for (const char* folder : kGenreFolders) fs::create_directories(fs::path(kTjaDir) / fs::u8path(folder), ec);
    if (!fs::is_directory(kTjaDir, ec)) return;

    const std::vector<fs::path> files = TjaFiles(kTjaDir);

    int count = 0, custom = 0;
    for (const fs::path& file : files) {
        TjaInfo info;
        if (!ReadTja(file, info)) continue;
        SongInfo song;
        song.genreNo = -1;
        const fs::path relative = file.lexically_relative(kTjaDir);
        if (std::distance(relative.begin(), relative.end()) >= 2) {
            const std::string top = relative.begin()->u8string();
            for (int g = 0; g < kGenreCount; ++g) {
                if (top == kGenreFolders[g]) song.genreNo = g;
            }
        }
        if (song.genreNo == kGenreCustom) {
            // 創作譜面の id はフォルダからのパスで決める（"cst" + 8桁。譜面を足したり消したりしても、ほかの曲の記録がずれない）
            song.id = TextFormat("cst%08x", PathHash(relative.generic_u8string()));
            song.uniqueId = kCustomUniqueIdBase + custom;
            ++custom;
        } else {
            // id は Songs の TJA のファイル名の順（プレイの記録と音の変換結果がこの id で残っているので変えない）
            song.id = TextFormat("tja%04d", count + 1);
            song.uniqueId = kTjaUniqueIdBase + count;
            ++count;
        }
        if (song.genreNo < 0) song.genreNo = GenreFromText(info.genre);
        RegisterTjaSong(file, info, song);
        songs_.push_back(std::move(song));
    }
    TraceLog(LOG_INFO, "SongDatabase: TJA の曲 %d・創作譜面 %d", count, custom);
}

// Data/x64/fumen の TJA（下のフォルダも含む）を曲として加える。ジャンルフォルダには songs_index の曲名と一致したときだけ並ぶ
//   id は fumen フォルダからのパスで決める（"fmn" + 8桁。TJA を足したり消したりしても、ほかの曲の記録がずれない）
void SongDatabase::LoadFumenSongs() {
    namespace fs = std::filesystem;
    const std::vector<fs::path> files = TjaFiles(kFumenDir);
    int count = 0;
    for (const fs::path& file : files) {
        TjaInfo info;
        if (!ReadTja(file, info)) continue;
        SongInfo song;
        song.id = TextFormat("fmn%08x", PathHash(file.lexically_relative(kFumenDir).generic_u8string()));
        song.uniqueId = kFumenUniqueIdBase + count;
        song.genreNo = GenreFromText(info.genre);   // songs_index のジャンルが決まれば BuildGenreOrder で置き換える
        song.fromFumen = true;
        info.wave = FumenWave(file, info.wave);
        if (info.wave.empty()) continue;   // 音源のない TJA は使わない（その曲はサンプルの譜面になる）
        RegisterTjaSong(file, info, song);
        songs_.push_back(std::move(song));
        ++count;
    }
    TraceLog(LOG_INFO, "SongDatabase: fumen の TJA の曲 %d", count);
}

// ジャンルフォルダの中の曲の並び（songs_index/<ジャンル>.json のインデックスの大きい順）
//   曲名と一致する TJA を、Data/x64/fumen から探す（作曲者つきのファイル名 → ファイル名 → TJA の曲名 → 記号だけ違うもの）。
//   見つからない曲は、サンプルの譜面の曲（sample）として並べる（曲名・作曲者・★は songs_index のもの）。
//   ジャンルフォルダに並ぶのは、この一覧の曲だけ。Songs の本家の譜面（創作譜面のフォルダ以外）は並べない
//   （段位道場のお題の曲としては、これまでどおり使える）。創作譜面のフォルダだけは、中身をファイル名の順にそのまま並べる
void SongDatabase::BuildGenreOrder() {
    namespace fs = std::filesystem;
    order_.assign(kGenreCount, {});

    // fumenLoose: 記号の違いを無視した形（LooseTitle）で引く表。songsByTitle は記録の引き継ぎだけに使う
    std::multimap<std::string, size_t> fumenByStem, fumenByTitle, songsByTitle, fumenLoose;
    for (size_t i = 0; i < songs_.size(); ++i) {
        const SongInfo& song = songs_[i];
        const std::string title = NormalizeTitle(WordList::Get().Text("song_" + song.id));
        if (song.fromFumen) {
            const std::string stem = NormalizeTitle(fs::u8path(song.tjaPath).stem().u8string());
            fumenByStem.emplace(stem, i);
            fumenByTitle.emplace(title, i);
            fumenLoose.emplace(LooseTitle(stem), i);
            if (LooseTitle(title) != LooseTitle(stem)) fumenLoose.emplace(LooseTitle(title), i);
        } else if (song.genreNo != kGenreCustom) {
            // 創作譜面は本家の曲の代わりにはしない（同じ曲名でも songs_index の曲には使わず、創作譜面のフォルダにだけ並べる）
            songsByTitle.emplace(title, i);
        }
    }
    auto find = [&](const std::multimap<std::string, size_t>& table, const std::string& key, int genre) -> long long {
        auto [begin, end] = table.equal_range(key);
        long long found = -1;
        for (auto it = begin; it != end; ++it) {
            if (found < 0) found = (long long)it->second;
            if (songs_[it->second].genreNo == genre) return (long long)it->second;
        }
        return found;
    };

    // fumen の曲と同じ曲名の Songs の曲が1つだけあれば、その曲の記録を引き継ぐ（Songs の曲の代わりに並ぶため）
    for (SongInfo& song : songs_) {
        if (!song.fromFumen) continue;
        const std::string title = NormalizeTitle(WordList::Get().Text("song_" + song.id));
        if (songsByTitle.count(title) == 1) song.recordId = songs_[songsByTitle.find(title)->second].id;
    }

    // サンプルの譜面（なければ TJA の見つからない曲は並べない）
    TjaInfo sampleInfo;
    const bool hasSample = FileExists(kSampleTja) && ReadTja(fs::u8path(kSampleTja), sampleInfo);
    if (hasSample && !sampleInfo.wave.empty()) {
        SoundManager::Get().RegisterSongFile(std::string("song_") + kSampleSound, sampleInfo.wave, float(sampleInfo.demoStart));
    }
    std::map<std::string, size_t> samples;   // 曲名と作曲者 → サンプルの曲（同じ曲がほかのジャンルにも載っていれば1つにする）

    // まず曲の番号で並びを作る（サンプルの曲を足すと songs_ が動くので、ポインタは最後に取る）
    std::vector<std::vector<size_t>> order(kGenreCount);
    std::vector<bool> genreSet(songs_.size(), false);
    int matched = 0, sampled = 0, missing = 0;
    for (int g = 0; g < kGenreCount; ++g) {
        std::vector<IndexEntry> entries;
        if (!LoadSongIndex(fs::path(kSongIndexDir) / fs::u8path(std::string(kSongIndexFiles[g]) + ".json"), entries)) continue;
        std::stable_sort(entries.begin(), entries.end(), [](const IndexEntry& a, const IndexEntry& b) { return a.index > b.index; });
        std::vector<bool> inGenre(songs_.size(), false);
        for (const IndexEntry& entry : entries) {
            const std::string key = NormalizeTitle(entry.title);
            // 探す順: fumen の「曲名 (作曲者)」というファイル名（同じ曲名の別の曲を見分ける）→ fumen のファイル名 →
            //   fumen の TJA の曲名 → fumen で記号だけ違うもの → Songs の TJA の曲名 → Songs で記号だけ違うもの
            const std::string loose = LooseTitle(key);
            long long index = -1;
            if (!entry.composer.empty()) index = find(fumenByStem, NormalizeTitle(entry.title + "(" + entry.composer + ")"), g);
            if (index < 0) index = find(fumenByStem, key, g);
            if (index < 0) index = find(fumenByTitle, key, g);
            if (index < 0 && !loose.empty()) index = find(fumenLoose, loose, g);
            // Songs の本家の譜面は、選曲の一覧には使わない（一覧は JSON と fumen の TJA だけ。Songs で使うのは創作譜面のフォルダ）
            if (index < 0 && hasSample) {
                const std::string sampleKey = key + '\n' + NormalizeTitle(entry.composer);
                auto found = samples.find(sampleKey);
                if (found == samples.end()) {
                    SongInfo song;
                    song.id = TextFormat("smp%08x", PathHash(entry.title + '\n' + entry.composer));
                    song.uniqueId = kSampleUniqueIdBase + int(samples.size());
                    song.genreNo = g;
                    song.sample = true;
                    song.soundId = kSampleSound;
                    song.tjaPath = kSampleTja;
                    song.stars = entry.stars;
                    WordList::Get().Set("song_" + song.id, entry.title);
                    WordList::Get().Set("song_sub_" + song.id, entry.composer);
                    WordList::Get().Set("song_detail_" + song.id, "");
                    songs_.push_back(std::move(song));
                    genreSet.push_back(true);
                    inGenre.push_back(false);
                    found = samples.emplace(sampleKey, songs_.size() - 1).first;
                }
                index = (long long)found->second;
                ++sampled;
            } else if (index < 0) {
                ++missing;
                continue;
            } else {
                ++matched;
            }
            if (inGenre[size_t(index)]) continue;   // 同じ曲名がもう並んでいる
            inGenre[size_t(index)] = true;
            // fumen の曲は、最初に載っていたジャンルの色・背景で演奏する
            SongInfo& song = songs_[size_t(index)];
            if (song.fromFumen && !genreSet[size_t(index)]) {
                song.genreNo = g;
                genreSet[size_t(index)] = true;
            }
            order[size_t(g)].push_back(size_t(index));
        }
    }
    for (size_t i = 0; i < songs_.size(); ++i) {
        // 創作譜面のフォルダだけは、JSON に載っていなくても中身をそのまま並べる（ほかのジャンルは JSON にある曲だけ）
        if (songs_[i].genreNo == kGenreCustom && !songs_[i].fromFumen && !songs_[i].sample) order[size_t(kGenreCustom)].push_back(i);
    }
    for (int g = 0; g < kGenreCount; ++g) {
        for (const size_t i : order[size_t(g)]) order_[size_t(g)].push_back(&songs_[i]);
    }
    TraceLog(LOG_INFO, "SongDatabase: songs_index の曲 TJA あり %d・サンプルの譜面 %d（サンプルの譜面がなく並べない曲 %d）", matched, sampled,
             missing);
}

} // namespace GuminTaiko
