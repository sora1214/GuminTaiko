#pragma once
#include <array>
#include <cstdint>
#include <string>
#include <vector>

// SSBH 形式（.numshb / .nusktb / .numdlb / .numatb / .nuanmb）の読み込み
// ファイルは "HBSS" で始まり、0x10 から本体（"HSEM" = MESH など）が続く。
// 配列・文字列は「その位置からの相対オフセット（u64）」で参照する。
namespace Ssbh {

// ---- メッシュ（.numshb） ----
enum class AttributeUsage : uint32_t {
    Position = 0, Normal = 1, Binormal = 2, Tangent = 3, TextureCoordinate = 4, ColorSet = 5,
};

struct Attribute {
    uint32_t usage = 0;
    uint32_t dataType = 0;
    uint32_t bufferIndex = 0;
    uint32_t bufferOffset = 0;
    std::string name;
};

struct VertexWeight {
    uint16_t vertex = 0;
    float weight = 0.0f;
};

struct BoneInfluence {
    std::string boneName;
    std::vector<VertexWeight> weights;
};

struct MeshObject {
    std::string name;
    uint64_t subIndex = 0;
    std::string parentBoneName;
    uint32_t vertexCount = 0;
    uint32_t indexCount = 0;
    uint32_t vertexBufferOffset[4] = {};
    uint32_t stride[4] = {};
    uint32_t indexBufferOffset = 0;
    uint32_t drawElementType = 0;   // 0: u16 / 1: u32
    bool useSkinning = false;
    std::vector<Attribute> attributes;

    // 展開済みの頂点データ
    std::vector<std::array<float, 3>> positions;
    std::vector<std::array<float, 3>> normals;
    std::vector<std::vector<std::array<float, 2>>> uvs;       // 属性名の順
    std::vector<std::string> uvNames;
    std::vector<std::array<float, 4>> colors;                 // colorSet1（なければ空）
    std::vector<uint32_t> indices;
    std::vector<BoneInfluence> influences;
};

struct Mesh {
    uint16_t major = 0, minor = 0;
    std::vector<MeshObject> objects;
};

// ---- スケルトン（.nusktb） ----
struct Bone {
    std::string name;
    int index = 0;
    int parent = -1;
    std::array<float, 16> world{};      // 行ベクトル × 行列（平行移動は 12〜14 番目）
    std::array<float, 16> transform{};  // 親からの相対
};

struct Skeleton {
    std::vector<Bone> bones;
    int Find(const std::string& name) const;
};

// ---- モデル定義（.numdlb） ----
struct ModelEntry {
    std::string meshObjectName;
    uint64_t subIndex = 0;
    std::string materialLabel;
};

struct Model {
    std::string skeletonFile;
    std::vector<std::string> materialFiles;
    std::string animationFile;
    std::string meshFile;
    std::vector<ModelEntry> entries;
};

// ---- マテリアル（.numatb） ----
struct MaterialParam {
    uint64_t id = 0;
    uint64_t type = 0;
    std::string text;                    // テクスチャ名など
    std::array<float, 4> vector{};       // Vector4 / Float
};

struct Material {
    std::string label;
    std::string shader;
    std::vector<MaterialParam> params;
    std::vector<std::string> Textures() const;
};

struct Materials {
    std::vector<Material> entries;
    const Material* Find(const std::string& label) const;
};

// ---- アニメーション（.nuanmb v1.2） ----
// プロパティ（Translate / Rotate / Scale / nfCustomInteger0）ごとのデータの種類:
//   3: 一定の値 / 0: 圧縮なしのキー / 8・9: 圧縮（DCT-IV の係数。読み込むときにすべてのキーの値に戻す。Ssbh.cpp を参照）
struct BonePose {
    std::array<float, 3> translate{0.0f, 0.0f, 0.0f};
    std::array<float, 4> rotate{0.0f, 0.0f, 0.0f, 1.0f};   // クォータニオン (x, y, z, w)
    std::array<float, 3> scale{1.0f, 1.0f, 1.0f};
    bool hasTranslate = false, hasRotate = false, hasScale = false;
    bool compensateScale = false;   // 親の拡大を受け継がない（Maya の Segment Scale Compensate）
};

struct AnimationCurve {
    enum class Type { None, Constant, Keys };
    Type type = Type::None;
    int components = 0;
    std::vector<float> frames;                  // キーのフレーム
    std::vector<std::array<float, 4>> values;   // キーの値（圧縮されていたものも戻してある）

    // frame の時点の値（クォータニオンは正規化して返す）
    std::array<float, 4> Sample(float frame) const;
};

struct BoneAnimation {
    std::string name;
    AnimationCurve translate, rotate, scale;
    bool compensateScale = false;
};

struct Animation {
    float frameCount = 0.0f;   // 最後のフレームの番号
    float frameRate = 60.0f;
    std::vector<BoneAnimation> bones;
    AnimationCurve face;       // FaceAnim の nfCustomInteger0（表情の番号）
};

bool LoadAnimation(const std::string& path, Animation& out, std::string* error = nullptr);

bool LoadMesh(const std::string& path, Mesh& out, std::string* error = nullptr);
bool LoadSkeleton(const std::string& path, Skeleton& out, std::string* error = nullptr);
bool LoadModel(const std::string& path, Model& out, std::string* error = nullptr);
bool LoadMaterials(const std::string& path, Materials& out, std::string* error = nullptr);

} // namespace Ssbh
