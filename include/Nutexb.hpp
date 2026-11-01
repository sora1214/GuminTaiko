#pragma once
#include <cstdint>
#include <string>
#include <vector>
#include "raylib.h"

namespace GuminTaiko {

// .nutexb の画素フォーマット（フッターの format 値）
enum class NutexbFormat : uint8_t {
    R8_UNORM = 0x00,
    R8G8B8A8_UNORM = 0x40,
    R8G8B8A8_SRGB = 0x45,
    B8G8R8A8_UNORM = 0x50,
    B8G8R8A8_SRGB = 0x55,
    BC1_UNORM = 0x80,
    BC1_SRGB = 0x85,
    BC2_UNORM = 0x90,
    BC2_SRGB = 0x95,
    BC3_UNORM = 0xA0,
    BC3_SRGB = 0xA5,
    BC4_UNORM = 0xB0,
    BC5_UNORM = 0xC0,
    BC7_UNORM = 0xE0,
    BC7_SRGB = 0xE5,
};

// .nutexb の読み込み結果
// ファイル構成: [画像データ][レイヤーごとのミップサイズ表 0x40 バイト × レイヤー数][フッター 0x70 バイト]
struct NutexbFile {
    std::string name;
    int width = 0;
    int height = 0;
    int depth = 0;
    int mipCount = 0;
    int layerCount = 0;
    uint8_t format = 0;
    std::vector<Image> layers;   // 各レイヤーのミップ0を RGBA8 に展開したもの
};

// 失敗時は false を返し、error に理由を入れる
bool LoadNutexb(const char* path, NutexbFile& out, std::string* error = nullptr);
void UnloadNutexb(NutexbFile& file);

// 展開せずに読み込んだもの（必要な範囲だけあとで展開する。巨大なフォント画像用）
struct NutexbRaw {
    NutexbFile info;               // layers は空
    std::vector<uint8_t> data;     // ファイルの中身そのまま
    size_t layerStride = 0;
};
bool LoadNutexbRaw(const char* path, NutexbRaw& out, std::string* error = nullptr);
// (x, y, w, h) の範囲を RGBA8 で rgba（w*h*4 バイト）に展開する
void DecodeNutexbRect(const NutexbRaw& raw, int layer, int x, int y, int w, int h, uint8_t* rgba);

const char* NutexbFormatName(uint8_t format);

} // namespace GuminTaiko
