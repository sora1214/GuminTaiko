#include "GameFont.hpp"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <sstream>
#include <string>

#include "Nutexb.hpp"
#include "rlgl.h"

namespace {

// ---- ゲーム内フォント ----
constexpr const char* kBitmapSmall = "Data/x64/font/jp_32_B";   // 32pt（小さい文字用）
constexpr const char* kBitmapLarge = "Data/x64/font/jp_64";     // 64pt（大きい文字用）
constexpr const char* kBitmapExtraBold = "Data/x64/font/jp_32_EB";   // 32pt 極太（ネームプレートの名前など）
constexpr float kBitmapLargeThreshold = 40.0f;
constexpr float kTextDownShift = 0.08f;   // 文字を下げる量（文字の大きさに対する割合）
constexpr int kAtlasSize = 2048;
constexpr int kAtlasPadding = 2;

// ---- システムフォント（ゲーム内フォントにない文字用） ----
const char* const kFontCandidates[] = {
    "Data/x64/font/GuminTaiko.ttf",
    "C:/Windows/Fonts/BIZ-UDGothicB.ttc",
    "C:/Windows/Fonts/meiryob.ttc",
    "C:/Windows/Fonts/YuGothB.ttc",
    "C:/Windows/Fonts/msgothic.ttc",
    "C:/Windows/Fonts/NotoSansJP-VF.ttf",
};
constexpr int kLargeSize = 72;
constexpr int kSmallSize = 36;
constexpr float kSmallThreshold = 40.0f;

uint32_t ReadBE32(const unsigned char* p) {
    return (uint32_t(p[0]) << 24) | (uint32_t(p[1]) << 16) | (uint32_t(p[2]) << 8) | uint32_t(p[3]);
}

uint16_t ReadBE16(const unsigned char* p) {
    return uint16_t((p[0] << 8) | p[1]);
}

// TTC（フォントコレクション）の先頭フォントを単体の TTF として読めるようにする。
// テーブルのオフセットはファイル先頭からの絶対位置なので、
// 先頭フォントのテーブルディレクトリをファイル先頭へ移すだけでよい。
bool ConvertTtcToTtf(std::vector<unsigned char>& data) {
    if (data.size() < 16 || std::memcmp(data.data(), "ttcf", 4) != 0) return true;

    const uint32_t offset = ReadBE32(&data[12]);
    if (size_t(offset) + 12 > data.size()) return false;

    const uint16_t numTables = ReadBE16(&data[offset + 4]);
    const size_t dirSize = 12 + 16 * size_t(numTables);
    if (size_t(offset) + dirSize > data.size()) return false;

    std::memmove(data.data(), data.data() + offset, dirSize);
    return true;
}

void AddRange(std::set<int>& set, int first, int last) {
    for (int c = first; c <= last; ++c) set.insert(c);
}

// xml の属性 name="値" を数値で読む
int Attribute(const std::string& line, const char* name) {
    const std::string key = std::string(name) + "=\"";
    const size_t pos = line.find(key);
    return pos == std::string::npos ? 0 : std::atoi(line.c_str() + pos + key.size());
}

// UTF-8 を行ごとのコードポイント列にする
std::vector<std::vector<int>> SplitCodepoints(const char* text) {
    std::vector<std::vector<int>> lines(1);
    while (*text != '\0') {
        int bytes = 1;
        const int codepoint = GetCodepointNext(text, &bytes);
        if (bytes < 1) bytes = 1;
        text += bytes;
        if (codepoint == '\n') lines.emplace_back();
        else if (codepoint != '\r') lines.back().push_back(codepoint);
    }
    return lines;
}

} // namespace

// ===========================================================================
// ゲーム内フォント
// ===========================================================================
struct GameFont::BitmapFont {
    struct Source {
        int u, v, w, h;
    };

    GuminTaiko::NutexbRaw raw;
    std::unordered_map<int, Source> table;
    float point = 32.0f;        // 文字の大きさ（pt）
    float cellHeight = 43.0f;   // 1文字の画像の高さ

    Image atlas{};
    Texture2D texture{};
    std::unordered_map<int, Rectangle> packed;
    int penX = kAtlasPadding;
    int penY = kAtlasPadding;
    int rowHeight = 0;

