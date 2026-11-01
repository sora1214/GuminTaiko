#pragma once
#include <string>

#include "LumenPlayer.hpp"

// 通信中ウィンドウ（lumen/000_default/common/banapass_load。lua: NetAccessWindow）
class NetWindow {
public:
    void Setup(Lumen::MovieClip* root);
    void Loading(const char* titleKey);
    void Success(const char* titleKey, const char* subKey);
    void Error(const char* titleKey, const char* subKey);
    void Close();
    bool IsPlay() const;

private:
    void Open(const char* rootLabel, const char* instance);

    Lumen::MovieClip* root_ = nullptr;
    Lumen::MovieClip* current_ = nullptr;
};

// 1人分の名前入力（lumen/000_default/entry/name_entry。lua: NameEntryOnePlayer）
// 名前は「a」「ka」「xtu」のようなローマ字コード5文字で持つ
class NameEntryPanel {
public:
    enum class Result { Doing, Upload, Finish };

    void Setup(Lumen::MovieClip* root, Lumen::MovieClip* guide, int player, NetWindow* net);
    void SetPlayerNum(int num) { playerNum_ = num; }
    void Start();              // フェードイン
    void StartSelect();        // 入力受付の開始
    void TimeUp();             // 時間切れ（今の名前で決める）
    void SetFinish() { result_ = Result::Finish; }
    Result Update(float dt, bool left, bool right, bool don);
    std::string NameText() const;   // ひらがなにした名前

private:
    enum class State {
        StartWait, ToRing1, Ring1, Ring1Move, ToRing2, Ring2, Ring2Move, ToRing3, Ring3, Ring3Move, CharDecide,
        ToAccept, ToAccept2, Accept, DecideWait, Upload, ToSuccess, Success, SuccessToEnd, EndWait, End,
    };

    void SetState(State state);
    void SetBigplateCursor(int pos);
    void SetNameBigplate();
    void SetupToRing1();
    void SetupToRing2();
    void SetupToRing3();
    void SetupToAccept();
    void SetRingCursor(bool flag);
    void SetDispModeRing1();
    void SetDispModeRing2();
    void SetDispModeRing3();
    void SetDispRing1(bool flag);
    void SetDispRing2(bool flag);
    void SetDispRing3(bool flag);
    void SetDispRingChar(Lumen::MovieClip* target, const std::string& code, const char* const* pre, int preCount,
                         const char* const* post, int postCount);
    void SetDispCenter(int ring);
    void SetDispCharPosRing1();
    void SetDispCharPosRing2();
    void SetDispCharPosRing3();
    void SetAcceptWindow(int cursor);
    void ChangeBlankNameToDefaultName();
    void PlaySe(const char* name) const;

    Lumen::MovieClip* mc_ = nullptr;
    Lumen::MovieClip* guide_ = nullptr;
    Lumen::MovieClip* nameInput_ = nullptr;
    Lumen::MovieClip* acceptBase_ = nullptr;
    Lumen::MovieClip* accept_ = nullptr;
    Lumen::MovieClip* dispNameChar_[5] = {};
    Lumen::MovieClip* center_ = nullptr;
    Lumen::MovieClip* ring1_ = nullptr;
    Lumen::MovieClip* ring2_ = nullptr;
    Lumen::MovieClip* ring3_ = nullptr;
    Lumen::MovieClip* ring2Row_[3] = {};   // row4 / row5 / row6
    Lumen::MovieClip* ring3Row_[2] = {};   // row3 / row4
    Lumen::MovieClip* ring2Disp_ = nullptr;
    Lumen::MovieClip* ring3Disp_ = nullptr;
    NetWindow* net_ = nullptr;

    int player_ = 0;
    int playerNum_ = 1;
    State state_ = State::StartWait;
    float stateTime_ = 0.0f;
    Result result_ = Result::Finish;

    std::string name_[5];
    int bigplateCursor_ = 1;
    int ring1Index_ = 1;
    int ring2Index_ = 1;
    int ring3Index_ = 1;
    int acceptCursor_ = 1;
    bool nameDecideBlank_ = false;
};
