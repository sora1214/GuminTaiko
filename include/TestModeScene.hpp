#pragma once
#include <map>
#include <string>
#include <vector>

#include "Scene.hpp"
#include "TestMenu.hpp"
#include "raylib.h"

// テストモード（Data/x64/testmode/TestMode.xml のメニューをそのまま出す）
//   画面は 96 × 30 マスの文字盤。全角も半角も1文字1マス。
//   Header / Footer の文字は中央寄せ、data-item は画面の中央からの位置、Center は padding-x からの位置に置く。
//   操作: SELECT（↑/↓）で項目を選び ENTER（Enter）で決定。値の項目は ENTER で変更を始め、SELECT で値を変え、
//         ENTER で確定（保存）する。テストスイッチ（F9）を戻すと再起動（アトラクトの最初）する。
//   値の色: 初期値は緑（DEFAULT IN GREEN）、それ以外は白。選んでいる項目は赤。
// 実機の周辺機器（カードリーダー・ネットワーク・USIO・ランプ）はないので、それらの項目は「つながっていない」表示。
class TestModeScene : public Scene {
public:
    // テストモードの最中か（main がテストスイッチ・サービスボタンを受け付けるかを決める）
    static bool IsActive() { return active_; }

    void Initialize() override;
    void Update(float deltaTime) override;
    void Draw() override;
    void Finalize() override;

private:
    struct Placed {
        const TestMenu::Item* item = nullptr;
        std::string layout;   // Header / Center / Footer
        int row = 0;
        int col = 0;          // ラベルの左端（マス）
        int paramCol = 0;     // 値の左端（マス）
    };

    enum class Edit { None, Value, Confirm };

    void OpenMenu(const std::string& id, const std::string& focusId = "");
    bool IsSelectable(const TestMenu::Item& item, bool includeSkip) const;
    int FindNext(int from, int direction, bool includeSkip) const;
    void Focus(int index);
    void Enter();
    void MoveValue(int direction);
    void ConfirmValue();
    void RunCommand(const TestMenu::Item& item);

    // 値
    bool IsSetting(const TestMenu::Item& item) const;
    int CurrentValue(const std::string& id) const;
    std::string ValueText(const TestMenu::Item& item) const;
    bool DynamicValue(const std::string& id, double& value) const;
    bool Flag(const TestMenu::Item& item, const std::string& key) const;
    bool EvalCondition(const std::string& expr) const;

    // 描画
    void DrawMarkup(const std::string& text, int col, int row, Color defaultColor) const;
    void DrawPattern(const std::string& msg) const;

    // ---- KEY CONFIG（キーの割り当て。本家のテストモードにはない、この移植で足した画面） ----
    //   トップメニューの最後に「ＫＥＹ ＣＯＮＦＩＧ」を足す。操作ごとに KEY1・KEY2 の2つのキーを割り当てられる。
    //   SELECT で選び ENTER で「キーを押してください」になり、次に押したキーを割り当てる（ESC で取り消し、DELETE で外す）。
    //   ほかの操作に同じキーがあれば、そちらは外す。DEFAULT で初期値に戻す。変えるとすぐ Backup/keyconfig.ini に保存する
    void OpenKeyConfig();
    void CloseKeyConfig();
    void UpdateKeyConfig();
    void DrawKeyConfig() const;
    TestMenu::Item keyConfigItem_;   // トップメニューに足す項目
    TestMenu::Item guminItem_;       // トップメニューに足す項目（ＧＵＭＩＮ ＳＥＴＴＩＮＧＳ）
    bool keyConfig_ = false;
    int kcCursor_ = 0;               // 割り当て（操作 × KEY1/KEY2 の順）、そのあと DEFAULT、EXIT
    bool kcWaiting_ = false;         // キーを押すのを待っている
    std::string kcMessage_;

    const TestMenu::Definition* def_ = nullptr;
    const TestMenu::Menu* menu_ = nullptr;
    std::vector<Placed> placed_;
    int cursor_ = -1;
    Edit edit_ = Edit::None;
    int editValue_ = 0;
    int valueRepeat_ = 0;            // 値を変えるキーを押し続けて繰り返した回数（長く押すと 10 ずつ変える）
    bool confirmYes_ = false;

    std::map<std::string, std::string> parentOf_;  // メニュー → 開いたときにいたメニュー
    std::map<std::string, int> temp_;              // 保存しない値（トグル・メッセージなど）
    std::map<std::string, int> commandState_;      // cmd-item の表示（cmd-text の番号）
    std::map<std::string, float> commandTimer_;
    float time_ = 0.0f;
    int coinCount_ = 0;                            // スイッチテスト中に入れたコイン
    float cellW_ = 20.0f, cellH_ = 36.0f;
    bool firstFrame_ = true;          // テストスイッチを押したフレームでは抜けない
    static inline bool active_ = false;
};
