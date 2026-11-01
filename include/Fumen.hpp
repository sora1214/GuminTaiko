#pragma once
#include <array>
#include <string>
#include <vector>

// 譜面（Data/x64/fumen/<曲ID>/<曲ID>_<e|n|h|m|x>.bin）
//   ヘッダー 0x208 バイト: 判定の幅（良・可・不可, ms）、魂ゲージの増減、小節の数
//   小節: [BPM f32][オフセット f32][ゴーゴー u8][小節線 u8][u16][分岐の条件 i32×6][i32]
//         × 3 分岐（普通・玄人・達人）: [音符の数 u16][u16][スクロール f32] + 音符
//   音符（24 バイト。連打は後ろに 8 バイト）: [種類 u32][小節内の位置 f32 ms][u32][f32]
//         [初項 u16][公差 u16][長さ f32 ms]。風船・くす玉の打数は「初項」に入っている
// 小節のオフセットは「判定枠に届く時刻 − 1小節分（240000 / BPM）」。音符を叩く時刻は
// オフセット + 240000 / BPM + 小節内の位置（曲の音声と照らし合わせて確かめた）。
namespace GuminTaiko {

enum class NoteType {
    None,
    Don, Do, Ko,          // 面（ドン）。do / ko は見た目だけの違い
    Katsu, Ka,            // ふち（カッ）
    BigDon, BigKatsu,     // 大音符
    Roll, BigRoll,        // 連打
    Balloon, Kusudama,    // 風船・くす玉
    HandDon, HandKatsu,   // 手をつないだ大音符（2人用）
};

struct FumenNote {
    NoteType type = NoteType::None;
    double time = 0.0;        // 叩く時刻（ms、曲の先頭から）
    double duration = 0.0;    // 連打・風船の長さ（ms）
    int hits = 0;             // 風船・くす玉を割るのに必要な打数
    double bpm = 120.0;       // その小節の BPM（流れる速さに使う）
    double scroll = 1.0;      // その小節のスクロール速度
    bool gogo = false;

    bool IsDon() const { return type == NoteType::Don || type == NoteType::Do || type == NoteType::Ko || type == NoteType::BigDon || type == NoteType::HandDon; }
    bool IsKatsu() const { return type == NoteType::Katsu || type == NoteType::Ka || type == NoteType::BigKatsu || type == NoteType::HandKatsu; }
    bool IsBig() const { return type == NoteType::BigDon || type == NoteType::BigKatsu || type == NoteType::HandDon || type == NoteType::HandKatsu; }
    bool IsRoll() const { return type == NoteType::Roll || type == NoteType::BigRoll; }
    bool IsBalloon() const { return type == NoteType::Balloon || type == NoteType::Kusudama; }
    bool IsHit() const { return IsDon() || IsKatsu(); }
};

struct FumenMeasure {
    double time = 0.0;        // 小節の頭が判定枠に届く時刻（ms）
    double bpm = 120.0;
    std::array<double, 3> scroll{1.0, 1.0, 1.0};
    bool gogo = false;
    bool barline = true;
    std::array<int, 6> branchInfo{};
    std::array<std::vector<FumenNote>, 3> notes;   // 普通・玄人・達人
};

struct Fumen {
    std::array<float, 3> windows{25.0f, 75.0f, 108.0f};   // 良・可・不可の判定幅（ms、片側）
    bool hasBranches = false;
    int hpMax = 10000;
    int hpClear = 8000;
    int hpGood = 0;
    int hpOk = 0;
    int hpBad = 0;
    int shinuti = 0;          // 良1つの点数（0 なら曲の情報 musicinfo の値を使う。TJA の譜面だけが入れる）
    std::vector<FumenMeasure> measures;
};

// course: 0 かんたん 1 ふつう 2 むずかしい 3 おに 4 おに(裏)
std::string FumenPath(const std::string& songId, int course);
// 判定の幅（良・可・不可, ms）を難易度で決める。かんたん・ふつう: 41.708 / 75.075 / 125.125、
// むずかしい・おに（裏）: 25.025 / 58.392 / 108.442。譜面ファイルの値より優先する
void SetJudgeWindows(int course, Fumen& fumen);
bool LoadFumen(const std::string& path, Fumen& out, std::string* error = nullptr);

} // namespace GuminTaiko
