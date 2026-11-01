#include "DonModel.hpp"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <map>

#include "AssetCache.hpp"
#include "rlgl.h"

namespace {

constexpr const char* kModelRoot = "Data/x64/model/";
constexpr const char* kAnimationRoot = "Data/x64/animation/";

constexpr const char* kVertexShader = R"(#version 330
in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
uniform mat4 mvp;
uniform mat4 matNormal;
out vec2 fragTexCoord;
out vec3 fragNormal;
void main() {
    fragTexCoord = vertexTexCoord;
    fragNormal = normalize(vec3(matNormal * vec4(vertexNormal, 0.0)));
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
)";

// mode 0: マスクの R/G/B に色を乗せる（taikoEffectChangeColors）
// mode 1: 画像をそのまま貼る（taikoEffectFace）
constexpr const char* kFragmentShader = R"(#version 330
in vec2 fragTexCoord;
in vec3 fragNormal;
uniform sampler2D texture0;
uniform int mode;
uniform vec3 colorR;
uniform vec3 colorG;
uniform vec3 colorB;
out vec4 finalColor;
void main() {
    vec4 texel = texture(texture0, fragTexCoord);
    if (mode == 1) {
        if (texel.a < 0.02) discard;
        finalColor = texel;
        return;
    }
    if (mode == 2) {
        // 着せかえの飾り（画像をそのまま。塗りは本体と同じく光の当たらない側を少し暗く）
        if (texel.a < 0.3) discard;
        vec3 n2 = normalize(fragNormal);
        float l2 = mix(0.86, 1.0, smoothstep(-0.05, 0.10, dot(n2, normalize(vec3(0.3, 0.7, 0.9)))));
        finalColor = vec4(texel.rgb * l2, 1.0);
        return;
    }
    // アニメ調のフラットな塗り（光の当たらない側だけ少し暗くする）
    vec3 n = normalize(fragNormal);
    float ndl = dot(n, normalize(vec3(0.3, 0.7, 0.9)));
    float light = mix(0.86, 1.0, smoothstep(-0.05, 0.10, ndl));
    vec3 color = texel.r * colorR + texel.g * colorG + texel.b * colorB;
    finalColor = vec4(color * light, 1.0);
}
)";

// 縁取り: 法線方向に膨らませたメッシュの裏面だけを黒く描く
constexpr const char* kOutlineVertexShader = R"(#version 330
in vec3 vertexPosition;
in vec3 vertexNormal;
uniform mat4 mvp;
uniform float outlineWidth;
void main() {
    // 法線が壊れている頂点（長さがほぼ 0）は膨らませない
    float len = length(vertexNormal);
    vec3 offset = len > 0.5 ? vertexNormal / len * outlineWidth : vec3(0.0);
    gl_Position = mvp * vec4(vertexPosition + offset, 1.0);
}
)";

constexpr const char* kOutlineFragmentShader = R"(#version 330
out vec4 finalColor;
void main() {
    finalColor = vec4(0.05, 0.03, 0.03, 1.0);
}
)";

constexpr float kOutlineWidth = 0.0042f;

// 顔の板（目と口）の大きさ。そのままだと赤い円いっぱいに広がるので、AC の筐体の見た目に合わせて中心から縮める
// （頭の飾り head_* の顔の板だけ。きぐるみ cos_* の顔はきぐるみに合わせた大きさなのでそのまま）
constexpr float kFaceScale = 0.8f;

// ---- 行列（SSBH と同じく「行ベクトル × 行列」、平行移動は 12〜14 番目） ----
using Mat4 = std::array<float, 16>;

Mat4 Identity() {
    return Mat4{1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};
}

Mat4 Mul(const Mat4& a, const Mat4& b) {
    Mat4 c{};
    for (int r = 0; r < 4; ++r) {
        for (int col = 0; col < 4; ++col) {
            float sum = 0.0f;
            for (int k = 0; k < 4; ++k) sum += a[size_t(r * 4 + k)] * b[size_t(k * 4 + col)];
            c[size_t(r * 4 + col)] = sum;
        }
    }
    return c;
}

Mat4 FromTRS(const std::array<float, 3>& t, std::array<float, 4> q, const std::array<float, 3>& s) {
    const float len = std::sqrt(q[0] * q[0] + q[1] * q[1] + q[2] * q[2] + q[3] * q[3]);
    if (len > 0.0f) {
        for (float& v : q) v /= len;
    }
    const float x = q[0], y = q[1], z = q[2], w = q[3];
    // 行ベクトル用の回転行列（列ベクトル用の転置）
    const float rot[9] = {
        1 - 2 * (y * y + z * z), 2 * (x * y + z * w),     2 * (x * z - y * w),
        2 * (x * y - z * w),     1 - 2 * (x * x + z * z), 2 * (y * z + x * w),
        2 * (x * z + y * w),     2 * (y * z - x * w),     1 - 2 * (x * x + y * y),
    };
    Mat4 m = Identity();
    for (int r = 0; r < 3; ++r) {
        for (int c = 0; c < 3; ++c) m[size_t(r * 4 + c)] = rot[r * 3 + c] * s[size_t(r)];
    }
    m[12] = t[0];
    m[13] = t[1];
    m[14] = t[2];
    return m;
}