    bool Load(const std::string& base) {
        std::ifstream xml(base + ".xml");
        if (!xml) return false;

        // <font fontPoint="32" ...> と <glyph index="コードポイント" offsetU offsetV width height>
        std::string line;
        std::unordered_map<int, int> heights;
        while (std::getline(xml, line)) {
            if (line.find("<glyph ") != std::string::npos) {
                const Source s{Attribute(line, "offsetU"), Attribute(line, "offsetV"), Attribute(line, "width"),
                               Attribute(line, "height")};
                table[Attribute(line, "index")] = s;
                ++heights[s.h];
            } else if (line.find("<font ") != std::string::npos) {
                point = float(Attribute(line, "fontPoint"));
            }
        }
        if (table.empty() || point <= 0.0f) return false;

        // 一番多い高さを1文字の高さとみなす
        int best = 0;
        for (auto& h : heights) {
            if (h.second > best) {
                best = h.second;
                cellHeight = float(h.first);
            }
        }

        std::string error;
        if (!GuminTaiko::LoadNutexbRaw((base + ".nutexb").c_str(), raw, &error)) {
            TraceLog(LOG_WARNING, "GameFont: %s.nutexb を読み込めません: %s", base.c_str(), error.c_str());
            return false;
        }

        atlas = GenImageColor(kAtlasSize, kAtlasSize, Color{255, 255, 255, 0});
        texture = LoadTextureFromImage(atlas);
        SetTextureFilter(texture, TEXTURE_FILTER_BILINEAR);
        TraceLog(LOG_INFO, "GameFont: %s（%zu 文字）を使用します", base.c_str(), table.size());
        return true;
    }

    void Unload() {
        if (texture.id != 0) UnloadTexture(texture);
        if (atlas.data) UnloadImage(atlas);
        texture = Texture2D{};
        atlas = Image{};
        packed.clear();
    }

    bool Has(int codepoint) const { return table.count(codepoint) != 0; }

    // 文字をアトラスに詰めて、その範囲を返す（初めての文字だけ展開する）
    const Rectangle* Glyph(int codepoint) {
        if (auto found = packed.find(codepoint); found != packed.end()) return &found->second;
        auto source = table.find(codepoint);
        if (source == table.end()) return nullptr;
        const Source& s = source->second;
        if (s.w <= 0 || s.h <= 0) return nullptr;

        if (penX + s.w + kAtlasPadding > kAtlasSize) {
            penX = kAtlasPadding;
            penY += rowHeight + kAtlasPadding;
            rowHeight = 0;
        }
        if (penY + s.h + kAtlasPadding > kAtlasSize) {
            // いっぱいになったら詰め直す（めったに起きない）
            packed.clear();
            penX = penY = kAtlasPadding;
            rowHeight = 0;
        }

        std::vector<uint8_t> pixels(size_t(s.w) * size_t(s.h) * 4);
        GuminTaiko::DecodeNutexbRect(raw, 0, s.u, s.v, s.w, s.h, pixels.data());
        const Rectangle rect{float(penX), float(penY), float(s.w), float(s.h)};
        UpdateTextureRec(texture, rect, pixels.data());

        penX += s.w + kAtlasPadding;
        rowHeight = std::max(rowHeight, s.h);
        return &(packed[codepoint] = rect);
    }

    float Advance(int codepoint, float size) const {
        auto found = table.find(codepoint);
        return found == table.end() ? 0.0f : float(found->second.w) * size / point;
    }
};

GameFont::GameFont() = default;
GameFont::~GameFont() = default;

void GameFont::LoadBitmapFonts() {
    if (bitmapTried_) return;
    bitmapTried_ = true;

    auto load = [](const char* base) -> std::unique_ptr<BitmapFont> {
        auto font = std::make_unique<BitmapFont>();
        if (!font->Load(base)) return nullptr;
        return font;
    };
    bitmapSmall_ = load(kBitmapSmall);
    bitmapLarge_ = load(kBitmapLarge);
    if (!bitmapSmall_ && !bitmapLarge_) {
        TraceLog(LOG_WARNING, "GameFont: ゲーム内フォントが見つからないので、システムのフォントで表示します");
    }
}

GameFont::BitmapFont* GameFont::PickBitmap(float size) const {
    if (face_ == FontFace::Large && bitmapLarge_) return bitmapLarge_.get();
    if (face_ == FontFace::ExtraBold) {
        // 極太は使うときに読み込む
        if (!extraBoldTried_) {
            extraBoldTried_ = true;
            auto font = std::make_unique<BitmapFont>();
            if (font->Load(kBitmapExtraBold)) bitmapExtraBold_ = std::move(font);
        }
        if (bitmapExtraBold_) return bitmapExtraBold_.get();
    }
    if (size > kBitmapLargeThreshold && bitmapLarge_) return bitmapLarge_.get();
    return bitmapSmall_ ? bitmapSmall_.get() : bitmapLarge_.get();
}

