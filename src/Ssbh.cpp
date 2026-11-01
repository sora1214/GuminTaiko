#include "Ssbh.hpp"

#include <algorithm>
#include <cmath>
#include <cstring>
#include <fstream>
#include <memory>

namespace Ssbh {

namespace {

constexpr size_t kBodyOffset = 0x10;   // "HBSS" のヘッダーの後ろ

class Reader {
public:
    explicit Reader(std::vector<uint8_t> data) : data_(std::move(data)) {}

    bool Valid(size_t pos, size_t size) const { return pos + size <= data_.size(); }
    const uint8_t* At(size_t pos) const { return data_.data() + pos; }
    size_t Size() const { return data_.size(); }

    template <typename T>
    T Read(size_t pos) const {
        T value{};
        if (Valid(pos, sizeof(T))) std::memcpy(&value, &data_[pos], sizeof(T));
        return value;
    }

    // 相対オフセット（0 なら無し）
    size_t Ptr(size_t pos) const {
        const uint64_t offset = Read<uint64_t>(pos);
        return offset == 0 ? 0 : pos + size_t(offset);
    }

    std::string String(size_t pos) const {
        const size_t p = Ptr(pos);
        if (p == 0 || p >= data_.size()) return {};
        const char* s = reinterpret_cast<const char*>(&data_[p]);
        return std::string(s, strnlen(s, data_.size() - p));
    }

