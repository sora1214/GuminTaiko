#pragma once
#include <cstdint>
#include <map>
#include <string>
#include <vector>

// Lumen（.nulm / "LMB"）の読み込み
// Flash に近いアニメーション形式。ファイルは「タグID(u32) + サイズ(u32, 4バイト単位) + データ」の平坦な並びで、
// 0xFF00 で終わる。スプライトやフレームは、直後に続くタグを子要素として持つ。
namespace Lumen {

enum Tag : uint32_t {
    kTagShowFrame = 0x0001,
    kTagPlaceObject = 0x0004,
    kTagRemoveObject = 0x0005,
    kTagDoAction = 0x000C,
    kTagFonts = 0x000A,
    kTagDefineText = 0x0025,
    kTagDefineSprite = 0x0027,
    kTagFrameLabel = 0x002B,
    kTagSymbols = 0xF001,
    kTagColors = 0xF002,
    kTagTransforms = 0xF003,
    kTagBounds = 0xF004,
    kTagActionScript = 0xF005,
    kTagTextureAtlases = 0xF007,
    kTagProperties = 0xF00C,
    kTagDefines = 0xF00D,
    kTagDefineShape = 0xF022,
    kTagGraphic = 0xF024,
    kTagPositions = 0xF103,
    kTagKeyFrame = 0xF105,
    kTagEnd = 0xFF00,
};

struct Matrix {
    float a = 1.0f, b = 0.0f, c = 0.0f, d = 1.0f, x = 0.0f, y = 0.0f;
};

struct ColorF {
    float r = 1.0f, g = 1.0f, b = 1.0f, a = 1.0f;
};

struct Rect {
    float left = 0.0f, top = 0.0f, right = 0.0f, bottom = 0.0f;
};

struct Vertex {
    float x, y, u, v;
};

struct Graphic {
    int atlas = 0;
    int fillType = 0;
    std::vector<Vertex> vertices;
    std::vector<uint16_t> indices;
};

struct Shape {
    int id = 0;
    int bounds = -1;
    std::vector<Graphic> graphics;
};

// 動的テキスト（0x0025）
struct TextField {
    int id = 0;
    std::string initialHtml;    // HTML 形式の初期テキスト
    int font = 0;
    int bounds = -1;            // 表示範囲（F004 の番号）
    int align = 0;              // 0: 左 1: 右 2: 中央（推定）
    float size = 32.0f;
    float leading = 0.0f;       // 縁取りの太さ（文字の大きさの 1〜2 割。以前は行間と見ていたので、行の間隔にも使う）
    int outlineColor = -1;      // 縁取りの色（色表の番号）
    uint32_t raw[16] = {};
};

// 配置命令（0x0004）
struct Placement {
    int characterId = -1;
    int placementId = -1;
    int nameSymbol = 0;
    int mode = 0;              // 1: 新規配置 2: 既存の変更
    int blendMode = 0;
    int depth = 0;
    int clipDepth = 0;         // マスク: 0 より大きければ、この形で depth+1〜clipDepth に置かれたものを切り抜く（自分は描かない）
    int transformIndex = -1;
    int transformFlags = 0;    // 0: F003 の行列 / それ以外: F103 の座標など（調査中）
    int colorMult = -1;
    int colorAdd = -1;
    uint32_t raw[12] = {};
};

struct FrameCommand {
    enum class Type { Place, Remove, Action, Unknown } type = Type::Unknown;
    Placement place;
    int depth = 0;            // Remove
    int actionId = -1;        // Action
    uint32_t tag = 0;
    std::vector<uint32_t> raw;
};

struct Frame {
    int id = 0;
    std::vector<FrameCommand> commands;
};

struct Label {
    std::string name;
    int frame = 0;
};

struct Sprite {
    int id = 0;
    uint32_t header[7] = {};
    std::vector<Label> labels;
    std::vector<Frame> frames;
    std::vector<Frame> keyFrames;
};

struct Atlas {
    int id = 0;
    std::string name;
    float width = 0.0f;
    float height = 0.0f;
};

struct File {
    std::vector<std::string> symbols;
    std::vector<ColorF> colors;
    std::vector<Matrix> transforms;
    std::vector<Matrix> positions;       // F103 の座標を平行移動の行列にしたもの
    std::vector<Rect> bounds;
    std::vector<std::vector<uint8_t>> actions;
    std::vector<Atlas> atlases;
    std::map<int, Shape> shapes;
    std::map<int, Sprite> sprites;
    std::map<int, TextField> texts;
    std::vector<uint32_t> properties;
    std::vector<uint32_t> defines;
    std::map<uint32_t, int> unknownTags;   // 未解析タグの出現数

    int rootId = -1;
    float frameRate = 60.0f;
    float width = 0.0f;
    float height = 0.0f;

    const std::string& Symbol(int index) const;
};

bool Load(const char* path, File& out, std::string* error = nullptr);

} // namespace Lumen