Mat4 Invert(const Mat4& m) {
    Mat4 inv{};
    inv[0] = m[5] * m[10] * m[15] - m[5] * m[11] * m[14] - m[9] * m[6] * m[15] + m[9] * m[7] * m[14] + m[13] * m[6] * m[11] - m[13] * m[7] * m[10];
    inv[4] = -m[4] * m[10] * m[15] + m[4] * m[11] * m[14] + m[8] * m[6] * m[15] - m[8] * m[7] * m[14] - m[12] * m[6] * m[11] + m[12] * m[7] * m[10];
    inv[8] = m[4] * m[9] * m[15] - m[4] * m[11] * m[13] - m[8] * m[5] * m[15] + m[8] * m[7] * m[13] + m[12] * m[5] * m[11] - m[12] * m[7] * m[9];
    inv[12] = -m[4] * m[9] * m[14] + m[4] * m[10] * m[13] + m[8] * m[5] * m[14] - m[8] * m[6] * m[13] - m[12] * m[5] * m[10] + m[12] * m[6] * m[9];
    inv[1] = -m[1] * m[10] * m[15] + m[1] * m[11] * m[14] + m[9] * m[2] * m[15] - m[9] * m[3] * m[14] - m[13] * m[2] * m[11] + m[13] * m[3] * m[10];
    inv[5] = m[0] * m[10] * m[15] - m[0] * m[11] * m[14] - m[8] * m[2] * m[15] + m[8] * m[3] * m[14] + m[12] * m[2] * m[11] - m[12] * m[3] * m[10];
    inv[9] = -m[0] * m[9] * m[15] + m[0] * m[11] * m[13] + m[8] * m[1] * m[15] - m[8] * m[3] * m[13] - m[12] * m[1] * m[11] + m[12] * m[3] * m[9];
    inv[13] = m[0] * m[9] * m[14] - m[0] * m[10] * m[13] - m[8] * m[1] * m[14] + m[8] * m[2] * m[13] + m[12] * m[1] * m[10] - m[12] * m[2] * m[9];
    inv[2] = m[1] * m[6] * m[15] - m[1] * m[7] * m[14] - m[5] * m[2] * m[15] + m[5] * m[3] * m[14] + m[13] * m[2] * m[7] - m[13] * m[3] * m[6];
    inv[6] = -m[0] * m[6] * m[15] + m[0] * m[7] * m[14] + m[4] * m[2] * m[15] - m[4] * m[3] * m[14] - m[12] * m[2] * m[7] + m[12] * m[3] * m[6];
    inv[10] = m[0] * m[5] * m[15] - m[0] * m[7] * m[13] - m[4] * m[1] * m[15] + m[4] * m[3] * m[13] + m[12] * m[1] * m[7] - m[12] * m[3] * m[5];
    inv[14] = -m[0] * m[5] * m[14] + m[0] * m[6] * m[13] + m[4] * m[1] * m[14] - m[4] * m[2] * m[13] - m[12] * m[1] * m[6] + m[12] * m[2] * m[5];
    inv[3] = -m[1] * m[6] * m[11] + m[1] * m[7] * m[10] + m[5] * m[2] * m[11] - m[5] * m[3] * m[10] - m[9] * m[2] * m[7] + m[9] * m[3] * m[6];
    inv[7] = m[0] * m[6] * m[11] - m[0] * m[7] * m[10] - m[4] * m[2] * m[11] + m[4] * m[3] * m[10] + m[8] * m[2] * m[7] - m[8] * m[3] * m[6];
    inv[11] = -m[0] * m[5] * m[11] + m[0] * m[7] * m[9] + m[4] * m[1] * m[11] - m[4] * m[3] * m[9] - m[8] * m[1] * m[7] + m[8] * m[3] * m[5];
    inv[15] = m[0] * m[5] * m[10] - m[0] * m[6] * m[9] - m[4] * m[1] * m[10] + m[4] * m[2] * m[9] + m[8] * m[1] * m[6] - m[8] * m[2] * m[5];
    float det = m[0] * inv[0] + m[1] * inv[4] + m[2] * inv[8] + m[3] * inv[12];
    if (std::fabs(det) < 1e-12f) return Identity();
    det = 1.0f / det;
    for (float& v : inv) v *= det;
    return inv;
}