    // 配列: 先頭位置と個数
    std::pair<size_t, size_t> Array(size_t pos) const { return {Ptr(pos), size_t(Read<uint64_t>(pos + 8))}; }

private:
    std::vector<uint8_t> data_;
};

bool Fail(std::string* error, const std::string& message) {
    if (error) *error = message;
    return false;
}

bool Open(const std::string& path, const char* magic, Reader*& out, std::vector<uint8_t>& storage, std::string* error) {
    std::ifstream ifs(path, std::ios::binary | std::ios::ate);
    if (!ifs) return Fail(error, "ファイルを開けません: " + path);
    const std::streamsize size = ifs.tellg();
    storage.resize(static_cast<size_t>(size));
    ifs.seekg(0);
    ifs.read(reinterpret_cast<char*>(storage.data()), size);
    if (storage.size() < 0x18 || std::memcmp(storage.data(), "HBSS", 4) != 0 ||
        std::memcmp(storage.data() + kBodyOffset, magic, 4) != 0) {
        return Fail(error, "SSBH ファイルではありません: " + path);
    }
    out = new Reader(std::move(storage));
    return true;
}

float HalfToFloat(uint16_t h) {
    const uint32_t sign = uint32_t(h & 0x8000) << 16;
    uint32_t exponent = (h >> 10) & 0x1F;
    uint32_t mantissa = h & 0x3FF;
    uint32_t bits;
    if (exponent == 0) {
        if (mantissa == 0) {
            bits = sign;
        } else {
            exponent = 1;
            while (!(mantissa & 0x400)) {
                mantissa <<= 1;
                --exponent;
            }
            mantissa &= 0x3FF;
            bits = sign | ((exponent + 112) << 23) | (mantissa << 13);
        }
    } else if (exponent == 31) {
        bits = sign | 0x7F800000 | (mantissa << 13);
    } else {
        bits = sign | ((exponent + 112) << 23) | (mantissa << 13);
    }
    float f;
    std::memcpy(&f, &bits, 4);
    return f;
}

// 属性の値を最大4要素の float で読む（v1.8/1.9 と v1.10 で型の番号が違う）
int ReadAttribute(const Reader& r, size_t pos, uint32_t dataType, float out[4]) {
    switch (dataType) {
    case 820:   // Float3（v1.8/1.9）
        dataType = 0;
        break;
    case 1076:  // Float4
        dataType = 4;
        break;
    case 1077:  // HalfFloat4
        dataType = 5;
        break;
    case 1079:  // Float2
        dataType = 7;
        break;
    case 1024:  // Byte4
        dataType = 2;
        break;
    default:
        break;
    }
    switch (dataType) {
    case 0:  // Float3
        for (int i = 0; i < 3; ++i) out[i] = r.Read<float>(pos + i * 4);
        return 3;
    case 2:  // Byte4
        for (int i = 0; i < 4; ++i) out[i] = r.Read<uint8_t>(pos + i) / 255.0f;
        return 4;
    case 4:  // Float4
        for (int i = 0; i < 4; ++i) out[i] = r.Read<float>(pos + i * 4);
        return 4;
    case 5:  // HalfFloat4
        for (int i = 0; i < 4; ++i) out[i] = HalfToFloat(r.Read<uint16_t>(pos + i * 2));
        return 4;
    case 7:  // Float2
        for (int i = 0; i < 2; ++i) out[i] = r.Read<float>(pos + i * 4);
        return 2;
    case 8:  // HalfFloat2
        for (int i = 0; i < 2; ++i) out[i] = HalfToFloat(r.Read<uint16_t>(pos + i * 2));
        return 2;
    default:
        return 0;
    }
}

} // namespace

// ===========================================================================
// メッシュ
// ===========================================================================
bool LoadMesh(const std::string& path, Mesh& out, std::string* error) {
    out = Mesh();
    std::vector<uint8_t> storage;
    Reader* raw = nullptr;
    if (!Open(path, "HSEM", raw, storage, error)) return false;
    std::unique_ptr<Reader> holder(raw);
    const Reader& r = *raw;

    out.major = r.Read<uint16_t>(0x14);
    out.minor = r.Read<uint16_t>(0x16);
    if (out.major != 1 || out.minor < 9) return Fail(error, "未対応のメッシュのバージョンです");

    const size_t base = 0x18;
    const auto objects = r.Array(base + 0x70);
    const auto vertexBuffers = r.Array(base + 0x98);
    const size_t indexBuffer = r.Ptr(base + 0xA8);
    const auto rigging = r.Array(base + 0xB8);

    std::vector<size_t> buffers;
    for (size_t i = 0; i < vertexBuffers.second; ++i) buffers.push_back(r.Ptr(vertexBuffers.first + i * 16));

    for (size_t i = 0; i < objects.second; ++i) {
        const size_t o = objects.first + i * 0xD0;
        MeshObject obj;
        obj.name = r.String(o);
        obj.subIndex = r.Read<uint64_t>(o + 0x08);
        obj.parentBoneName = r.String(o + 0x10);
        obj.vertexCount = r.Read<uint32_t>(o + 0x18);
        obj.indexCount = r.Read<uint32_t>(o + 0x1C);
        for (int b = 0; b < 4; ++b) {
            obj.vertexBufferOffset[b] = r.Read<uint32_t>(o + 0x24 + b * 4);
            obj.stride[b] = r.Read<uint32_t>(o + 0x34 + b * 4);
        }
        obj.indexBufferOffset = r.Read<uint32_t>(o + 0x44);
        obj.drawElementType = r.Read<uint32_t>(o + 0x4C);
        obj.useSkinning = r.Read<uint32_t>(o + 0x50) != 0;

        const auto attributes = r.Array(o + 0xC0);
        for (size_t a = 0; a < attributes.second; ++a) {
            const size_t ap = attributes.first + a * 48;
            Attribute attr;
            attr.usage = r.Read<uint32_t>(ap);
            attr.dataType = r.Read<uint32_t>(ap + 4);
            attr.bufferIndex = r.Read<uint32_t>(ap + 8);
            attr.bufferOffset = r.Read<uint32_t>(ap + 12);
            attr.name = r.String(ap + 24);
            obj.attributes.push_back(attr);
        }

        // 頂点の展開
        for (const Attribute& attr : obj.attributes) {
            if (attr.bufferIndex >= buffers.size() || buffers[attr.bufferIndex] == 0) continue;
            const size_t start = buffers[attr.bufferIndex] + obj.vertexBufferOffset[attr.bufferIndex] + attr.bufferOffset;
            const size_t stride = obj.stride[attr.bufferIndex];
            std::vector<std::array<float, 2>> uv;
            for (uint32_t v = 0; v < obj.vertexCount; ++v) {
                float value[4] = {0.0f, 0.0f, 0.0f, 1.0f};
                ReadAttribute(r, start + v * stride, attr.dataType, value);
                switch (AttributeUsage(attr.usage)) {
                case AttributeUsage::Position: obj.positions.push_back({value[0], value[1], value[2]}); break;
                case AttributeUsage::Normal: obj.normals.push_back({value[0], value[1], value[2]}); break;
                case AttributeUsage::TextureCoordinate: uv.push_back({value[0], value[1]}); break;
                case AttributeUsage::ColorSet:
                    if (obj.colors.size() < obj.vertexCount && (attr.name == "colorSet1" || obj.colors.empty())) {
                        obj.colors.push_back({value[0], value[1], value[2], value[3]});
                    }
                    break;
                default: break;
                }
            }
            if (!uv.empty()) {
                obj.uvs.push_back(std::move(uv));
                obj.uvNames.push_back(attr.name);
            }
        }

        // インデックス
        const size_t ib = indexBuffer + obj.indexBufferOffset;
        for (uint32_t n = 0; n < obj.indexCount; ++n) {
            obj.indices.push_back(obj.drawElementType == 0 ? r.Read<uint16_t>(ib + n * 2) : r.Read<uint32_t>(ib + n * 4));
        }
        out.objects.push_back(std::move(obj));
    }

    // ボーンの重み
    for (size_t g = 0; g < rigging.second; ++g) {
        const size_t gp = rigging.first + g * 40;
        const std::string name = r.String(gp);
        const uint64_t subIndex = r.Read<uint64_t>(gp + 8);
        MeshObject* target = nullptr;
        for (MeshObject& obj : out.objects) {
            if (obj.name == name && obj.subIndex == subIndex) target = &obj;
        }
        if (!target) continue;

        const auto bones = r.Array(gp + 24);
        for (size_t b = 0; b < bones.second; ++b) {
            const size_t bp = bones.first + b * 24;
            BoneInfluence influence;
            influence.boneName = r.String(bp);
            const size_t data = r.Ptr(bp + 8);
            const size_t size = size_t(r.Read<uint64_t>(bp + 16));
            // v1.10 は u16 + f32（6バイト、サイズはバイト数）
            // それより前は u32 + f32（8バイト、サイズ欄は件数）
            const size_t step = out.minor >= 10 ? 6 : 8;
            const size_t weightOffset = out.minor >= 10 ? 2 : 4;
            const size_t bytes = out.minor >= 10 ? size : size * step;
            for (size_t w = 0; w + step <= bytes; w += step) {
                const uint32_t vertex = step == 6 ? r.Read<uint16_t>(data + w) : r.Read<uint32_t>(data + w);
                influence.weights.push_back({uint16_t(vertex), r.Read<float>(data + w + weightOffset)});
            }
            target->influences.push_back(std::move(influence));
        }
    }
    return true;
}

// ===========================================================================
// スケルトン
// ===========================================================================
int Skeleton::Find(const std::string& name) const {
    for (size_t i = 0; i < bones.size(); ++i) {
        if (bones[i].name == name) return int(i);
    }
    return -1;
}

bool LoadSkeleton(const std::string& path, Skeleton& out, std::string* error) {
    out = Skeleton();
    std::vector<uint8_t> storage;
    Reader* raw = nullptr;
    if (!Open(path, "LEKS", raw, storage, error)) return false;
    std::unique_ptr<Reader> holder(raw);
    const Reader& r = *raw;

    const size_t base = 0x18;
    const auto entries = r.Array(base);
    const auto world = r.Array(base + 16);
    const auto transforms = r.Array(base + 48);
    for (size_t i = 0; i < entries.second; ++i) {
        const size_t e = entries.first + i * 16;
        Bone bone;
        bone.name = r.String(e);
        bone.index = r.Read<uint16_t>(e + 8);
        bone.parent = r.Read<int16_t>(e + 10);
        for (int m = 0; m < 16; ++m) {
            if (i < world.second) bone.world[size_t(m)] = r.Read<float>(world.first + i * 64 + m * 4);
            if (i < transforms.second) bone.transform[size_t(m)] = r.Read<float>(transforms.first + i * 64 + m * 4);
        }
        out.bones.push_back(bone);
    }
    return true;
}

// ===========================================================================
// モデル定義
// ===========================================================================
bool LoadModel(const std::string& path, Model& out, std::string* error) {
    out = Model();
    std::vector<uint8_t> storage;
    Reader* raw = nullptr;
    if (!Open(path, "LDOM", raw, storage, error)) return false;
    std::unique_ptr<Reader> holder(raw);
    const Reader& r = *raw;

    const size_t base = 0x18;
    out.skeletonFile = r.String(base + 8);
    const auto materials = r.Array(base + 16);
    for (size_t i = 0; i < materials.second; ++i) out.materialFiles.push_back(r.String(materials.first + i * 8));
    if (const size_t anim = r.Ptr(base + 32)) out.animationFile = r.String(anim);
    out.meshFile = r.String(base + 40);
    const auto entries = r.Array(base + 48);
    for (size_t i = 0; i < entries.second; ++i) {
        const size_t e = entries.first + i * 24;
        out.entries.push_back({r.String(e), r.Read<uint64_t>(e + 8), r.String(e + 16)});
    }
    return true;
}

// ===========================================================================
// アニメーション（v1.2）
// ===========================================================================
// ヘッダー: 0x28 最後のフレームの番号 f32 / 0x24 フレームレート f32 / 0x30 トラック / 0x40 バッファ
// プロパティのデータ: [種別 u8][形式 u8][u16] …
//   形式: 上位 4 ビットが成分の数（1: 数値, 3: Vector3, 4: クォータニオン）。
//         下位 4 ビットが 3 ならキーのフレーム番号の表（u8 × キーの数、4 バイト境界まで詰め物）が付く。4 なら全フレーム
//   種別 3（一定）: [値]
//   種別 0（圧縮なし）: [キーの数 u32][f32][フレーム番号の表?][値 × キーの数]
//   種別 8（圧縮）: [キーの数 u32][f32][フレーム番号の表?][振れ幅 f32][最初の値][最後の値][成分ごとのチャンネル…]
//     途中のキーの値 = 最初と最後の値をキーの番号で直線に結んだ値 + チャンネルの係数の逆 DCT-IV（ReadChannel）
//   種別 9（区間に分けた圧縮）: [キーの数 u32][f32][フレーム番号の表?][振れ幅 f32]
//     [u16 区間の数][u16 × (区間の数 − 1) 区間 1 以降の係数の位置（4 バイト境界まで詰め物）][区間の境目の値 × (区間の数 + 1)]
//     [区間ごとのチャンネル…]。区間は 33 キー間隔ずつ。位置 0 の区間は係数がなく直線
//   （解読の確かめ: 回転のクォータニオンを戻すと長さが 1 に 0.0003 以内でそろう）
namespace {

std::array<float, 4> ReadValue(const Reader& r, size_t pos, int components) {
    std::array<float, 4> v{0.0f, 0.0f, 0.0f, components == 4 ? 1.0f : 0.0f};
    for (int i = 0; i < components; ++i) v[size_t(i)] = r.Read<float>(pos + size_t(i) * 4);
    return v;
}

// キーのフレーム番号の表を読み、その後ろの位置を返す
size_t ReadFrames(const Reader& r, size_t pos, uint8_t format, uint32_t count, std::vector<float>& frames) {
    frames.clear();
    if ((format & 0x0F) == 3) {
        for (uint32_t i = 0; i < count; ++i) frames.push_back(float(r.Read<uint8_t>(pos + i)));
        return pos + (size_t(count) + 3) / 4 * 4;
    }
    for (uint32_t i = 0; i < count; ++i) frames.push_back(float(i));
    return pos;
}

// 圧縮の1成分: [u16 A][u16 B][u8 C][u8 まとまりの数（上位 16bit / 下位 8bit）][u8 （上位 4bit / 下位 0bit）][u8 段数] の後ろに
// 係数（4つずつのまとまり。16bit → 8bit → 4bit の順、0bit は 0）。係数はキーの番号の順に並んだ途中の値の、直線からのずれの
// DCT-IV（正規直交、長さ M = 4 × まとまりの数）で、段（係数 0〜3 / 4〜11 / 12〜）ごとに最大が ±1 になるよう正規化されている。
//   段の大きさ: s0 = 振れ幅 × A / 65535、s1 = s0 × B / 65535、s2 = s1 × C / 255
// 逆変換（DCT-IV は自分自身が逆変換）の頭の residual.size() 個が途中のキーのずれ。次のチャンネルの位置を返す
size_t ReadChannel(const Reader& r, size_t pos, float range, std::vector<float>& residual) {
    const float A = float(r.Read<uint16_t>(pos)), B = float(r.Read<uint16_t>(pos + 2)), C = float(r.Read<uint8_t>(pos + 4));
    const uint8_t c0 = r.Read<uint8_t>(pos + 5), c1 = r.Read<uint8_t>(pos + 6);
    const int n16 = c0 >> 4, n8 = c0 & 0x0F, n4 = c1 >> 4, n0 = c1 & 0x0F;
    const int M = 4 * (n16 + n8 + n4 + n0);
    std::vector<float> q;
    q.reserve(size_t(M));
    size_t p = pos + 8;
    for (int i = 0; i < n16 * 4; ++i, p += 2) q.push_back(float(r.Read<int16_t>(p)) / 32767.0f);
    for (int i = 0; i < n8 * 4; ++i, p += 1) q.push_back(float(r.Read<int8_t>(p)) / 127.0f);
    for (int i = 0; i < n4 * 4; ++i) {
        const uint8_t byte = r.Read<uint8_t>(p + size_t(i / 2));
        const int nibble = i % 2 == 0 ? byte >> 4 : byte & 0x0F;
        q.push_back(float(nibble - 8) / 7.0f);
    }
    p += size_t(n4) * 2;
    q.resize(size_t(M), 0.0f);
    const float s0 = range * A / 65535.0f, s1 = s0 * B / 65535.0f, s2 = s1 * C / 255.0f;
    for (int k = 0; k < M; ++k) q[size_t(k)] *= k < 4 ? s0 : k < 12 ? s1 : s2;

    const double norm = std::sqrt(2.0 / double(std::max(1, M)));
    constexpr double kPi = 3.14159265358979323846;
    for (size_t n = 0; n < residual.size() && int(n) < M; ++n) {
        double sum = 0.0;
        for (int k = 0; k < M; ++k) sum += double(q[size_t(k)]) * std::cos(kPi * (double(n) + 0.5) * (double(k) + 0.5) / double(M));
        residual[n] = float(norm * sum);
    }
    const size_t bytes = size_t(8 * n16 + 4 * n8 + 2 * n4);
    return pos + 8 + (bytes + 3) / 4 * 4;
}

bool ReadCurve(const Reader& r, size_t data, AnimationCurve& curve) {
    const uint8_t kind = r.Read<uint8_t>(data);
    const uint8_t format = r.Read<uint8_t>(data + 1);
    const int components = format >> 4;
    if (components != 1 && components != 3 && components != 4) return false;
    curve = AnimationCurve();
    curve.components = components;

    if (kind == 3) {
        curve.type = AnimationCurve::Type::Constant;
        curve.frames = {0.0f};
        curve.values = {ReadValue(r, data + 4, components)};
        return true;
    }
    if (kind != 0 && kind != 8 && kind != 9) return false;

    const uint32_t count = r.Read<uint32_t>(data + 4);
    if (count == 0 || count > 4096) return false;
    std::vector<float> frames;
    size_t pos = ReadFrames(r, data + 12, format, count, frames);

    if (kind == 0) {
        curve.type = AnimationCurve::Type::Keys;
        curve.frames = frames;
        for (uint32_t i = 0; i < count; ++i) curve.values.push_back(ReadValue(r, pos + size_t(i) * size_t(components) * 4, components));
        return true;
    }

    // 圧縮（種別 8: 1区間 / 9: 33 キー間隔ずつの区間に分けたもの）。すべてのキーの値に戻す
    const float range = r.Read<float>(pos);
    pos += 4;
    int segments = 1;
    std::vector<uint16_t> offsets;   // 区間 1 以降の係数の位置（区間の係数の頭から 4 バイト単位。0 なら係数なし = 直線）
    if (kind == 9) {
        segments = std::max(1, int(r.Read<uint16_t>(pos)));
        for (int i = 0; i < segments - 1; ++i) offsets.push_back(r.Read<uint16_t>(pos + 2 + size_t(i) * 2));
        pos += (size_t(2 + 2 * (segments - 1)) + 3) / 4 * 4;
    }
    std::vector<std::array<float, 4>> ends;   // 区間の境目のキーの値（区間の数 + 1）
    for (int i = 0; i <= segments; ++i) {
        ends.push_back(ReadValue(r, pos, components));
        pos += size_t(components) * 4;
    }
    const size_t base = pos;
    constexpr int kSegmentKeys = 33;   // 1区間のキーの間隔の数（途中のキーは最大 32）

    curve.type = AnimationCurve::Type::Keys;
    curve.frames = frames;
    curve.values.assign(count, std::array<float, 4>{0.0f, 0.0f, 0.0f, components == 4 ? 1.0f : 0.0f});
    for (int s = 0; s < segments; ++s) {
        const int k0 = s * kSegmentKeys;
        const int k1 = std::min(k0 + kSegmentKeys, int(count) - 1);
        if (k0 >= int(count)) break;
        curve.values[size_t(k0)] = ends[size_t(s)];
        curve.values[size_t(k1)] = ends[size_t(s + 1)];
        const int inner = k1 - k0 - 1;
        if (inner <= 0) continue;
        size_t channel = s == 0 ? base : (offsets[size_t(s - 1)] != 0 ? base + size_t(offsets[size_t(s - 1)]) * 4 : 0);
        for (int c = 0; c < components; ++c) {
            std::vector<float> residual(size_t(inner), 0.0f);
            if (channel != 0) channel = ReadChannel(r, channel, range, residual);
            const float a = ends[size_t(s)][size_t(c)], b = ends[size_t(s + 1)][size_t(c)];
            for (int i = 0; i < inner; ++i) {
                const float t = float(i + 1) / float(inner + 1);
                curve.values[size_t(k0 + 1 + i)][size_t(c)] = a + (b - a) * t + residual[size_t(i)];
            }
        }
    }
    return true;
}

} // namespace

std::array<float, 4> AnimationCurve::Sample(float frame) const {
    std::array<float, 4> out{0.0f, 0.0f, 0.0f, components == 4 ? 1.0f : 0.0f};
    if (values.empty()) return out;
    if (values.size() == 1 || frame <= frames.front()) {
        out = values.front();
    } else if (frame >= frames.back()) {
        out = values.back();
    } else {
        size_t k = 0;
        while (k + 2 < frames.size() && frame >= frames[k + 1]) ++k;
        const float span = frames[k + 1] - frames[k];
        const float t = span > 0.0f ? (frame - frames[k]) / span : 0.0f;
        const std::array<float, 4>& a = values[k];
        const std::array<float, 4>& b = values[k + 1];
        // クォータニオンは向きをそろえてから補間する
        float sign = 1.0f;
        if (components == 4 && a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3] < 0.0f) sign = -1.0f;
        for (size_t i = 0; i < 4; ++i) out[i] = a[i] + (b[i] * sign - a[i]) * t;
    }
    if (components == 4) {
        const float len = std::sqrt(out[0] * out[0] + out[1] * out[1] + out[2] * out[2] + out[3] * out[3]);
        if (len > 0.0f) {
            for (float& v : out) v /= len;
        }
    }
    return out;
}

