#pragma once
#include <string>
#include <vector>

// どんちゃんの着せかえ（Data/x64/model の番号 = datatable/don_cos_reward の dataId。ファイル名は 6 桁。例: body 1000 → body_001000）
//   kigurumi（cos_*）が 0 以上なら、きぐるみで体と頭をまるごと置き換える。そうでなければ body（胴・手足の飾り）と head（頭の飾り）
//   face は表情の画像の組（face_*）。色は datatable/don_color.bin の番号（-1 なら どんちゃん／かっちゃんの初期の色）
struct DonCostume {
    int kigurumi = -1;
    int body = 0;
    int head = 0;
    int face = 0;
    int faceColor = -1;   // 顔の円
    int bodyColor = -1;   // 胴
    int legsColor = -1;   // ふち・手足
    bool operator==(const DonCostume& o) const {
        return kigurumi == o.kigurumi && body == o.body && head == o.head && face == o.face && faceColor == o.faceColor &&
               bodyColor == o.bodyColor && legsColor == o.legsColor;
    }
    bool operator!=(const DonCostume& o) const { return !(*this == o); }
};

// エントリーのきせかえの番号（PlayerData::costume）
constexpr int kDonCostumeRandom = 4;   // おまかせ
constexpr int kDonCostumeCustom = 5;   // じぶんで選んだ着せかえ（DonCostume をそのまま着る）

// 着せかえの一覧（すべて解放してある）。datatable/don_cos_reward.bin の並びで、モデルのファイルがあるものだけ
namespace DonCatalog {

enum class Kind { Kigurumi, Head, Body, Face, Count };

struct Entry {
    int dataId = 0;          // モデルの番号
    std::string name;        // 名前（wordlist の costume_<種類>_<uniqueId>）
};

// 種類ごとの一覧（1回読み込んで使い回す）。きぐるみの先頭は「きぐるみなし（-1）」
const std::vector<Entry>& Items(Kind kind);
// 体の色の数（datatable/don_color.bin）。番号 0〜Count-1、-1 は初期の色
int ColorCount();
// 色（0〜255）。番号が範囲の外なら白
void ColorRgb(int index, unsigned char& r, unsigned char& g, unsigned char& b);
// 一覧の中での位置（見つからなければ 0）
int IndexOf(Kind kind, int dataId);

// ---- 着せかえを変える項目（エントリーの「じぶんで」と着せかえアプリで共通） ----
enum class Field { Kigurumi, Head, Body, Face, FaceColor, BodyColor, LegsColor, Count };
const char* FieldName(Field field);                               // 「きぐるみ」など
std::string ValueText(const DonCostume& costume, Field field);    // 選んでいるものの名前
void Step(DonCostume& costume, Field field, int direction);       // 次・前のものに変える（端で回る）
bool FieldUsed(const DonCostume& costume, Field field);           // きぐるみを着ているときの頭・体は使わない

} // namespace DonCatalog
