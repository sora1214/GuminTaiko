#pragma once
#include <array>
#include <string>

#include "LumenPlayer.hpp"
#include "PlayData.hpp"

// 難易度選択で開く演奏オプションの板（lua: song_select_option_main / song_select_option_selector）。
// song_select_main_diff_option の main/board_left（1P）か main/board_right（2P）を動かす。
// 面で次の項目へ進み、ふちで選択肢を変える。8項目を終えると閉じる。
// 音符位置調整は「する」で面を叩くと調整の窓が開き、ふちで左5〜右5を選んで、もう一度面で閉じる
class PlayOptionBoard {
public:
    enum Item { kSpeed, kDoron, kAbekobe, kRandom, kSkip, kPosition, kVoice, kNeiro, kItemCount };

    // board: main/board_left か main/board_right。right: 右の板、twoPlayers: 2人で遊んでいる（演奏スキップは選べない）
    void Setup(Lumen::MovieClip* board, int player, bool right, bool twoPlayers);
    // 板を出す（lua: Tween_SlideIn）
    void Open(const GuminTaiko::PlayOptions& options);
    // 60fps の1フレームぶん。そのフレームに叩いた入力を渡す
    void Step(bool don, bool kaLeft, bool kaRight);
    // 時間切れ: いまの設定のまま閉じる
    void ForceClose();
    bool IsOpen() const { return open_; }   // 出入りの途中も含む
    bool TakeClosed();                      // 閉じ終わったフレームに1回だけ true
    GuminTaiko::PlayOptions Options() const;

private:
    struct Selector {
        Lumen::MovieClip* mc = nullptr;
        Lumen::MovieClip* arrowLeft = nullptr;
        Lumen::MovieClip* arrowRight = nullptr;
        int current = 0;    // 選択肢の番号（0 が初期値）
        int count = 1;
    };

    void Reset();                           // lua: PlayerOptionInit
    void SetCursor(int item, bool on);      // lua: SetSelectCursor
    void StartCursor(int item);
    void EndCursor(int item);
    void Change(int direction);             // lua: Tween_Left / Tween_Right
    void UpdateText(int item, bool selecting, int direction);   // lua: TextSet
    void Next();                            // lua: CursorMove
    void SetPositionWindow(int position);   // lua: SetOnpuPositionGotoPlay
    void UpdateNeiro();
    void PlaySe(const char* tone) const;

    Lumen::MovieClip* board_ = nullptr;
    Lumen::MovieClip* positionWindow_ = nullptr;   // 音符位置調整の窓
    Lumen::MovieClip* positionSelect_ = nullptr;
    Lumen::MovieClip* skipWindow_ = nullptr;        // 演奏スキップの説明
    std::array<Selector, kItemCount> selectors_{};
    int player_ = 0;
    bool right_ = false;
    bool twoPlayers_ = false;

    bool open_ = false;
    bool fadeIn_ = false;
    bool fadeOut_ = false;
    bool closed_ = false;
    int item_ = 0;                  // 選んでいる項目
    int waitFrames_ = 0;            // はやさ: 開いてから入力を受け付けるまで（lua: Wait）
    int position_ = 0;              // 音符位置調整の値（-5〜5）
    bool positionOpen_ = false;     // 音符位置調整の窓が開いている
    int neiroWait_ = 0;             // 音色: 選んでから最初の音まで
    int neiroTimer_ = 0;
    bool neiroDon_ = false;         // 次に鳴らすのがカッなら true（ドン → カッ → ドン …）
};