bool LoadAnimation(const std::string& path, Animation& out, std::string* error) {
    out = Animation();
    std::vector<uint8_t> storage;
    Reader* raw = nullptr;
    if (!Open(path, "MINA", raw, storage, error)) return false;
    std::unique_ptr<Reader> holder(raw);
    const Reader& r = *raw;
    if (r.Read<uint16_t>(0x14) != 1 || r.Read<uint16_t>(0x16) != 2) return Fail(error, "未対応のアニメーションのバージョンです");

    out.frameRate = r.Read<float>(0x24);
    if (!(out.frameRate > 0.0f)) out.frameRate = 60.0f;
    out.frameCount = r.Read<float>(0x28);
    const auto tracks = r.Array(0x30);
    const auto buffers = r.Array(0x40);

    for (size_t t = 0; t < tracks.second; ++t) {
        const size_t tp = tracks.first + t * 32;
        BoneAnimation bone;
        bone.name = r.String(tp);
        const auto props = r.Array(tp + 16);
        for (size_t p = 0; p < props.second; ++p) {
            const size_t pp = props.first + p * 16;
            const std::string name = r.String(pp);
            const size_t index = size_t(r.Read<uint64_t>(pp + 8));
            if (index >= buffers.second) continue;
            const size_t data = r.Ptr(buffers.first + index * 16);
            if (data == 0) continue;

            // CompensateScale: [種別 0x13][形式 0x10][u16] の後ろに u16（0 以外なら有効）
            if (name == "CompensateScale") {
                bone.compensateScale = r.Read<uint16_t>(data + 4) != 0;
                continue;
            }
            AnimationCurve curve;
            if (!ReadCurve(r, data, curve)) continue;
            if (name == "Translate" && curve.components == 3) bone.translate = std::move(curve);
            else if (name == "Rotate" && curve.components == 4) bone.rotate = std::move(curve);
            else if (name == "Scale" && curve.components == 3) bone.scale = std::move(curve);
            else if (name == "nfCustomInteger0" && curve.components == 1) out.face = std::move(curve);
        }
        out.bones.push_back(std::move(bone));
    }
    return true;
}