// ===========================================================================
// 描画
// ===========================================================================
void GameFont::Preload(const char* text) {
    if (text == nullptr) return;
    LoadBitmapFonts();
    std::vector<int> missing;
    for (const std::vector<int>& line : SplitCodepoints(text)) {
        for (int c : line) {
            bool found = false;
            for (BitmapFont* font : {bitmapSmall_.get(), bitmapLarge_.get()}) {
                if (font && font->Has(c)) {
                    font->Glyph(c);
                    found = true;
                }
            }
            if (!found) missing.push_back(c);
        }
    }
    EnsureSystemGlyphs(missing);
}

float GameFont::LineWidth(const std::vector<int>& codepoints, float size) {
    BitmapFont* bitmap = PickBitmap(size);
    const Font system = PickSystem(size);
    float width = 0.0f;
    for (int c : codepoints) {
        if (bitmap && bitmap->Has(c)) {
            width += bitmap->Advance(c, size);
        } else {
            const int index = GetGlyphIndex(system, c);
            const float advance = system.glyphs[index].advanceX != 0 ? float(system.glyphs[index].advanceX)
                                                                      : system.recs[index].width;
            width += advance * size / float(system.baseSize);
        }
    }
    return width;
}

void GameFont::DrawLine(const std::vector<int>& codepoints, float x, float y, float size, Color color) {
    BitmapFont* bitmap = PickBitmap(size);
    const Font system = PickSystem(size);
    for (int c : codepoints) {
        if (bitmap && bitmap->Has(c)) {
            const float scale = size / bitmap->point;
            if (const Rectangle* src = bitmap->Glyph(c)) {
                // 1文字の画像を、行の高さ（size）の中で上下中央に置く
                const float h = src->height * scale;
                const Rectangle dest{x, y + (size - bitmap->cellHeight * scale) * 0.5f, src->width * scale, h};
                DrawTexturePro(bitmap->texture, *src, dest, Vector2{0.0f, 0.0f}, 0.0f, color);
            }
            x += bitmap->Advance(c, size);
        } else {
            if (c != ' ') DrawTextCodepoint(system, c, Vector2{x, y}, size, color);
            const int index = GetGlyphIndex(system, c);
            const float advance = system.glyphs[index].advanceX != 0 ? float(system.glyphs[index].advanceX)
                                                                      : system.recs[index].width;
            x += advance * size / float(system.baseSize);
        }
    }
}

void GameFont::Draw(const char* text, float x, float y, float size, Color color,
                    TextAlign align, float outline, Color outlineColor, FontFace face) {
    if (text == nullptr || *text == '\0' || size <= 0.0f) return;
    LoadBitmapFonts();
    struct FaceScope {
        FontFace& current;
        FaceScope(FontFace& f, FontFace value) : current(f) { current = value; }
        ~FaceScope() { current = FontFace::Auto; }
    } scope{face_, face};

    const std::vector<std::vector<int>> lines = SplitCodepoints(text);
    BitmapFont* bitmap = PickBitmap(size);
    std::vector<int> missing;
    for (const std::vector<int>& line : lines) {
        for (int c : line) {
            if (!bitmap || !bitmap->Has(c)) missing.push_back(c);
        }
    }
    EnsureSystemGlyphs(missing);

    const float lineHeight = size * 1.2f;
    for (size_t l = 0; l < lines.size(); ++l) {
        const float width = LineWidth(lines[l], size);
        float lx = x;
        if (align == TextAlign::Center) lx -= width * 0.5f;
        else if (align == TextAlign::Right) lx -= width;
        // 文字の画像は上寄りに見えるので、行の高さの 8% だけ下げて描く（ゲーム内のすべての文字に効く）
        const float ly = y + float(l) * lineHeight + size * kTextDownShift;

        if (outline > 0.0f && outlineColor.a > 0) {
            const int steps = outline > 3.0f ? 16 : 8;
            for (int i = 0; i < steps; ++i) {
                const float angle = 2.0f * PI * float(i) / float(steps);
                DrawLine(lines[l], lx + std::cos(angle) * outline, ly + std::sin(angle) * outline, size, outlineColor);
            }
        }
        DrawLine(lines[l], lx, ly, size, color);
    }
}

