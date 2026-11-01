#pragma once
#include "LumenPlayer.hpp"

// 画面をまたいで使う Lumen の部品（lua: common/NamePlate, common/Timer）
namespace CommonParts {

// ネームプレート（lumen/000_default/common/name_plate を読み込んだインスタンス）にプレイヤーの情報を出す
// （lua: NamePlate:SetPlayerInfo）
void SetNamePlate(Lumen::MovieClip* root, int player);
// オートプレイで遊んだときの「記録は残りません」の表示（リザルトの上に重ねる）
void DrawNoRecordNotice();
// F3 でオートプレイを入り切りする（選曲画面と段位選択画面だけで呼ぶ）。切り替えたら音を鳴らす。切り替えたら true
bool ToggleAutoPlay();
// オートプレイ中のしるし（左端 left、高さの中心 centerY。オートでなければ何も描かない）。
// scale 1.0 が演奏オプションのアイコンと同じ大きさ（約 38px）
void DrawAutoBadge(float left, float centerY, float scale = 1.0f);

// ネームプレートの main の文字（称号・名前）を本家の見た目にする
//   字形は選曲のジャンルの看板と同じ。称号: 帯の上下中央に黒い文字  名前: 白い帯の上下中央に、黒い縁取りの白い文字
void StyleNamePlateText(Lumen::MovieClip* plate);

// タイマーの数字（timer_main_instance/time_count_instance）を count にする。
// redLimit 以下は赤く点滅する表示（lua: Timer:DisplayCount）
void SetTimerCount(Lumen::MovieClip* timeCount, int count, int redLimit);

} // namespace CommonParts
