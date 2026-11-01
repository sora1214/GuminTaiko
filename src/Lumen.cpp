#include "Lumen.hpp"

#include <cstring>
#include <fstream>

namespace Lumen {

namespace {

constexpr size_t kHeaderSize = 0x40;

class Reader {
public:
    Reader(const std::vector<uint8_t>& data, size_t begin, size_t end) : data_(data), pos_(begin), end_(end) {}

    bool Has(size_t bytes) const { return pos_ + bytes <= end_; }
    size_t Pos() const { return pos_; }

    uint32_t U32() {
        if (!Has(4)) return 0;
        uint32_t v;
        std::memcpy(&v, &data_[pos_], 4);
        pos_ += 4;
        return v;
    }
    int32_t I32() { return int32_t(U32()); }
    uint16_t U16() {
        if (!Has(2)) return 0;
        uint16_t v;
        std::memcpy(&v, &data_[pos_], 2);
        pos_ += 2;
        return v;
    }
    int16_t I16() { return int16_t(U16()); }
    float F32() {
        const uint32_t bits = U32();
        float v;
        std::memcpy(&v, &bits, 4);
        return v;
    }
    void Skip(size_t bytes) { pos_ += bytes; }
    const uint8_t* Ptr() const { return &data_[pos_]; }

private:
    const std::vector<uint8_t>& data_;
    size_t pos_;
    size_t end_;
};

struct TagHeader {
    uint32_t tag = 0;
    size_t size = 0;      // バイト
    size_t data = 0;      // データの開始位置
};

class Parser {
public:
    Parser(const std::vector<uint8_t>& data, File& out) : data_(data), out_(out) {}

    bool Run(std::string* error) {
        pos_ = kHeaderSize;
        while (pos_ + 8 <= data_.size()) {
            const TagHeader tag = Next();
            if (tag.tag == kTagEnd) return true;
            ParseTopLevel(tag);
        }
        if (error) *error = "終端タグ(0xFF00)が見つかりません";
        return false;
    }

private:
    TagHeader Next() {
        TagHeader h;
        std::memcpy(&h.tag, &data_[pos_], 4);
        uint32_t words;
        std::memcpy(&words, &data_[pos_ + 4], 4);
        h.size = size_t(words) * 4;
        h.data = pos_ + 8;
        pos_ = h.data + h.size;
        return h;
    }

    TagHeader Peek() const {
        TagHeader h;
        if (pos_ + 8 > data_.size()) return h;
        std::memcpy(&h.tag, &data_[pos_], 4);
        uint32_t words;
        std::memcpy(&words, &data_[pos_ + 4], 4);
        h.size = size_t(words) * 4;
        h.data = pos_ + 8;
        return h;
    }

    Reader At(const TagHeader& tag) const { return Reader(data_, tag.data, tag.data + tag.size); }

    std::string Symbol(int index) const {
        return index >= 0 && size_t(index) < out_.symbols.size() ? out_.symbols[size_t(index)] : std::string();
    }

    std::vector<uint32_t> Raw(const TagHeader& tag) const {
        std::vector<uint32_t> raw(tag.size / 4);
        if (!raw.empty()) std::memcpy(raw.data(), &data_[tag.data], raw.size() * 4);
        return raw;
    }