const Ssbh::Animation* LoadAnimationCached(const std::string& name) {
    static std::map<std::string, Ssbh::Animation> cache;
    auto found = cache.find(name);
    if (found != cache.end()) return found->second.bones.empty() ? nullptr : &found->second;
    Ssbh::Animation& animation = cache[name];
    std::string error;
    if (!Ssbh::LoadAnimation(std::string(kAnimationRoot) + name + ".nuanmb", animation, &error)) {
        TraceLog(LOG_WARNING, "DonModel: %s", error.c_str());
        animation.bones.clear();
        return nullptr;
    }
    return &animation;
}

Vector3 Rgb(float r, float g, float b) { return Vector3{r, g, b}; }

} // namespace

// 初期スキンの色（datatable/don_color.bin の先頭の色）
//   どんちゃん: 顔 赤 / 胴 水色 / ふち クリーム　かっちゃん: 顔 水色 / 胴 赤
DonModel::Colors DonModel::DefaultColors(int side) {
    const Vector3 red = Rgb(0.972549f, 0.282353f, 0.156863f);
    const Vector3 cyan = Rgb(0.407843f, 0.752941f, 0.752941f);
    const Vector3 white = Rgb(0.98f, 0.97f, 0.94f);   // ふち（参考画像に合わせて白寄り）
    return side == 0 ? Colors{cyan, red, white} : Colors{red, cyan, white};
}

// ---- 着せかえ ----
namespace {

std::string Id6(int dataId) { return TextFormat("%06d", dataId); }

// datatable/don_color.bin（体の色の表）
const std::vector<Vector3>& ColorTable() {
    static std::vector<Vector3> table;
    static bool loaded = false;
    if (loaded) return table;
    loaded = true;
    int size = 0;
    unsigned char* packed = LoadFileData("Data/x64/datatable/don_color.bin", &size);
    if (!packed) return table;
    int textSize = 0;
    // gzip（10 バイトのヘッダーの後ろが deflate）
    unsigned char* text = size > 18 ? DecompressData(packed + 10, size - 18, &textSize) : nullptr;
    UnloadFileData(packed);
    if (!text) return table;
    const std::string json(reinterpret_cast<char*>(text), size_t(textSize));
    MemFree(text);
    size_t pos = 0;
    while ((pos = json.find("\"red\"", pos)) != std::string::npos) {
        auto number = [&](const char* key) {
            const size_t k = json.find(key, pos);
            return k == std::string::npos ? 0.0f : float(std::atof(json.c_str() + json.find(':', k) + 1));
        };
        table.push_back(Vector3{number("\"red\""), number("\"green\""), number("\"blue\"")});
        pos += 5;
    }
    return table;
}

// 着せかえの組の初期値（Data/x64/don_presets.ini があればその値）
//   本家では組の中身が C++ 側で決まっていてデータにないので、この移植で決めたもの
DonModel::Costume g_presets[DonModel::kPresetCount] = {
    {},                                   // いつもの
    {23000, 0, 0, 0, -1, -1, -1},         // クール（武者のかぶと）
    {24000, 0, 0, 0, -1, -1, -1},         // キュート（ねこ）
    {4000, 0, 0, 0, -1, -1, -1},          // ジョーク（ヘリコプター）
};

void LoadPresets() {
    static bool loaded = false;
    if (loaded) return;
    loaded = true;
    char* text = LoadFileText("Data/x64/don_presets.ini");
    if (!text) return;
    // 1 行 1 組: 番号=kigurumi,body,head,face,faceColor,bodyColor,legsColor
    std::string all(text);
    UnloadFileText(text);
    size_t start = 0;
    while (start < all.size()) {
        size_t end = all.find('\n', start);
        if (end == std::string::npos) end = all.size();
        const std::string line = all.substr(start, end - start);
        start = end + 1;
        const size_t eq = line.find('=');
        if (line.empty() || line[0] == '#' || eq == std::string::npos) continue;
        const int index = std::atoi(line.c_str());
        if (index < 0 || index >= DonModel::kPresetCount) continue;
        int v[7] = {-1, 0, 0, 0, -1, -1, -1};
        std::sscanf(line.c_str() + eq + 1, "%d,%d,%d,%d,%d,%d,%d", &v[0], &v[1], &v[2], &v[3], &v[4], &v[5], &v[6]);
        g_presets[index] = DonModel::Costume{v[0], v[1], v[2], v[3], v[4], v[5], v[6]};
    }
}

} // namespace

DonModel::Costume DonModel::Preset(int index) {
    LoadPresets();
    return g_presets[std::clamp(index, 0, kPresetCount - 1)];
}

int DonModel::RandomKigurumi() {
    static std::vector<int> ids;
    if (ids.empty()) {
        FilePathList list = LoadDirectoryFiles((std::string(kModelRoot) + "cos").c_str());
        for (unsigned int i = 0; i < list.count; ++i) {
            const char* name = GetFileName(list.paths[i]);
            if (std::strncmp(name, "cos_", 4) == 0) ids.push_back(std::atoi(name + 4));
        }
        UnloadDirectoryFiles(list);
        if (ids.empty()) ids.push_back(-1);
    }
    return ids[size_t(GetRandomValue(0, int(ids.size()) - 1))];
}

