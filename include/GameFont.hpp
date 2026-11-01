#pragma once
#include <memory>
#include <set>
#include <unordered_map>
#include <vector>
#include "raylib.h"

enum class TextAlign { Left, Center, Right };

// ゲーム内フォントの選び方。Auto: 大きさで選ぶ（40 以下は jp_32_B、それより大きいと jp_64）
//   ExtraBold: jp_32_EB（極太）  Large: jp_64（選曲のジャンルの看板と同じ字形。小さく描いても使う）
enum class FontFace { Auto, ExtraBold, Large };

// 文字の描画
// ゲーム内フォント（Data/x64/font/jp_*.nutexb + .xml）を優先して使い、
// 収録されていない文字だけシステムの日本語フォントで補う。
class GameFont {
public:
    static GameFont& Get() {
        static GameFont instance;
        return instance;
    }

    // 使用予定の文字を先に登録しておく（初回描画時の読み込み待ちを防ぐ）
    void Preload(const char* text);

    // y は文字の上端。outline > 0 で縁取り付き。face: ゲーム内フォントの選び方
    void Draw(const char* text, float x, float y, float size, Color color,
              TextAlign align = TextAlign::Left, float outline = 0.0f, Color outlineColor = BLACK, FontFace face = FontFace::Auto);
    Vector2 Measure(const char* text, float size, FontFace face = FontFace::Auto);

    void Unload();

private:
    // ゲーム内フォント（アトラスは圧縮のまま持ち、使う文字だけ展開して小さなアトラスに詰める）
    struct BitmapFont;

    GameFont();
    ~GameFont();

    void LoadBitmapFonts();
    BitmapFont* PickBitmap(float size) const;
    float LineWidth(const std::vector<int>& codepoints, float size);
    void DrawLine(const std::vector<int>& codepoints, float x, float y, float size, Color color);

    // ---- システムフォント（ゲーム内フォントにない文字用） ----
    bool LoadFontFile();
    bool EnsureSystemGlyphs(const std::vector<int>& codepoints);
    void RebuildSystemFont();
    Font PickSystem(float size) const;

    std::vector<unsigned char> fileData_;
    bool fileTried_ = false;
    std::set<int> codepoints_;
    Font large_{};
    Font small_{};
    bool loaded_ = false;

    bool bitmapTried_ = false;
    std::unique_ptr<BitmapFont> bitmapSmall_;
    std::unique_ptr<BitmapFont> bitmapLarge_;
    mutable std::unique_ptr<BitmapFont> bitmapExtraBold_;
    mutable bool extraBoldTried_ = false;
    FontFace face_ = FontFace::Auto;   // Draw / Measure のあいだだけ使うフォント
};
