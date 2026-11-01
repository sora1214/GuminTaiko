#pragma once
#include <memory>
#include "Scene.hpp"

enum class SceneType {
    Entry,          // エントリー画面（カードタッチ / 参加受付）
    Title,          // タイトル・モード選択（1人/2人/段位など）
    SongSelect,     // 楽曲選択画面
    GamePlay        // 演奏画面
};

class SceneManager {
private:
    std::unique_ptr<Scene> currentScene;
    std::unique_ptr<Scene> nextScene;
    std::unique_ptr<Scene> keptScene;      // 次の画面に引き渡す前の画面（ロード画面の幕の後ろに描く）
    bool keepCurrent = false;
    bool nextInitialized = false;

public:
    static SceneManager& GetInstance() {
        static SceneManager instance;
        return instance;
    }

    // シーン切り替えは次の Update の先頭で行う
    // （シーンの Update 中に呼ばれても自分自身を破棄しないため）
    //   keep: 今の画面を後片付けせず、次の画面が TakeKeptScene で受け取れるようにする
    //   initialized: 新しい画面は Initialize 済み（ロード画面が先に準備したもの）
    void ChangeScene(std::unique_ptr<Scene> newScene, bool keep = false, bool initialized = false) {
        nextScene = std::move(newScene);
        keepCurrent = keep;
        nextInitialized = initialized;
    }

    std::unique_ptr<Scene> TakeKeptScene() { return std::move(keptScene); }

    void Update(float deltaTime) {
        if (nextScene) {
            if (keptScene) {
                keptScene->Finalize();
                keptScene.reset();
            }
            if (currentScene) {
                if (keepCurrent) keptScene = std::move(currentScene);
                else currentScene->Finalize();
            }
            currentScene = std::move(nextScene);
            if (!nextInitialized) currentScene->Initialize();
        }
        if (currentScene) currentScene->Update(deltaTime);
    }

    void Draw() {
        if (currentScene) currentScene->Draw();
    }

    void Shutdown() {
        nextScene.reset();
        if (keptScene) {
            keptScene->Finalize();
            keptScene.reset();
        }
        if (currentScene) {
            currentScene->Finalize();
            currentScene.reset();
        }
    }
};