DonModel::Costume DonModel::FromEntry(int costume, int kigurumi, const Costume& custom) {
    if (costume == kCostumeCustom) return custom;
    if (costume >= kPresetCount) {
        Costume c;
        c.kigurumi = kigurumi;
        return c;
    }
    return Preset(costume);
}

bool DonModel::Load() {
    if (loaded_) return true;

    shader_ = LoadShaderFromMemory(kVertexShader, kFragmentShader);
    if (shader_.id == 0) return false;
    modeLoc_ = GetShaderLocation(shader_, "mode");
    colorLoc_[0] = GetShaderLocation(shader_, "colorR");
    colorLoc_[1] = GetShaderLocation(shader_, "colorG");
    colorLoc_[2] = GetShaderLocation(shader_, "colorB");
    outlineShader_ = LoadShaderFromMemory(kOutlineVertexShader, kOutlineFragmentShader);
    outlineWidthLoc_ = GetShaderLocation(outlineShader_, "outlineWidth");

    loaded_ = BuildSet(0);
    BuildSet(1);
    if (!loaded_) {
        TraceLog(LOG_WARNING, "DonModel: どんちゃんのモデルを読み込めません");
        return false;
    }
    // エントリー画面の待機ポーズ（lua: Don.SetLoopAnimation(…, "select_loop")）
    SetPose("don_select_loop");
    return true;
}

// side の見た目を組み立て直す（前のメッシュは捨てる）
bool DonModel::BuildSet(int side) {
    Set& set = sets_[size_t(side)];
    for (Part& part : set.parts) UnloadMesh(part.mesh);
    set.parts.clear();
    const Costume& c = set.costume;
    bool ok = false;
    if (c.kigurumi >= 0) {
        const std::string id = Id6(c.kigurumi);
        ok = LoadPart(set, "cos/cos_" + id + "/cos_" + id + "/cos_" + id);
    }
    if (!ok) {
        const std::string body = Id6(std::max(0, c.body)), head = Id6(std::max(0, c.head));
        const bool b = LoadPart(set, "body/body_" + body + "/body_" + body + "/body_" + body) ||
                       LoadPart(set, "body/body_000000/body_000000/body_000000");
        const bool h = LoadPart(set, "head/head_" + head + "/head_" + head + "/head_" + head) ||
                       LoadPart(set, "head/head_000000/head_000000/head_000000");
        ok = b && h;
    }
    std::string facePath = std::string(kModelRoot) + "face/face_" + Id6(std::max(0, c.face)) + ".nutexb";
    if (!FileExists(facePath.c_str())) facePath = std::string(kModelRoot) + "face/face_000000.nutexb";
    const std::vector<Texture2D>& faces = AssetCache::Get().Nutexb(facePath);
    set.faces = faces.empty() ? nullptr : &faces;
    set.built = ok;
    return ok;
}

void DonModel::SetCostume(int side, const Costume& costume) {
    if (side < 0 || side > 1) return;
    Set& set = sets_[size_t(side)];
    if (set.built && set.costume == costume) return;
    set.costume = costume;
    if (!loaded_) return;   // Load のときに組み立てる
    BuildSet(side);
    ReapplyPose();
}

// 組み立て直したメッシュに今の姿勢を当て直す
void DonModel::ReapplyPose() {
    const std::string name = poseName_;
    const float frame = poseFrame_;
    poseName_.clear();
    if (!name.empty()) SetPose(name, frame);
}

