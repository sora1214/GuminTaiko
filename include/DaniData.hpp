#pragma once
#include <array>
#include <string>
#include <vector>

// 段位道場のお題（lua: DaniData / Cabinet.DaniInfo。本家はサーバーから配信される）
//   Dani/*.json に1つの段位を1ファイルで書く（着せかえと同じく、このゲームだけの形。段位の作成アプリ GuminDaniEditor で作る）
//   {
//     "schemaVersion": 1,
//     "level": 6,                               段位（1: 五級 … 5: 一級、6: 初段 … 15: 十段、16: 玄人、17: 名人、18: 超人、19: 達人、20: 外伝）
//     "songs": [                                課題曲3曲（Songs からの TJA の相対パス、難易度）
//       { "tja": "ナムコオリジナル/…/曲.tja", "course": "oni", "hidden": false }, …
//     ],
//     "gauge": { "red": 98, "gold": 100 },      魂ゲージ（%）
//     "exams": [                                お題（3つまで）
//       { "type": "good", "range": "total", "red": [1000], "gold": [1100] },
//       { "type": "bad",  "range": "song",  "red": [10, 10, 10], "gold": [5, 5, 5] }
//     ]
//   }
//   type: good（良）/ ok（可）/ bad（不可）/ combo（最大コンボ）/ roll（連打）/ score（スコア）/ hit（たたけた数）
//   range: total（3曲通し）/ song（1曲ごと）。可・不可は「未満」、ほかは「以上」
namespace GuminTaiko {

constexpr int kDaniLevelCount = 20;   // 外伝まで
constexpr int kDaniMaxRank = 19;      // いちばん上の段位（達人）
// 外伝（達人の次の板）。腕前の段位ではないので、合格しても昇段はなく、ネームプレートの段位にもならない。最初から選べる
constexpr int kDaniGaiden = 20;
constexpr int kDaniSongCount = 3;
constexpr int kDaniExamCount = 3;

enum class DaniExamType { None, Good, Ok, Bad, Combo, Roll, Score, Hit };

struct DaniExam {
    DaniExamType type = DaniExamType::None;
    bool total = true;                           // 3曲通し
    std::array<int, kDaniSongCount> red{};       // 赤合格（通しなら [0] だけ）
    std::array<int, kDaniSongCount> gold{};      // 金合格
    bool LessThan() const { return type == DaniExamType::Ok || type == DaniExamType::Bad; }   // 「未満」のお題
};

// 1曲ぶんの成績（お題の判定と記録に使う）
struct DaniSongResult {
    int good = 0, ok = 0, bad = 0, combo = 0, roll = 0, score = 0, hit = 0;
    int Value(DaniExamType type) const {
        switch (type) {
        case DaniExamType::Good: return good;
        case DaniExamType::Ok: return ok;
        case DaniExamType::Bad: return bad;
        case DaniExamType::Combo: return combo;
        case DaniExamType::Roll: return roll;
        case DaniExamType::Score: return score;
        case DaniExamType::Hit: return hit;
        default: return 0;
        }
    }
};

// 挑戦中の段位（3曲をまたいで持つ）
struct DaniRun {
    bool active = false;
    int level = 0;
    int songIndex = 0;                                   // いま遊んでいる曲（0〜2）
    std::array<DaniSongResult, 3> songs{};
    double gauge = 0.0;                                  // 魂ゲージ（0〜1。3曲の音符の数で重みをつけて足す）
    int combo = 0;                                       // 曲をまたいで続くコンボ
    int score = 0;                                       // 前の曲までのスコア（表示は3曲通して増える）
    bool failed = false;                                 // 赤合格に届かなくなって途中で終わった
    int arrival = 0;                                     // 到達した曲数
    std::array<int, 3> notes{};                          // 曲ごとの音符の数（魂ゲージの重み・お題の見込みに使う）
    int totalNotes = 0;
};

// お題の値（通しなら3曲の合計。コンボは曲をまたいだ最大）と、赤・金の判定
int DaniExamValue(const DaniExam& exam, const DaniRun& run, int song);
// 0: 未達 1: 赤 2: 金。まだ遊んでいる途中なら、今の値で見る
int DaniExamGrade(const DaniExam& exam, int value, int song);

struct DaniSong {
    std::string tja;         // Songs からの相対パス（/ 区切り）
    int course = 3;          // 0: かんたん … 3: おに 4: おに(裏)
    bool hidden = false;     // 挑戦するまで曲名を ？？？ にする
    int uniqueId = -1;       // 見つかった曲（SongDatabase のユニーク ID。見つからなければ -1）
};

struct DaniCourse {
    int level = 0;                                    // 1〜19
    std::string file;                                 // 読み込んだファイル
    std::array<DaniSong, kDaniSongCount> songs;
    int gaugeRed = 100;
    int gaugeGold = 100;
    std::array<DaniExam, kDaniExamCount> exams;
    bool Playable() const;                            // 3曲とも譜面がある
};

// 段位の名前（五級 … 達人）、Lumen のラベル（5kyuu … 14dan）
const char* DaniName(int level);
const char* DaniLabel(int level);
const char* DaniExamTypeName(DaniExamType type);      // "good" など（JSON の値）
const char* DaniExamTextKey(DaniExamType type);       // wordlist の clear_theme_*（「良の数」など）
DaniExamType DaniExamTypeFromName(const std::string& name);

class DaniDatabase {
public:
    static DaniDatabase& Get() {
        static DaniDatabase instance;
        return instance;
    }
    // 段位（なければ nullptr）。はじめて呼んだときに Dani/*.json を読み、曲を SongDatabase から探す
    const DaniCourse* Course(int level);
    void Reload();

    // JSON の読み書き（作成アプリと共通）
    static bool LoadFile(const std::string& path, DaniCourse& out, std::string* error = nullptr);
    static bool SaveFile(const std::string& path, const DaniCourse& course);
    static std::string DefaultPath(int level);        // Dani/<level>_<名前>.json

private:
    void Load();
    bool loaded_ = false;
    std::array<DaniCourse, kDaniLevelCount + 1> courses_{};
    std::array<bool, kDaniLevelCount + 1> has_{};
};

} // namespace GuminTaiko
