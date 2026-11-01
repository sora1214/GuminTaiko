#include "AssetCache.hpp"

#include "Nutexb.hpp"

const std::vector<Texture2D>& AssetCache::Nutexb(const std::string& path) {
    auto found = nutexb_.find(path);
    if (found != nutexb_.end()) return found->second;

    // 失敗しても空の配列を登録して、毎回読み直さないようにする
    std::vector<Texture2D>& textures = nutexb_[path];

    GuminTaiko::NutexbFile file;
    std::string error;
    if (!GuminTaiko::LoadNutexb(path.c_str(), file, &error)) {
        TraceLog(LOG_WARNING, "AssetCache: %s を読み込めません: %s", path.c_str(), error.c_str());
        return textures;
    }

    for (const Image& image : file.layers) {
        Texture2D texture = LoadTextureFromImage(image);
        SetTextureFilter(texture, TEXTURE_FILTER_BILINEAR);
        textures.push_back(texture);
    }
    GuminTaiko::UnloadNutexb(file);
    return textures;
}

void AssetCache::UnloadAll() {
    for (auto& entry : nutexb_) {
        for (Texture2D& texture : entry.second) UnloadTexture(texture);
    }
    nutexb_.clear();
}