bool DonModel::LoadPart(Set& set, const std::string& name) {
    const std::string modelPath = std::string(kModelRoot) + name + ".numdlb";
    if (!FileExists(modelPath.c_str())) return false;
    const std::string dir = modelPath.substr(0, modelPath.find_last_of('/') + 1);

    Ssbh::Model model;
    Ssbh::Mesh mesh;
    std::string error;
    if (!Ssbh::LoadModel(modelPath, model, &error) || !Ssbh::LoadMesh(dir + model.meshFile, mesh, &error)) {
        TraceLog(LOG_WARNING, "DonModel: %s", error.c_str());
        return false;
    }

    // スケルトンと、初期姿勢の逆行列
    Ssbh::Skeleton skeleton;
    int skeletonIndex = -1;
    if (Ssbh::LoadSkeleton(dir + model.skeletonFile, skeleton, &error)) {
        std::vector<Mat4> inverse;
        for (const Ssbh::Bone& bone : skeleton.bones) inverse.push_back(Invert(bone.world));
        skeletons_.push_back(std::move(skeleton));
        inverseBind_.push_back(std::move(inverse));
        skeletonIndex = int(skeletons_.size()) - 1;
    }

    // テクスチャのパスはマテリアルファイルの場所からの相対パス
    std::vector<std::pair<Ssbh::Materials, std::string>> materials;
    for (const std::string& file : model.materialFiles) {
        Ssbh::Materials m;
        const std::string path = dir + file;
        if (Ssbh::LoadMaterials(path, m)) materials.emplace_back(std::move(m), path.substr(0, path.find_last_of('/') + 1));
    }

    bool any = false;
    for (const Ssbh::ModelEntry& entry : model.entries) {
        const Ssbh::MeshObject* object = nullptr;
        for (const Ssbh::MeshObject& o : mesh.objects) {
            if (o.name == entry.meshObjectName && o.subIndex == entry.subIndex) object = &o;
        }
        if (!object || object->positions.empty()) continue;

        // マテリアルからテクスチャと描き方を決める
        Part part;
        part.skeleton = skeletonIndex;
        std::string texture;
        for (const auto& m : materials) {
            if (const Ssbh::Material* material = m.first.Find(entry.materialLabel)) {
                if (texture.empty() && !material->Textures().empty()) texture = m.second + material->Textures().front();
                if (material->shader == "taikoEffectFace") part.face = true;
                if (material->shader == "taikoEffect") part.plain = true;
            }
        }
        if (!texture.empty()) {
            const std::vector<Texture2D>& textures = AssetCache::Get().Nutexb(texture + ".nutexb");
            if (!textures.empty()) part.texture = textures.front();
        }

        // raylib のメッシュにする（姿勢を変えるので頂点は書き換えられるようにする）
        // 面積がない三角形は捨てる（見えないが、縁取りを付けると黒い点になる）
        std::vector<uint32_t> indices;
        for (size_t t = 0; t + 2 < object->indices.size(); t += 3) {
            const auto& a = object->positions[object->indices[t]];
            const auto& b = object->positions[object->indices[t + 1]];
            const auto& c = object->positions[object->indices[t + 2]];
            const float ux = b[0] - a[0], uy = b[1] - a[1], uz = b[2] - a[2];
            const float vx = c[0] - a[0], vy = c[1] - a[1], vz = c[2] - a[2];
            const float cx = uy * vz - uz * vy, cy = uz * vx - ux * vz, cz = ux * vy - uy * vx;
            if (cx * cx + cy * cy + cz * cz < 1e-14f) continue;
            indices.insert(indices.end(), {object->indices[t], object->indices[t + 1], object->indices[t + 2]});
        }

        const int vertexCount = int(object->positions.size());
        Mesh& m = part.mesh;
        m.vertexCount = vertexCount;
        m.triangleCount = int(indices.size() / 3);
        m.vertices = static_cast<float*>(MemAlloc(unsigned(vertexCount * 3 * sizeof(float))));
        m.normals = static_cast<float*>(MemAlloc(unsigned(vertexCount * 3 * sizeof(float))));
        m.texcoords = static_cast<float*>(MemAlloc(unsigned(vertexCount * 2 * sizeof(float))));
        m.indices = static_cast<unsigned short*>(MemAlloc(unsigned(indices.size() * sizeof(unsigned short))));
        for (int v = 0; v < vertexCount; ++v) {
            std::memcpy(&m.vertices[v * 3], object->positions[size_t(v)].data(), 3 * sizeof(float));
            if (size_t(v) < object->normals.size()) std::memcpy(&m.normals[v * 3], object->normals[size_t(v)].data(), 3 * sizeof(float));
            if (!object->uvs.empty() && size_t(v) < object->uvs[0].size()) {
                m.texcoords[v * 2] = object->uvs[0][size_t(v)][0];
                m.texcoords[v * 2 + 1] = object->uvs[0][size_t(v)][1];
            }
        }
        for (size_t i = 0; i < indices.size(); ++i) m.indices[i] = (unsigned short)indices[i];
        if (part.face && name.rfind("head/", 0) == 0) {
            // 顔の板は正面（XY 平面）に置かれているので、XY の範囲の中心から縮める
            float mn[2] = {1e9f, 1e9f}, mx[2] = {-1e9f, -1e9f};
            for (int v = 0; v < vertexCount; ++v) {
                for (int c = 0; c < 2; ++c) {
                    mn[c] = std::min(mn[c], m.vertices[v * 3 + c]);
                    mx[c] = std::max(mx[c], m.vertices[v * 3 + c]);
                }
            }
            for (int v = 0; v < vertexCount; ++v) {
                for (int c = 0; c < 2; ++c) {
                    const float center = (mn[c] + mx[c]) * 0.5f;
                    m.vertices[v * 3 + c] = center + (m.vertices[v * 3 + c] - center) * kFaceScale;
                }
            }
        }
        part.bindPositions.assign(m.vertices, m.vertices + vertexCount * 3);
        part.bindNormals.assign(m.normals, m.normals + vertexCount * 3);

        // ボーンの重み（1頂点あたり重い順に4つまで）
        part.joints.assign(size_t(vertexCount), {-1, -1, -1, -1});
        part.weights.assign(size_t(vertexCount), {0.0f, 0.0f, 0.0f, 0.0f});
        if (skeletonIndex >= 0) {
            const Ssbh::Skeleton& skel = skeletons_[size_t(skeletonIndex)];
            for (const Ssbh::BoneInfluence& influence : object->influences) {
                const int bone = skel.Find(influence.boneName);
                if (bone < 0) continue;
                for (const Ssbh::VertexWeight& w : influence.weights) {
                    if (w.vertex >= vertexCount || w.weight <= 0.0f) continue;
                    auto& joints = part.joints[w.vertex];
                    auto& weights = part.weights[w.vertex];
                    int slot = 0;
                    for (int k = 1; k < 4; ++k) {
                        if (weights[size_t(k)] < weights[size_t(slot)]) slot = k;
                    }
                    if (w.weight > weights[size_t(slot)]) {
                        joints[size_t(slot)] = bone;
                        weights[size_t(slot)] = w.weight;
                    }
                }
            }
        }

        UploadMesh(&m, true);
        set.parts.push_back(std::move(part));
        any = true;
    }
    return any;
}