    void ParseTopLevel(const TagHeader& tag) {
        Reader r = At(tag);
        switch (tag.tag) {
        case kTagSymbols: {
            const uint32_t count = r.U32();
            for (uint32_t i = 0; i < count && r.Has(4); ++i) {
                const uint32_t len = r.U32();
                out_.symbols.emplace_back(reinterpret_cast<const char*>(r.Ptr()), len);
                r.Skip((len / 4 + 1) * 4);   // 終端の 0 を含めて 4 バイト境界
            }
            break;
        }
        case kTagColors: {
            const uint32_t count = r.U32();
            for (uint32_t i = 0; i < count; ++i) {
                ColorF c;
                c.r = r.I16() / 256.0f;
                c.g = r.I16() / 256.0f;
                c.b = r.I16() / 256.0f;
                c.a = r.I16() / 256.0f;
                out_.colors.push_back(c);
            }
            break;
        }
        case kTagTransforms: {
            const uint32_t count = r.U32();
            for (uint32_t i = 0; i < count; ++i) {
                Matrix m;
                m.a = r.F32();
                m.b = r.F32();
                m.c = r.F32();
                m.d = r.F32();
                m.x = r.F32();
                m.y = r.F32();
                out_.transforms.push_back(m);
            }
            break;
        }
        case kTagPositions: {
            const uint32_t count = r.U32();
            for (uint32_t i = 0; i < count; ++i) {
                Matrix m;
                m.x = r.F32();
                m.y = r.F32();
                out_.positions.push_back(m);
            }
            break;
        }
        case kTagBounds: {
            const uint32_t count = r.U32();
            for (uint32_t i = 0; i < count; ++i) {
                Rect b;
                b.left = r.F32();
                b.top = r.F32();
                b.right = r.F32();
                b.bottom = r.F32();
                out_.bounds.push_back(b);
            }
            break;
        }
        case kTagActionScript: {
            const uint32_t count = r.U32();
            for (uint32_t i = 0; i < count && r.Has(4); ++i) {
                const uint32_t len = r.U32();
                out_.actions.emplace_back(r.Ptr(), r.Ptr() + len);
                r.Skip((len + 3) / 4 * 4);
            }
            break;
        }
        case kTagTextureAtlases: {
            const uint32_t count = r.U32();
            for (uint32_t i = 0; i < count; ++i) {
                Atlas a;
                a.id = r.I32();
                const int name = r.I32();
                a.name = name >= 0 && size_t(name) < out_.symbols.size() ? out_.symbols[size_t(name)] : "";
                a.width = r.F32();
                a.height = r.F32();
                out_.atlases.push_back(a);
            }
            break;
        }
        case kTagProperties:
            out_.properties = Raw(tag);
            break;
        case kTagDefines:
            out_.defines = Raw(tag);
            break;
        case kTagDefineShape:
            ParseShape(tag);
            break;
        case kTagDefineSprite:
            ParseSprite(tag);
            break;
        case kTagDefineText: {
            TextField text;
            const std::vector<uint32_t> raw = Raw(tag);
            for (size_t i = 0; i < 16 && i < raw.size(); ++i) text.raw[i] = raw[i];
            // [id, ?, 初期テキスト, フォント, 縁取りの色, 表示範囲, ?, ?, 揃え(u16), ?, ?, ?, サイズ, ?, ?, 縁取りの太さ]
            text.id = r.I32();
            r.U32();
            text.initialHtml = Symbol(r.I32());
            text.font = r.I32();
            text.outlineColor = r.I32();
            text.bounds = r.I32();
            r.U32();
            r.U32();
            text.align = r.U16();
            r.U16();
            r.U32();
            r.U32();
            text.size = r.F32();
            r.U32();
            r.U32();
            r.U32();
            text.leading = r.F32();
            out_.texts[text.id] = std::move(text);
            break;
        }
        default:
            ++out_.unknownTags[tag.tag];
            break;
        }
    }

    void ParseShape(const TagHeader& tag) {
        Reader r = At(tag);
        Shape shape;
        shape.id = r.I32();
        r.U32();
        shape.bounds = r.I32();
        r.U32();
        const uint32_t graphicCount = r.U32();

        for (uint32_t i = 0; i < graphicCount; ++i) {
            if (Peek().tag != kTagGraphic) break;
            const TagHeader g = Next();
            Reader gr = At(g);
            Graphic graphic;
            graphic.atlas = gr.I32();
            graphic.fillType = gr.U16();
            const uint16_t vertexCount = gr.U16();
            const uint32_t indexCount = gr.U32();
            for (uint16_t v = 0; v < vertexCount; ++v) {
                Vertex vert;
                vert.x = gr.F32();
                vert.y = gr.F32();
                vert.u = gr.F32();
                vert.v = gr.F32();
                graphic.vertices.push_back(vert);
            }
            for (uint32_t n = 0; n < indexCount; ++n) graphic.indices.push_back(gr.U16());
            shape.graphics.push_back(std::move(graphic));
        }
        out_.shapes[shape.id] = std::move(shape);
    }

