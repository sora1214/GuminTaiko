#pragma once
#include <string>

#include "raylib.h"

// 太鼓コントローラーと筐体のボタンのキーボード割り当て（テストモードの KEY CONFIG で変えられる。Backup/keyconfig.ini に保存）
// 初期値:
//   1P: D=ふち(左) F=面(左) J=面(右) K=ふち(右)   ※ ←/→ と Enter でも操作可
//   2P: Z=ふち(左) X=面(左) C=面(右) V=ふち(右)   ※ テンキー 7/4/6/9 でも操作可
//   筐体: F1=テストスイッチ F10=サービスボタン F5=コイン投入 F3=カードタッチ(登録済み) F4=カードタッチ(新規)
//         F2=フリープレイ切替（アトラクト・エントリー）／特訓モード（演奏中）
// 変えられないキー: ESC（もどる・ポーズ）、F11（キー操作ガイド）、F12（raylib の画面保存を止めるため捨てる）
//   テストモードの SELECT / ENTER は ↑/↓ と Enter/Space のまま（割り当てを間違えても設定画面を操作できるように）
namespace TaikoInput {

enum class Pad { LeftKa = 0, LeftDon, RightDon, RightKa };

// 割り当てられる操作。太鼓は 1P・2P それぞれ Pad の順
enum class Action {
    P1KaLeft, P1DonLeft, P1DonRight, P1KaRight,
    P2KaLeft, P2DonLeft, P2DonRight, P2KaRight,
    Test, Service, Coin, Card, NewCard, FreePlay, Training,
    Count
};
constexpr int kActionCount = int(Action::Count);
constexpr int kKeySlots = 2;   // 1つの操作に割り当てられるキーの数

// 割り当て（起動時に LoadBindings で読み込む）
void LoadBindings();
void SaveBindings();
void ResetBindings();                          // 初期値に戻す（保存もする）
int BoundKey(Action action, int slot);         // 割り当てたキー（なければ 0）
int DefaultKey(Action action, int slot);       // 初期値のキー（なければ 0）
// キーを割り当てる（0 で外す）。同じキーをほかの操作に割り当てていたら、そちらは外す
// （フリープレイ切替と特訓モードは使う画面が違うので同じキーでもよい）。変えられないキーなら false
bool SetBoundKey(Action action, int slot, int key);
bool IsReservedKey(Action action, int key);
// raylib（GLFW）のキーの番号を、Windows の仮想キーの番号にする（対応がなければ 0。叩いた瞬間の音の監視用）
int WindowsKey(int key);
std::string ActionName(Action action);         // 表示名（英語）
std::string KeyName(int key);                  // キーの表示名（英語。0 は "---"）

// 確認用: このフレームだけ叩いたことにする（main の --input から使う。毎フレームの終わりに消す）
inline bool g_injected[2][4] = {};
inline void Inject(int player, Pad pad) { g_injected[player][int(pad)] = true; }
inline void ClearInjected() {
    for (auto& player : g_injected) {
        for (bool& hit : player) hit = false;
    }
}

// 確認用: 筐体側のキー（F9 など）もこのフレームだけ押したことにする
inline bool g_injectedKeys[512] = {};
inline void InjectKey(int key) {
    if (key > 0 && key < 512) g_injectedKeys[key] = true;
}
inline bool KeyPressed(int key) { return IsKeyPressed(key) || (key > 0 && key < 512 && g_injectedKeys[key]); }
// このフレームに押したキー（raylib の GetKeyPressed と、確認用に押したことにしたキー）。なければ 0
inline int FirstPressedKey() {
    for (int key = 1; key < 512; ++key) {
        if (g_injectedKeys[key]) return key;
    }
    return GetKeyPressed();
}
inline void ClearInjectedKeys() {
    for (bool& key : g_injectedKeys) key = false;
}

// 割り当てたキーのどれかが押された／押している／押し続けて繰り返しが来た
bool ActionPressed(Action action);
bool ActionDown(Action action);
bool ActionRepeat(Action action);

inline Action PadAction(int player, Pad pad) { return Action(player * 4 + int(pad)); }
inline bool IsHit(int player, Pad pad) { return g_injected[player][int(pad)] || ActionPressed(PadAction(player, pad)); }

inline bool IsDon(int player) { return IsHit(player, Pad::LeftDon) || IsHit(player, Pad::RightDon); }
inline bool IsKaLeft(int player) { return IsHit(player, Pad::LeftKa); }
inline bool IsKaRight(int player) { return IsHit(player, Pad::RightKa); }

inline bool AnyDon() { return IsDon(0) || IsDon(1); }
inline bool AnyKaLeft() { return IsKaLeft(0) || IsKaLeft(1); }
inline bool AnyKaRight() { return IsKaRight(0) || IsKaRight(1); }

// 筐体側の入力（デバッグ用の代替キー）
inline bool IsFreePlayToggled() { return ActionPressed(Action::FreePlay); }
inline bool IsTrainingPressed() { return ActionPressed(Action::Training); }
inline bool IsCardTouched() { return ActionPressed(Action::Card); }
inline bool IsNewCardTouched() { return ActionPressed(Action::NewCard); }
inline bool IsCoinInserted() { return ActionPressed(Action::Coin); }
// テストスイッチ
// raylib は F12 で画面を保存してしまう（screenshot000.png などができる）ので、F12 のキーの知らせは raylib に渡す前に捨てる
// （InstallTestSwitch をウィンドウを作ったあとに1回呼ぶ）
void InstallTestSwitch();
inline bool IsTestPressed() { return ActionPressed(Action::Test); }
inline bool IsTestDown() { return ActionDown(Action::Test); }
inline bool IsServicePressed() { return ActionPressed(Action::Service); }
inline bool IsServiceDown() { return ActionDown(Action::Service); }

// テストモードのボタン（筐体の SELECT / ENTER）
inline bool IsSelectUp() { return KeyPressed(KEY_UP) || IsKeyPressedRepeat(KEY_UP); }
inline bool IsSelectDown() { return KeyPressed(KEY_DOWN) || IsKeyPressedRepeat(KEY_DOWN); }
inline bool IsSelectUpDown() { return IsKeyDown(KEY_UP); }
inline bool IsSelectDownDown() { return IsKeyDown(KEY_DOWN); }
// ESC: 1つ前の画面に戻る（演奏中はポーズ）。ゲームは終わらせない（main で raylib の終了キーを外している）
inline bool IsBackPressed() { return KeyPressed(KEY_ESCAPE); }
inline bool IsEnter() { return KeyPressed(KEY_ENTER) || KeyPressed(KEY_SPACE); }
inline bool IsEnterDown() { return IsKeyDown(KEY_ENTER) || IsKeyDown(KEY_SPACE); }

} // namespace TaikoInput