bool DonModel::SetPose(const std::string& animation, float frame) {
    if (!loaded_ && sets_[0].parts.empty()) return false;
    if (animation == poseName_ && std::fabs(frame - poseFrame_) < 0.0001f) return true;

    const Ssbh::Animation* anim = LoadAnimationCached(animation);
    if (!anim) return false;

    std::vector<std::pair<std::string, Ssbh::BonePose>> pose;
    pose.reserve(anim->bones.size());
    for (const Ssbh::BoneAnimation& bone : anim->bones) {
        Ssbh::BonePose p;
        using Type = Ssbh::AnimationCurve::Type;
        p.hasTranslate = bone.translate.type != Type::None;
        p.hasRotate = bone.rotate.type != Type::None;
        p.hasScale = bone.scale.type != Type::None;
        const auto t = bone.translate.Sample(frame);
        const auto r = bone.rotate.Sample(frame);
        const auto s = bone.scale.Sample(frame);
        for (size_t i = 0; i < 3; ++i) {
            p.translate[i] = t[i];
            p.scale[i] = s[i];
        }
        p.rotate = r;
        p.compensateScale = bone.compensateScale;
        pose.emplace_back(bone.name, p);
    }
    ApplyPose(pose);
    if (anim->face.type != Ssbh::AnimationCurve::Type::None) expression_ = int(std::lround(anim->face.Sample(frame)[0]));
    poseName_ = animation;
    poseFrame_ = frame;
    return true;
}

bool DonModel::PlayLoop(const std::string& animation, float seconds) {
    const Ssbh::Animation* anim = LoadAnimationCached(animation);
    if (!anim || anim->frameCount <= 0.0f) return SetPose(animation, 0.0f);
    return SetPose(animation, std::fmod(seconds * anim->frameRate, anim->frameCount));
}

// ===========================================================================
// DonAnimator
// ===========================================================================
// lua のアニメーション名 → ファイル名。"_p1" / "_p2" で終わるものは 1P/2P 用のファイルに読み替える
//   kusu_in_p1 → don_kusu1P_in、result_failure_p2 → don_result2P_failure、result_failure_loop_p1 → don_result_failure_loop
std::string DonAnimator::FileName(const std::string& luaName) {
    std::string name = luaName;
    if (name.rfind("don_", 0) == 0) name = name.substr(4);
    std::string side;
    if (name.size() > 3 && (name.compare(name.size() - 3, 3, "_p1") == 0 || name.compare(name.size() - 3, 3, "_p2") == 0)) {
        side = name.substr(name.size() - 1) + "P";
        name = name.substr(0, name.size() - 3);
    }
    if (!side.empty()) {
        // 最初の単語の後ろに 1P/2P を入れる（1P は付けない名前のファイルもある）
        const size_t us = name.find('_');
        const std::string head = us == std::string::npos ? name : name.substr(0, us);
        const std::string tail = us == std::string::npos ? "" : name.substr(us);
        const std::string withSide = "don_" + head + side + tail;
        if (FileExists(("Data/x64/animation/" + withSide + ".nuanmb").c_str())) return withSide;
    }
    return "don_" + name;
}

void DonAnimator::Preload(const std::string& luaName) { LoadAnimationCached(FileName(luaName)); }

void DonAnimator::SetLoopAnimation(const std::string& name, bool restart) {
    const std::string file = FileName(name);
    if (file == loop_ && !restart) return;
    loop_ = file;
    if (once_.empty()) time_ = 0.0f;
}