    void ParseSprite(const TagHeader& tag) {
        Reader r = At(tag);
        Sprite sprite;
        for (uint32_t& h : sprite.header) h = r.U32();
        sprite.id = int(sprite.header[0]);

        const uint32_t labelCount = sprite.header[3];
        const uint32_t frameCount = sprite.header[4];
        const uint32_t keyFrameCount = sprite.header[5];

        // ラベル・フレーム・キーフレームが指定の数だけ続く
        while (sprite.labels.size() < labelCount || sprite.frames.size() < frameCount ||
               sprite.keyFrames.size() < keyFrameCount) {
            const TagHeader peek = Peek();
            if (peek.tag == kTagFrameLabel) {
                const TagHeader t = Next();
                Reader lr = At(t);
                Label label;
                const int name = lr.I32();
                label.name = name >= 0 && size_t(name) < out_.symbols.size() ? out_.symbols[size_t(name)] : "";
                label.frame = lr.I32();
                sprite.labels.push_back(label);
            } else if (peek.tag == kTagShowFrame || peek.tag == kTagKeyFrame) {
                const TagHeader t = Next();
                Reader fr = At(t);
                Frame frame;
                frame.id = fr.I32();
                const uint32_t children = fr.U32();
                for (uint32_t i = 0; i < children; ++i) frame.commands.push_back(ParseCommand(Next()));
                (t.tag == kTagShowFrame ? sprite.frames : sprite.keyFrames).push_back(std::move(frame));
            } else {
                break;   // 想定外のタグ。ここで打ち切る
            }
        }
        out_.sprites[sprite.id] = std::move(sprite);
    }

    FrameCommand ParseCommand(const TagHeader& tag) {
        FrameCommand cmd;
        cmd.tag = tag.tag;
        cmd.raw = Raw(tag);
        Reader r = At(tag);

        switch (tag.tag) {
        case kTagPlaceObject: {
            cmd.type = FrameCommand::Type::Place;
            Placement& p = cmd.place;
            for (int i = 0; i < 12 && i < int(cmd.raw.size()); ++i) p.raw[i] = cmd.raw[size_t(i)];
            p.characterId = r.I32();
            p.placementId = r.I32();
            r.U32();
            p.nameSymbol = r.I32();
            p.mode = r.U16();
            p.blendMode = r.U16();
            p.depth = r.U16();
            p.clipDepth = r.U16();   // マスク（onp_jump の風船の虹など）
            r.U32();
            // 符号なし（32767 を超える番号がある。musicintro など）。0xFFFF はなし
            {
                const uint16_t index = r.U16();
                p.transformIndex = index == 0xFFFF ? -1 : int(index);
            }
            p.transformFlags = r.U16();
            p.colorMult = r.I32();
            p.colorAdd = r.I32();
            break;
        }
        case kTagRemoveObject:
            cmd.type = FrameCommand::Type::Remove;
            r.U32();
            cmd.depth = r.U16();
            break;
        case kTagDoAction:
            cmd.type = FrameCommand::Type::Action;
            cmd.actionId = r.I32();
            break;
        default:
            ++out_.unknownTags[tag.tag];
            break;
        }
        return cmd;
    }

    const std::vector<uint8_t>& data_;
    File& out_;
    size_t pos_ = 0;
};

} // namespace

const std::string& File::Symbol(int index) const {
    static const std::string kEmpty;
    return index >= 0 && size_t(index) < symbols.size() ? symbols[size_t(index)] : kEmpty;
}

bool Load(const char* path, File& out, std::string* error) {
    out = File();

    std::ifstream ifs(path, std::ios::binary | std::ios::ate);
    if (!ifs) {
        if (error) *error = std::string("ファイルを開けません: ") + path;
        return false;
    }
    const std::streamsize size = ifs.tellg();
    std::vector<uint8_t> data(static_cast<size_t>(size));
    ifs.seekg(0);
    ifs.read(reinterpret_cast<char*>(data.data()), size);

    if (data.size() < kHeaderSize || std::memcmp(data.data(), "LMB", 4) != 0) {
        if (error) *error = "LMB ファイルではありません";
        return false;
    }

    Parser parser(data, out);
    if (!parser.Run(error)) return false;

    // プロパティ: [.., .., .., 最大キャラクターID, -1, ルートのキャラクターID, 最大深度, fps, 幅, 高さ, ...]
    if (out.properties.size() >= 10) {
        out.rootId = int(out.properties[5]);
        float f[3];
        std::memcpy(f, &out.properties[7], sizeof(f));
        out.frameRate = f[0];
        out.width = f[1];
        out.height = f[2];
    }
    return true;
}

} // namespace Lumen