Vector2 GameFont::Measure(const char* text, float size, FontFace face) {
    if (text == nullptr || *text == '\0') return Vector2{0.0f, size};
    LoadBitmapFonts();
    face_ = face;
    struct Reset {
        FontFace& current;
        ~Reset() { current = FontFace::Auto; }
    } reset{face_};

    const std::vector<std::vector<int>> lines = SplitCodepoints(text);
    BitmapFont* bitmap = PickBitmap(size);
    std::vector<int> missing;
    for (const std::vector<int>& line : lines) {
        for (int c : line) {
            if (!bitmap || !bitmap->Has(c)) missing.push_back(c);
        }
    }
    EnsureSystemGlyphs(missing);

    float width = 0.0f;
    for (const std::vector<int>& line : lines) width = std::max(width, LineWidth(line, size));
    return Vector2{width, size + size * 1.2f * float(lines.size() - 1)};
}

void GameFont::Unload() {
    if (loaded_) {
        UnloadFont(large_);
        UnloadFont(small_);
    }
    loaded_ = false;
    if (bitmapSmall_) bitmapSmall_->Unload();
    if (bitmapLarge_) bitmapLarge_->Unload();
    if (bitmapExtraBold_) bitmapExtraBold_->Unload();
    bitmapSmall_.reset();
    bitmapLarge_.reset();
    bitmapTried_ = false;
}

// ===========================================================================
// システムフォント
// ===========================================================================
bool GameFont::LoadFontFile() {
    if (fileTried_) return !fileData_.empty();
    fileTried_ = true;

    for (const char* path : kFontCandidates) {
        if (!FileExists(path)) continue;

        int size = 0;
        unsigned char* raw = LoadFileData(path, &size);
        if (raw == nullptr || size <= 0) continue;

        fileData_.assign(raw, raw + size);
        UnloadFileData(raw);

        if (ConvertTtcToTtf(fileData_)) {
            TraceLog(LOG_INFO, "GameFont: 補助に %s を使用します", path);
            return true;
        }
        fileData_.clear();
    }

    TraceLog(LOG_WARNING, "GameFont: 日本語のシステムフォントが見つかりません");
    return false;
}

bool GameFont::EnsureSystemGlyphs(const std::vector<int>& codepoints) {
    bool changed = false;

    if (codepoints_.empty()) {
        AddRange(codepoints_, 0x20, 0x7E);       // ASCII
        AddRange(codepoints_, 0x3000, 0x303F);   // 和文記号
        AddRange(codepoints_, 0x3041, 0x309F);   // ひらがな
        AddRange(codepoints_, 0x30A0, 0x30FF);   // カタカナ
        AddRange(codepoints_, 0xFF01, 0xFF5E);   // 全角英数
        changed = true;
    }
    for (int c : codepoints) {
        if (codepoints_.insert(c).second) changed = true;
    }

    if (changed || !loaded_) RebuildSystemFont();
    return changed;
}

void GameFont::RebuildSystemFont() {
    if (!LoadFontFile()) return;

    // 描画待ちのバッチが古いフォントのテクスチャを参照しているので先に流す
    rlDrawRenderBatchActive();
    if (loaded_) {
        UnloadFont(large_);
        UnloadFont(small_);
    }

    std::vector<int> codepoints(codepoints_.begin(), codepoints_.end());
    auto load = [&](int size) {
        Font font = LoadFontFromMemory(".ttf", fileData_.data(), int(fileData_.size()), size,
                                       codepoints.data(), int(codepoints.size()));
        if (font.texture.id != 0 && font.texture.id != GetFontDefault().texture.id) {
            GenTextureMipmaps(&font.texture);
            SetTextureFilter(font.texture, TEXTURE_FILTER_TRILINEAR);
        }
        return font;
    };
    large_ = load(kLargeSize);
    small_ = load(kSmallSize);

    const unsigned int defaultId = GetFontDefault().texture.id;
    loaded_ = large_.texture.id != 0 && large_.texture.id != defaultId &&
              small_.texture.id != 0 && small_.texture.id != defaultId;
}

Font GameFont::PickSystem(float size) const {
    if (!loaded_) return GetFontDefault();
    return size <= kSmallThreshold ? small_ : large_;
}
