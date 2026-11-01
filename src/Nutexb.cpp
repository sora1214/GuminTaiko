#include "Nutexb.hpp"

#include <algorithm>
#include <cstring>
#include <fstream>

#define BCDEC_IMPLEMENTATION
#include "bcdec.h"

namespace GuminTaiko {

namespace {

constexpr size_t kFooterSize = 0x70;
constexpr size_t kMipTableSizePerLayer = 0x40;

uint32_t ReadU32(const uint8_t* p) {
    return uint32_t(p[0]) | (uint32_t(p[1]) << 8) | (uint32_t(p[2]) << 16) | (uint32_t(p[3]) << 24);
}

bool Fail(std::string* error, const std::string& message) {
    if (error) *error = message;
    return false;
}

// BC 形式のブロックサイズ（非圧縮なら 0）
int BlockBytes(uint8_t format) {
    switch (NutexbFormat(format)) {
    case NutexbFormat::BC1_UNORM:
    case NutexbFormat::BC1_SRGB:
    case NutexbFormat::BC4_UNORM:
        return 8;
    case NutexbFormat::BC2_UNORM:
    case NutexbFormat::BC2_SRGB:
    case NutexbFormat::BC3_UNORM:
    case NutexbFormat::BC3_SRGB:
    case NutexbFormat::BC5_UNORM:
    case NutexbFormat::BC7_UNORM:
    case NutexbFormat::BC7_SRGB:
        return 16;
    default:
        return 0;
    }
}

int PixelBytes(uint8_t format) {
    switch (NutexbFormat(format)) {
    case NutexbFormat::R8_UNORM:
        return 1;
    case NutexbFormat::R8G8B8A8_UNORM:
    case NutexbFormat::R8G8B8A8_SRGB:
    case NutexbFormat::B8G8R8A8_UNORM:
    case NutexbFormat::B8G8R8A8_SRGB:
        return 4;
    default:
        return 0;
    }
}

// 1ブロック（4x4）を RGBA8 に展開する
void DecodeBlock(uint8_t format, const uint8_t* src, uint8_t* dst, int pitch) {
    switch (NutexbFormat(format)) {
    case NutexbFormat::BC1_UNORM:
    case NutexbFormat::BC1_SRGB:
        bcdec_bc1(src, dst, pitch);
        break;
    case NutexbFormat::BC2_UNORM:
    case NutexbFormat::BC2_SRGB:
        bcdec_bc2(src, dst, pitch);
        break;
    case NutexbFormat::BC3_UNORM:
    case NutexbFormat::BC3_SRGB:
        bcdec_bc3(src, dst, pitch);
        break;
    case NutexbFormat::BC4_UNORM: {
        uint8_t r[16];
        bcdec_bc4(src, r, 4);
        for (int y = 0; y < 4; ++y) {
            for (int x = 0; x < 4; ++x) {
                uint8_t* p = dst + y * pitch + x * 4;
                p[0] = p[1] = p[2] = r[y * 4 + x];
                p[3] = 255;
            }
        }
        break;
    }
    case NutexbFormat::BC5_UNORM: {
        uint8_t rg[32];
        bcdec_bc5(src, rg, 8);
        for (int y = 0; y < 4; ++y) {
            for (int x = 0; x < 4; ++x) {
                uint8_t* p = dst + y * pitch + x * 4;
                p[0] = rg[y * 8 + x * 2];
                p[1] = rg[y * 8 + x * 2 + 1];
                p[2] = 0;
                p[3] = 255;
            }
        }
        break;
    }
    case NutexbFormat::BC7_UNORM:
    case NutexbFormat::BC7_SRGB:
        bcdec_bc7(src, dst, pitch);
        break;
    default:
        break;
    }
}

bool DecodeLayer(uint8_t format, const uint8_t* src, size_t srcSize, int width, int height, Image& out,
                 std::string* error) {
    const int blockBytes = BlockBytes(format);
    const int pixelBytes = PixelBytes(format);

    const size_t needed = blockBytes > 0
                              ? size_t((width + 3) / 4) * size_t((height + 3) / 4) * size_t(blockBytes)
                              : size_t(width) * size_t(height) * size_t(pixelBytes);
    if (needed > srcSize) return Fail(error, "画像データがフッターの情報より短いです");

    auto* rgba = static_cast<uint8_t*>(MemAlloc(unsigned(size_t(width) * size_t(height) * 4)));
    if (!rgba) return Fail(error, "メモリを確保できません");

    if (blockBytes > 0) {
        const int blocksX = (width + 3) / 4;
        const int blocksY = (height + 3) / 4;
        const bool exact = width % 4 == 0 && height % 4 == 0;
        uint8_t tmp[4 * 4 * 4];

        for (int by = 0; by < blocksY; ++by) {
            for (int bx = 0; bx < blocksX; ++bx) {
                const uint8_t* block = src + (size_t(by) * blocksX + bx) * blockBytes;
                if (exact) {
                    DecodeBlock(format, block, rgba + (size_t(by) * 4 * width + size_t(bx) * 4) * 4, width * 4);
                    continue;
                }
                // 端のはみ出すブロックは一時領域に展開してから必要分だけ写す
                DecodeBlock(format, block, tmp, 16);
                for (int y = 0; y < 4 && by * 4 + y < height; ++y) {
                    for (int x = 0; x < 4 && bx * 4 + x < width; ++x) {
                        std::memcpy(rgba + (size_t(by * 4 + y) * width + size_t(bx * 4 + x)) * 4, tmp + (y * 4 + x) * 4, 4);
                    }
                }
            }
        }
    } else {
        const size_t count = size_t(width) * size_t(height);
        for (size_t i = 0; i < count; ++i) {
            uint8_t* p = rgba + i * 4;
            switch (NutexbFormat(format)) {
            case NutexbFormat::R8_UNORM:
                p[0] = p[1] = p[2] = src[i];
                p[3] = 255;
                break;
            case NutexbFormat::B8G8R8A8_UNORM:
            case NutexbFormat::B8G8R8A8_SRGB:
                p[0] = src[i * 4 + 2];
                p[1] = src[i * 4 + 1];
                p[2] = src[i * 4 + 0];
                p[3] = src[i * 4 + 3];
                break;
            default:
                std::memcpy(p, src + i * 4, 4);
                break;
            }
        }
    }

    out = Image{};
    out.data = rgba;
    out.width = width;
    out.height = height;
    out.mipmaps = 1;
    out.format = PIXELFORMAT_UNCOMPRESSED_R8G8B8A8;
    return true;
}

} // namespace

bool LoadNutexb(const char* path, NutexbFile& out, std::string* error) {
    out = NutexbFile();

    NutexbRaw raw;
    if (!LoadNutexbRaw(path, raw, error)) return false;
    out = raw.info;

    for (int layer = 0; layer < out.layerCount; ++layer) {
        Image image{};
        const uint8_t* src = raw.data.data() + raw.layerStride * size_t(layer);
        if (!DecodeLayer(out.format, src, raw.layerStride, out.width, out.height, image, error)) {
            UnloadNutexb(out);
            return false;
        }
        out.layers.push_back(image);
    }
    return true;
}

bool LoadNutexbRaw(const char* path, NutexbRaw& out, std::string* error) {
    out = NutexbRaw();

    std::ifstream ifs(path, std::ios::binary | std::ios::ate);
    if (!ifs) return Fail(error, std::string("ファイルを開けません: ") + path);

    const std::streamsize fileSize = ifs.tellg();
    if (fileSize < std::streamsize(kFooterSize)) return Fail(error, "ファイルが小さすぎます");

    out.data.resize(static_cast<size_t>(fileSize));
    ifs.seekg(0);
    if (!ifs.read(reinterpret_cast<char*>(out.data.data()), fileSize)) return Fail(error, "読み込みに失敗しました");

    // フッター
    const uint8_t* footer = out.data.data() + out.data.size() - kFooterSize;
    if (std::memcmp(footer + 0x68, " XET", 4) != 0) return Fail(error, "nutexb ではありません（フッターの識別子が違います）");

    NutexbFile& info = out.info;
    const char* nameBegin = reinterpret_cast<const char*>(footer + 0x04);
    info.name.assign(nameBegin, strnlen(nameBegin, 0x40));
    info.width = int(ReadU32(footer + 0x44));
    info.height = int(ReadU32(footer + 0x48));
    info.depth = int(ReadU32(footer + 0x4C));
    info.format = footer[0x50];
    info.mipCount = int(ReadU32(footer + 0x58));
    info.layerCount = int(ReadU32(footer + 0x60));
    const size_t dataSize = ReadU32(footer + 0x64);

    if (info.width <= 0 || info.height <= 0 || info.layerCount <= 0) return Fail(error, "フッターの画像サイズが不正です");

    // このゲームでは format=0 でも中身が 1画素4バイト（RGBA8）のことがある。データ量で見分ける
    if (NutexbFormat(info.format) == NutexbFormat::R8_UNORM &&
        dataSize >= size_t(info.width) * size_t(info.height) * 4 * size_t(info.layerCount)) {
        info.format = uint8_t(NutexbFormat::R8G8B8A8_UNORM);
    }
    if (BlockBytes(info.format) == 0 && PixelBytes(info.format) == 0) {
        return Fail(error, std::string("未対応のフォーマットです: ") + NutexbFormatName(info.format));
    }
    if (dataSize + kMipTableSizePerLayer * size_t(info.layerCount) + kFooterSize > out.data.size()) {
        return Fail(error, "フッターのデータサイズがファイルサイズと合いません");
    }

    // レイヤーはミップを含めて等間隔に並ぶ
    out.layerStride = dataSize / size_t(info.layerCount);
    return true;
}

void DecodeNutexbRect(const NutexbRaw& raw, int layer, int x, int y, int w, int h, uint8_t* rgba) {
    const NutexbFile& info = raw.info;
    std::memset(rgba, 0, size_t(w) * size_t(h) * 4);
    if (layer < 0 || layer >= info.layerCount) return;
    const uint8_t* src = raw.data.data() + raw.layerStride * size_t(layer);

    const int blockBytes = BlockBytes(info.format);
    if (blockBytes == 0) {
        // 非圧縮は画素ごとに写す
        const int pixelBytes = PixelBytes(info.format);
        for (int py = 0; py < h; ++py) {
            for (int px = 0; px < w; ++px) {
                const int sx = x + px, sy = y + py;
                if (sx < 0 || sy < 0 || sx >= info.width || sy >= info.height) continue;
                const uint8_t* s = src + (size_t(sy) * info.width + sx) * pixelBytes;
                uint8_t* d = rgba + (size_t(py) * w + px) * 4;
                switch (NutexbFormat(info.format)) {
                case NutexbFormat::R8_UNORM: d[0] = d[1] = d[2] = s[0]; d[3] = 255; break;
                case NutexbFormat::B8G8R8A8_UNORM:
                case NutexbFormat::B8G8R8A8_SRGB: d[0] = s[2]; d[1] = s[1]; d[2] = s[0]; d[3] = s[3]; break;
                default: std::memcpy(d, s, 4); break;
                }
            }
        }
        return;
    }

    // 範囲にかかるブロックだけ展開する
    const int blocksX = (info.width + 3) / 4;
    const int bx0 = std::max(0, x / 4), by0 = std::max(0, y / 4);
    const int bx1 = std::min(blocksX - 1, (x + w - 1) / 4), by1 = std::min((info.height + 3) / 4 - 1, (y + h - 1) / 4);
    uint8_t block[4 * 4 * 4];
    for (int by = by0; by <= by1; ++by) {
        for (int bx = bx0; bx <= bx1; ++bx) {
            DecodeBlock(info.format, src + (size_t(by) * blocksX + bx) * blockBytes, block, 16);
            for (int py = 0; py < 4; ++py) {
                const int ty = by * 4 + py - y;
                if (ty < 0 || ty >= h) continue;
                for (int px = 0; px < 4; ++px) {
                    const int tx = bx * 4 + px - x;
                    if (tx < 0 || tx >= w) continue;
                    std::memcpy(rgba + (size_t(ty) * w + tx) * 4, block + (py * 4 + px) * 4, 4);
                }
            }
        }
    }
}

void UnloadNutexb(NutexbFile& file) {
    for (Image& image : file.layers) UnloadImage(image);
    file.layers.clear();
}

const char* NutexbFormatName(uint8_t format) {
    switch (NutexbFormat(format)) {
    case NutexbFormat::R8_UNORM: return "R8_UNORM";
    case NutexbFormat::R8G8B8A8_UNORM: return "R8G8B8A8_UNORM";
    case NutexbFormat::R8G8B8A8_SRGB: return "R8G8B8A8_SRGB";
    case NutexbFormat::B8G8R8A8_UNORM: return "B8G8R8A8_UNORM";
    case NutexbFormat::B8G8R8A8_SRGB: return "B8G8R8A8_SRGB";
    case NutexbFormat::BC1_UNORM: return "BC1_UNORM";
    case NutexbFormat::BC1_SRGB: return "BC1_SRGB";
    case NutexbFormat::BC2_UNORM: return "BC2_UNORM";
    case NutexbFormat::BC2_SRGB: return "BC2_SRGB";
    case NutexbFormat::BC3_UNORM: return "BC3_UNORM";
    case NutexbFormat::BC3_SRGB: return "BC3_SRGB";
    case NutexbFormat::BC4_UNORM: return "BC4_UNORM";
    case NutexbFormat::BC5_UNORM: return "BC5_UNORM";
    case NutexbFormat::BC7_UNORM: return "BC7_UNORM";
    case NutexbFormat::BC7_SRGB: return "BC7_SRGB";
    }
    return TextFormat("不明(0x%02X)", format);
}

} // namespace GuminTaiko
