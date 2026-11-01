#pragma once
#include "Scene.hpp"

// エントリー後の遷移先（曲選択・段位選択・AI選択）ができるまでの仮画面。
// PlayDataManager に渡された内容を表示し、決定でエントリー画面へ戻る。
class PlaceholderScene : public Scene {
public:
    void Initialize() override;
    void Update(float deltaTime) override;
    void Draw() override;
    void Finalize() override {}

private:
    float time_ = 0.0f;
};
