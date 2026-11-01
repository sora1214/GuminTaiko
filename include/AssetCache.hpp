#pragma once
#include <map>
#include <string>
#include <vector>
#include "raylib.h"

// 展開に時間のかかる素材を一度だけ読み込んで使い回す
class AssetCache {
public:
    static AssetCache& Get() {
        static AssetCache instance;
        return instance;
    }

    // .nutexb の全レイヤーをテクスチャにして返す。読めなかった場合は空の配列
    const std::vector<Texture2D>& Nutexb(const std::string& path);

    void UnloadAll();

private:
    AssetCache() = default;

    std::map<std::string, std::vector<Texture2D>> nutexb_;
};