// ===========================================================================
// マテリアル
// ===========================================================================
std::vector<std::string> Material::Textures() const {
    std::vector<std::string> out;
    for (const MaterialParam& p : params) {
        if ((p.type == 8 || p.type == 11) && !p.text.empty()) out.push_back(p.text);
    }
    return out;
}

const Material* Materials::Find(const std::string& label) const {
    for (const Material& m : entries) {
        if (m.label == label) return &m;
    }
    return nullptr;
}

bool LoadMaterials(const std::string& path, Materials& out, std::string* error) {
    out = Materials();
    std::vector<uint8_t> storage;
    Reader* raw = nullptr;
    if (!Open(path, "LTAM", raw, storage, error)) return false;
    std::unique_ptr<Reader> holder(raw);
    const Reader& r = *raw;

    const size_t base = 0x18;
    const auto entries = r.Array(base);
    for (size_t i = 0; i < entries.second; ++i) {
        const size_t e = entries.first + i * 32;
        Material material;
        material.label = r.String(e);
        material.shader = r.String(e + 24);
        const auto params = r.Array(e + 8);
        for (size_t p = 0; p < params.second; ++p) {
            const size_t pp = params.first + p * 24;
            MaterialParam param;
            param.id = r.Read<uint64_t>(pp);
            const size_t data = r.Ptr(pp + 8);
            param.type = r.Read<uint64_t>(pp + 16);
            if (data != 0) {
                if (param.type == 8 || param.type == 11) {
                    param.text = r.String(data);   // 文字列は、さらに相対オフセットで指す
                } else if (param.type == 1) {
                    param.vector[0] = r.Read<float>(data);
                } else if (param.type == 5) {
                    for (int k = 0; k < 4; ++k) param.vector[size_t(k)] = r.Read<float>(data + k * 4);
                } else if (param.type == 2) {
                    param.vector[0] = float(r.Read<uint32_t>(data));
                }
            }
            material.params.push_back(param);
        }
        out.entries.push_back(std::move(material));
    }
    return true;
}

} // namespace Ssbh
