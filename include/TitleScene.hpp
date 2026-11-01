#pragma once
#include <iostream>
#include "Scene.hpp"

enum class GameMode {
    SinglePlay,  // 1人で遊ぶ
    TwoPlay,     // 2人で遊ぶ
    DanDanDojo,  // 段位道場
    AIPlay       // AIバトル演奏
};

class TitleScene : public Scene {
private:
    GameMode selectedMode = GameMode::SinglePlay;

public:
    void Initialize() override {
        std::cout << "\n==========================================" << std::endl;
        std::cout << " [モード選択画面]" << std::endl;
        std::cout << "  -> 1人であそぶ" << std::endl;
        std::cout << "     2人であそぶ" << std::endl;
        std::cout << "     段位道場" << std::endl;
        std::cout << "==========================================" << std::endl;
    }

    void Update(float deltaTime) override {
        // モード選択（ドン・カッの入力でカーソル移動）の処理を記述
    }

    void Draw() override {}
    void Finalize() override {}
};