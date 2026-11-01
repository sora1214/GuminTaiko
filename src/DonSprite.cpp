#include "DonSprite.hpp"

#include <algorithm>

namespace {

constexpr Color kInk{52, 26, 18, 255};
constexpr Color kCream{255, 246, 222, 255};
constexpr Color kWhite{255, 255, 255, 255};

float Clamp01(float v) { return std::min(1.0f, std::max(0.0f, v)); }

Color Mix(Color a, Color b, float t) {
    t = Clamp01(t);
    return Color{
        (unsigned char)(a.r + (b.r - a.r) * t),
        (unsigned char)(a.g + (b.g - a.g) * t),
        (unsigned char)(a.b + (b.b - a.b) * t),
        (unsigned char)(a.a + (b.a - a.a) * t),
    };
}

Color WithAlpha(Color c, float alpha) {
    c.a = (unsigned char)(c.a * Clamp01(alpha));
    return c;
}

} // namespace

void DrawDonSprite(Vector2 c, float r, int side, int costume, bool gray, float alpha) {
    auto tone = [&](Color col) {
        if (gray) {
            const unsigned char l = (unsigned char)(0.3f * col.r + 0.59f * col.g + 0.11f * col.b);
            col = Mix(col, Color{l, l, l, col.a}, 0.85f);
            col = Mix(col, Color{60, 60, 60, col.a}, 0.35f);
        }
        return WithAlpha(col, alpha);
    };
    const Color face = side == 0 ? Color{232, 70, 44, 255} : Color{52, 150, 230, 255};

    // 足と手
    DrawEllipse(int(c.x - r * 0.42f), int(c.y + r * 0.98f), r * 0.26f, r * 0.13f, tone(kInk));
    DrawEllipse(int(c.x + r * 0.42f), int(c.y + r * 0.98f), r * 0.26f, r * 0.13f, tone(kInk));
    for (float s : {-1.0f, 1.0f}) {
        DrawCircleV(Vector2{c.x + s * r * 1.02f, c.y + r * 0.25f}, r * 0.17f, tone(kInk));
        DrawCircleV(Vector2{c.x + s * r * 1.02f, c.y + r * 0.25f}, r * 0.11f, tone(kCream));
    }

    // 胴のふちと面
    DrawCircleV(c, r * 1.04f, tone(kInk));
    DrawCircleV(c, r * 0.97f, tone(kCream));
    DrawCircleV(c, r * 0.80f, tone(face));

    // 目
    for (float s : {-1.0f, 1.0f}) {
        const Vector2 eye{c.x + s * r * 0.30f, c.y - r * 0.10f};
        DrawEllipse(int(eye.x), int(eye.y), r * 0.085f, r * 0.11f, tone(kInk));
        DrawCircleV(Vector2{eye.x - r * 0.02f, eye.y - r * 0.045f}, r * 0.035f, tone(kWhite));
    }
    // ほっぺ
    for (float s : {-1.0f, 1.0f}) {
        DrawEllipse(int(c.x + s * r * 0.52f), int(c.y + r * 0.14f), r * 0.12f, r * 0.07f, tone(Color{255, 170, 170, 200}));
    }
    // 口
    DrawCircleSector(Vector2{c.x, c.y + r * 0.06f}, r * 0.20f, 0.0f, 180.0f, 24, tone(Color{110, 20, 20, 255}));
    DrawCircleSector(Vector2{c.x, c.y + r * 0.17f}, r * 0.09f, 0.0f, 180.0f, 16, tone(Color{255, 120, 120, 255}));

    // きせかえ
    switch (costume) {
    case 1: // クール：サングラス
        DrawRectangleRounded(Rectangle{c.x - r * 0.52f, c.y - r * 0.25f, r * 0.42f, r * 0.26f}, 0.5f, 8, tone(kInk));
        DrawRectangleRounded(Rectangle{c.x + r * 0.10f, c.y - r * 0.25f, r * 0.42f, r * 0.26f}, 0.5f, 8, tone(kInk));
        DrawRectangle(int(c.x - r * 0.12f), int(c.y - r * 0.18f), int(r * 0.24f), int(std::max(2.0f, r * 0.05f)), tone(kInk));
        DrawCircleV(Vector2{c.x - r * 0.40f, c.y - r * 0.17f}, r * 0.04f, tone(kWhite));
        DrawCircleV(Vector2{c.x + r * 0.22f, c.y - r * 0.17f}, r * 0.04f, tone(kWhite));
        break;
    case 2: { // キュート：リボン
        const Vector2 bow{c.x + r * 0.50f, c.y - r * 0.82f};
        const Color pink = tone(Color{255, 110, 170, 255});
        DrawEllipse(int(bow.x - r * 0.20f), int(bow.y), r * 0.22f, r * 0.15f, tone(kInk));
        DrawEllipse(int(bow.x + r * 0.20f), int(bow.y), r * 0.22f, r * 0.15f, tone(kInk));
        DrawEllipse(int(bow.x - r * 0.20f), int(bow.y), r * 0.18f, r * 0.11f, pink);
        DrawEllipse(int(bow.x + r * 0.20f), int(bow.y), r * 0.18f, r * 0.11f, pink);
        DrawCircleV(bow, r * 0.09f, tone(kInk));
        DrawCircleV(bow, r * 0.06f, pink);
        break;
    }
    case 3: // ジョーク：鼻とヒゲ
        DrawEllipse(int(c.x - r * 0.14f), int(c.y + r * 0.07f), r * 0.16f, r * 0.06f, tone(kInk));
        DrawEllipse(int(c.x + r * 0.14f), int(c.y + r * 0.07f), r * 0.16f, r * 0.06f, tone(kInk));
        DrawCircleV(Vector2{c.x, c.y - r * 0.01f}, r * 0.08f, tone(Color{255, 200, 120, 255}));
        break;
    default:
        break;
    }
}