void DonAnimator::SetNonLoopAnimation(const std::string& name, bool restart) {
    const std::string file = FileName(name);
    if (file == once_ && !restart) return;
    once_ = file;
    time_ = 0.0f;
}

bool DonAnimator::IsPlayingNonLoop() const {
    if (once_.empty()) return false;
    const Ssbh::Animation* anim = LoadAnimationCached(once_);
    return anim && time_ * anim->frameRate < anim->frameCount;
}

void DonAnimator::Apply(DonModel& model) {
    if (!once_.empty()) {
        const Ssbh::Animation* anim = LoadAnimationCached(once_);
        const float frame = anim ? time_ * anim->frameRate : 0.0f;
        if (anim && frame < anim->frameCount) {
            model.SetPose(once_, frame);
            return;
        }
        // 流し終わったらループに戻る（ループは頭から）
        once_.clear();
        time_ = 0.0f;
    }
    model.PlayLoop(loop_, time_);
}

// 姿勢からボーンの行列を求め、頂点を動かす
void DonModel::ApplyPose(const std::vector<std::pair<std::string, Ssbh::BonePose>>& pose) {
    std::vector<std::vector<Mat4>> skins(skeletons_.size());
    for (size_t s = 0; s < skeletons_.size(); ++s) {
        const Ssbh::Skeleton& skel = skeletons_[s];
        const size_t count = skel.bones.size();

        std::vector<Mat4> local(count);
        std::vector<std::array<float, 3>> scale(count, {1.0f, 1.0f, 1.0f});
        std::vector<bool> compensate(count, false);
        for (size_t i = 0; i < count; ++i) {
            local[i] = skel.bones[i].transform;
            for (const auto& entry : pose) {
                if (entry.first != skel.bones[i].name) continue;
                const Ssbh::BonePose& p = entry.second;
                if (p.hasTranslate && p.hasRotate && p.hasScale) {
                    local[i] = FromTRS(p.translate, p.rotate, p.scale);
                    scale[i] = p.scale;
                    compensate[i] = p.compensateScale;
                }
                break;
            }
        }
        // 親の拡大を受け継がない骨は、回転・拡大の後に親の拡大の逆数を掛ける（位置はそのまま）
        //   world = S·R · 親の拡大⁻¹ · T · 親の world
        for (size_t i = 0; i < count; ++i) {
            const int parent = skel.bones[i].parent;
            if (!compensate[i] || parent < 0 || size_t(parent) >= count) continue;
            for (int r = 0; r < 3; ++r) {
                for (int c = 0; c < 3; ++c) {
                    const float s = scale[size_t(parent)][size_t(c)];
                    if (std::fabs(s) > 1e-6f) local[i][size_t(r * 4 + c)] /= s;
                }
            }
        }

        // 親から順に world を求める（world = local × 親の world）
        std::vector<Mat4> world(count);
        std::vector<bool> done(count, false);
        for (size_t i = 0; i < count; ++i) {
            std::vector<size_t> chain;
            size_t b = i;
            while (!done[b]) {
                chain.push_back(b);
                const int parent = skel.bones[b].parent;
                if (parent < 0 || size_t(parent) >= count) break;
                b = size_t(parent);
            }
            for (auto it = chain.rbegin(); it != chain.rend(); ++it) {
                const int parent = skel.bones[*it].parent;
                world[*it] = parent >= 0 && size_t(parent) < count && done[size_t(parent)] ? Mul(local[*it], world[size_t(parent)])
                                                                                          : local[*it];
                done[*it] = true;
            }
        }

        skins[s].resize(count);
        for (size_t i = 0; i < count; ++i) skins[s][i] = Mul(inverseBind_[s][i], world[i]);
    }

    for (Set& set : sets_)
    for (Part& part : set.parts) {
        if (part.skeleton < 0) continue;
        const std::vector<Mat4>& skin = skins[size_t(part.skeleton)];
        const int count = part.mesh.vertexCount;
        for (int v = 0; v < count; ++v) {
            const float* p = &part.bindPositions[size_t(v) * 3];
            const float* n = &part.bindNormals[size_t(v) * 3];
            float op[3] = {0, 0, 0}, on[3] = {0, 0, 0}, total = 0.0f, volume = 0.0f;
            for (int k = 0; k < 4; ++k) {
                const int j = part.joints[size_t(v)][size_t(k)];
                const float w = part.weights[size_t(v)][size_t(k)];
                if (j < 0 || w <= 0.0f || size_t(j) >= skin.size()) continue;
                const Mat4& m = skin[size_t(j)];
                // 拡大率（行列式）。0 に縮められた部分は非表示の扱い
                volume += w * std::fabs(m[0] * (m[5] * m[10] - m[6] * m[9]) - m[1] * (m[4] * m[10] - m[6] * m[8]) +
                                        m[2] * (m[4] * m[9] - m[5] * m[8]));
                for (int c = 0; c < 3; ++c) {
                    op[c] += w * (p[0] * m[size_t(c)] + p[1] * m[size_t(4 + c)] + p[2] * m[size_t(8 + c)] + m[size_t(12 + c)]);
                    on[c] += w * (n[0] * m[size_t(c)] + n[1] * m[size_t(4 + c)] + n[2] * m[size_t(8 + c)]);
                }
                total += w;
            }
            if (total <= 0.0f) {
                std::memcpy(&part.mesh.vertices[v * 3], p, 3 * sizeof(float));
                std::memcpy(&part.mesh.normals[v * 3], n, 3 * sizeof(float));
                continue;
            }
            const float len = std::sqrt(on[0] * on[0] + on[1] * on[1] + on[2] * on[2]);
            const bool collapsed = volume / total < 1e-4f;   // 縮めて隠した部分は縁取りしない（法線を 0 にする）
            for (int c = 0; c < 3; ++c) {
                part.mesh.vertices[v * 3 + c] = op[c] / total;
                part.mesh.normals[v * 3 + c] = collapsed ? 0.0f : len > 0.0f ? on[c] / len : n[c];
            }
        }
        UpdateMeshBuffer(part.mesh, 0, part.mesh.vertices, count * 3 * int(sizeof(float)), 0);
        UpdateMeshBuffer(part.mesh, 2, part.mesh.normals, count * 3 * int(sizeof(float)), 0);
    }
}

