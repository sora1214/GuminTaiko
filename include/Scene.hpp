#pragma once

// ゲーム内の各画面（エントリー、曲選択、演奏など）の共通インターフェース
class Scene {
public:
    virtual ~Scene() = default;
    
    virtual void Initialize() = 0;                     // 初期化（画像ロードなど）
    virtual void Update(float deltaTime) = 0;          // ロジック更新（入力チェックなど）
    virtual void Draw() = 0;                           // 描画処理
    virtual void Finalize() = 0;                       // 後処理（リソース解放など）
};