#pragma once
#include <array>
#include <string>

#include "Fumen.hpp"

// TJA 形式の譜面（太鼓さん次郎・TJAPlayer などの譜面ファイル）
//   ヘッダー: TITLE / SUBTITLE / BPM / WAVE / OFFSET / DEMOSTART / GENRE / COURSE / LEVEL / BALLOON
//   命令: #START [P1|P2] / #END / #MEASURE / #BPMCHANGE / #SCROLL / #GOGOSTART / #GOGOEND / #DELAY
//         #BARLINEON / #BARLINEOFF / #BRANCHSTART p|r|s,玄人,達人 / #N / #E / #M / #BRANCHEND / #SECTION / #LEVELHOLD
//         （そのほかは読み飛ばす）
//   音符: 1 ドン 2 カッ 3 大ドン 4 大カッ 5 連打 6 大連打 7 風船 8 連打・風船の終わり 9 くす玉
//         A 手をつないだ大ドン B 手をつないだ大カッ（C 爆弾・F アドリブなどは置かない）
// 文字コードは UTF-8（BOM あり・なし）と Shift_JIS に対応する。パスは UTF-8 で渡す。
// 本家の譜面（.bin）にある判定の幅・魂ゲージの増え方・真打の配点は TJA にないので、本家の譜面の値から
// 割り出した式で決める（Tja.cpp の MakeGauge を参照）。
namespace GuminTaiko {

struct TjaInfo {
    std::string title;
    std::string subtitle;
    std::string wave;                  // 曲の音声（TJA からの相対パスを UTF-8 の絶対パスにしたもの）
    std::string genre;                 // GENRE: の値。なければ上のフォルダの box.def / genre.ini、それもなければフォルダのパス
    double demoStart = 0.0;            // 選曲画面で流し始める位置（秒）
    std::array<int, 5> levels{};       // 難易度ごとの★（譜面がない難易度は 0）
    std::array<bool, 5> branch{};      // 譜面分岐があるか
};

// ヘッダーと、どの難易度の譜面が入っているかだけを読む（選曲画面に並べるため）
bool ReadTjaInfo(const std::string& path, TjaInfo& out, std::string* error = nullptr);

// course: 0 かんたん 〜 4 おに(裏)。音符の時刻は Fumen と同じ（叩く時刻、曲の先頭から ms）
bool LoadTja(const std::string& path, int course, Fumen& out, std::string* error = nullptr);

} // namespace GuminTaiko