void DonModel::Unload() {
    for (Set& set : sets_) {
        for (Part& part : set.parts) UnloadMesh(part.mesh);
        set.parts.clear();
        set.built = false;
    }
    skeletons_.clear();
    inverseBind_.clear();
    if (shader_.id != 0) UnloadShader(shader_);
    if (outlineShader_.id != 0) UnloadShader(outlineShader_);
    shader_ = Shader{};
    outlineShader_ = Shader{};
    loaded_ = false;
    poseName_.clear();
    poseFrame_ = -1.0f;
}

void DonModel::Draw(int side, int expression, Matrix transform) const {
    if (!loaded_) return;
    const Set& set = sets_[size_t(std::clamp(side, 0, 1))].built ? sets_[size_t(std::clamp(side, 0, 1))] : sets_[0];
    const std::vector<Part>& parts = set.parts;
    const std::vector<Texture2D>* faces = set.faces;
    // 体の色: 着せかえで決まっていればその色（don_color の番号）、なければ どんちゃん／かっちゃんの初期の色
    //   マスクの R が胴、G が顔の円、B がふち・手足
    Colors colors = DefaultColors(side);
    const std::vector<Vector3>& table = ColorTable();
    auto pick = [&](int index, Vector3& out) {
        if (index >= 0 && size_t(index) < table.size()) out = table[size_t(index)];
    };
    pick(set.costume.bodyColor, colors.r);
    pick(set.costume.faceColor, colors.g);
    pick(set.costume.legsColor, colors.b);
    const Vector3 values[3] = {colors.r, colors.g, colors.b};
    for (int i = 0; i < 3; ++i) SetShaderValue(shader_, colorLoc_[i], &values[i], SHADER_UNIFORM_VEC3);

    Material material = LoadMaterialDefault();

    // 縁取り（胴・手足だけ。膨らませたメッシュの表側を捨て、裏側を黒く描く）
    if (outline_ && outlineShader_.id != 0) {
        material.shader = outlineShader_;
        const float width = kOutlineWidth;
        SetShaderValue(outlineShader_, outlineWidthLoc_, &width, SHADER_UNIFORM_FLOAT);
        rlEnableBackfaceCulling();
        rlSetCullFace(outlineCullFront_ ? RL_CULL_FACE_FRONT : RL_CULL_FACE_BACK);
        for (const Part& part : parts) {
            if (!part.face) DrawMesh(part.mesh, material, transform);
        }
        rlSetCullFace(RL_CULL_FACE_BACK);
    }

    material.shader = shader_;
    rlDisableBackfaceCulling();
    // 胴を先に、顔の板を後に（顔は透明な部分を捨てて描く）
    for (int pass = 0; pass < 2; ++pass) {
        for (const Part& part : parts) {
            if (part.face != (pass == 1)) continue;
            const int mode = part.face ? 1 : part.plain ? 2 : 0;
            SetShaderValue(shader_, modeLoc_, &mode, SHADER_UNIFORM_INT);
            Texture2D texture = part.texture;
            if (part.face && faces && !faces->empty()) {
                texture = (*faces)[size_t(expression) < faces->size() ? size_t(expression) : 0];
            }
            material.maps[MATERIAL_MAP_DIFFUSE].texture = texture;
            DrawMesh(part.mesh, material, transform);
        }
    }
    rlEnableBackfaceCulling();

    // LoadMaterialDefault が確保した配列だけ解放する（シェーダーとテクスチャは借り物）
    MemFree(material.maps);
}
