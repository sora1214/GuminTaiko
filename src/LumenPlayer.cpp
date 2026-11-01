#include "LumenPlayer.hpp"

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <deque>

#include "AssetCache.hpp"
#include "GameFont.hpp"
#include "WordList.hpp"
#include "rlgl.h"

namespace Lumen {

namespace {

constexpr const char* kDataRoot = "Data/x64/";
constexpr int kBlendAdd = 8;
constexpr uint16_t kTransformNone = 0xFFFF;
constexpr uint16_t kTransformPosition = 0x8000;

Matrix Multiply(const Matrix& p, const Matrix& c) {
    Matrix m;
    m.a = p.a * c.a + p.c * c.b;
    m.b = p.b * c.a + p.d * c.b;
    m.c = p.a * c.c + p.c * c.d;
    m.d = p.b * c.c + p.d * c.d;
    m.x = p.a * c.x + p.c * c.y + p.x;
    m.y = p.b * c.x + p.d * c.y + p.y;
    return m;
}

ColorF Multiply(const ColorF& a, const ColorF& b) {
    return ColorF{a.r * b.r, a.g * b.g, a.b * b.b, a.a * b.a};
}

unsigned char ToByte(float v) {
    if (v <= 0.0f) return 0;
    if (v >= 1.0f) return 255;
    return (unsigned char)(v * 255.0f + 0.5f);
}

// HTML 形式のテキストから文字と色を取り出す（<p> ごとに改行）
std::vector<std::string> ParseHtmlText(const std::string& html, Color* color) {
    std::vector<std::string> lines;
    std::string current;
    bool hasParagraph = false;

    size_t i = 0;
    while (i < html.size()) {
        if (html[i] == '<') {
            const size_t end = html.find('>', i);
            if (end == std::string::npos) break;
            const std::string tag = html.substr(i + 1, end - i - 1);
            if (tag == "/p") {
                lines.push_back(current);
                current.clear();
                hasParagraph = true;
            }
            const size_t colorPos = tag.find("color=\"#");
            if (color && colorPos != std::string::npos && colorPos + 14 <= tag.size()) {
                const unsigned long rgb = std::strtoul(tag.substr(colorPos + 8, 6).c_str(), nullptr, 16);
                *color = Color{(unsigned char)(rgb >> 16), (unsigned char)(rgb >> 8), (unsigned char)rgb, 255};
            }
            i = end + 1;
        } else if (html.compare(i, 5, "&amp;") == 0) {
            current += '&';
            i += 5;
        } else if (html.compare(i, 4, "&lt;") == 0) {
            current += '<';
            i += 4;
        } else if (html.compare(i, 4, "&gt;") == 0) {
            current += '>';
            i += 4;
        } else {
            current += html[i++];
        }
    }
    if (!current.empty() || !hasParagraph) lines.push_back(current);
    return lines;
}

std::vector<std::string> SplitLines(const std::string& text) {
    std::vector<std::string> lines;
    size_t start = 0;
    while (true) {
        const size_t end = text.find('\n', start);
        lines.push_back(text.substr(start, end == std::string::npos ? std::string::npos : end - start));
        if (end == std::string::npos) break;
        start = end + 1;
    }
    return lines;
}

std::map<std::string, std::unique_ptr<Movie>>& MovieCache() {
    static std::map<std::string, std::unique_ptr<Movie>> cache;
    return cache;
}

struct ExternalTexture {
    const Texture2D* texture = nullptr;
    bool flipY = false;
};

std::map<std::string, ExternalTexture>& ExternalTextures() {
    static std::map<std::string, ExternalTexture> textures;
    return textures;
}

// 色変換の加算成分を扱うシェーダー（raylib の既定シェーダーに加算を足したもの）
constexpr const char* kColorAddFragment = R"(#version 330
in vec2 fragTexCoord;
in vec4 fragColor;
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform vec4 colorAdd;
out vec4 finalColor;
void main() {
    vec4 texel = texture(texture0, fragTexCoord);
    vec4 color = texel * fragColor * colDiffuse;
    color.rgb += colorAdd.rgb * texel.a;
    color.a += colorAdd.a * texel.a;
    finalColor = clamp(color, 0.0, 1.0);
}
)";

struct ColorAddShader {
    Shader shader{};
    int location = -1;
    bool tried = false;
    ColorF current{0.0f, 0.0f, 0.0f, 0.0f};
};

ColorAddShader& AddShader() {
    static ColorAddShader s;
    if (!s.tried) {
        s.tried = true;
        s.shader = LoadShaderFromMemory(nullptr, kColorAddFragment);
        s.location = GetShaderLocation(s.shader, "colorAdd");
    }
    return s;
}

bool SameColor(const ColorF& a, const ColorF& b) {
    return a.r == b.r && a.g == b.g && a.b == b.b && a.a == b.a;
}

// 加算成分を切り替える（切り替えるときは描画待ちを先に流す）
void SetColorAdd(const ColorF& add) {
    ColorAddShader& s = AddShader();
    if (s.location < 0 || SameColor(s.current, add)) return;
    rlDrawRenderBatchActive();
    const float value[4] = {add.r, add.g, add.b, add.a};
    SetShaderValue(s.shader, s.location, value, SHADER_UNIFORM_VEC4);
    s.current = add;
}

// 明るい文字には暗い縁取りを付ける（元の画面では縁取り付きで表示される）
Color OutlineFor(Color text) {
    const float luma = (0.3f * text.r + 0.59f * text.g + 0.11f * text.b) / 255.0f;
    return luma > 0.6f ? Color{40, 24, 16, text.a} : Color{0, 0, 0, 0};
}

// 8ビットで入っている色（塗り色）
unsigned char FillByte(float v256) {
    // 色表の値は /256 済みなので 256 倍して 0〜255 に戻す
    const float v = v256 * 256.0f;
    return v <= 0.0f ? 0 : v >= 255.0f ? 255 : (unsigned char)v;
}

} // namespace

// ===========================================================================
// ムービーの読み込み
// ===========================================================================
const Movie* LoadMovieFile(const std::string& path) {
    auto& cache = MovieCache();
    auto found = cache.find(path);
    if (found != cache.end()) return found->second.get();

    auto movie = std::make_unique<Movie>();
    movie->path = path;
    std::string error;
    const std::string base = std::string(kDataRoot) + path;
    if (!Load((base + ".nulm").c_str(), movie->file, &error)) {
        TraceLog(LOG_WARNING, "Lumen: %s を読み込めません: %s", path.c_str(), error.c_str());
        cache[path] = nullptr;
        return nullptr;
    }
    movie->textures = &AssetCache::Get().Nutexb(base + ".nutexb");
    return (cache[path] = std::move(movie)).get();
}

void UnloadAllMovies() {
    MovieCache().clear();
}

void SetExternalTexture(const std::string& name, const Texture2D* texture, bool flipY) {
    if (texture) ExternalTextures()[name] = ExternalTexture{texture, flipY};
    else ExternalTextures().erase(name);
}

void ClearExternalTextures() {
    ExternalTextures().clear();
}

// ===========================================================================
// MovieClip
// ===========================================================================
MovieClip::MovieClip(const Movie* movie, const Sprite* sprite, std::string name)
    : movie_(movie), sprite_(sprite), name_(std::move(name)) {
    if (sprite_ && !sprite_->frames.empty()) ApplyFrame(0, true);
}

MovieClip* MovieClip::Child(const std::string& name) {
    for (auto& entry : displayList_) {
        if (entry.second.clip && entry.second.name == name) return entry.second.clip.get();
    }
    return nullptr;
}

MovieClip* MovieClip::Find(const std::string& path) {
    // "a/b/c" は a を探してから順にたどる
    const size_t slash = path.find('/');
    if (slash != std::string::npos) {
        MovieClip* head = Find(path.substr(0, slash));
        return head ? head->Find(path.substr(slash + 1)) : nullptr;
    }

    // 近いものから探す
    std::deque<MovieClip*> queue{this};
    while (!queue.empty()) {
        MovieClip* clip = queue.front();
        queue.pop_front();
        for (auto& entry : clip->displayList_) {
            if (!entry.second.clip) continue;
            if (entry.second.name == path) return entry.second.clip.get();
            queue.push_back(entry.second.clip.get());
        }
    }
    return nullptr;
}

int MovieClip::LabelFrame(const std::string& label) const {
    if (!sprite_) return -1;
    for (const Label& l : sprite_->labels) {
        if (l.name == label) return l.frame;
    }
    return -1;
}

bool MovieClip::GotoAndPlay(const std::string& label) {
    const int frame = LabelFrame(label);
    if (frame < 0) return false;
    GotoAndPlay(frame);
    return true;
}

bool MovieClip::GotoAndStop(const std::string& label) {
    const int frame = LabelFrame(label);
    if (frame < 0) return false;
    GotoAndStop(frame);
    return true;
}

void MovieClip::GotoAndPlay(int frame) {
    if (!sprite_ || sprite_->frames.empty()) return;
    frame = std::max(0, std::min(frame, FrameCount() - 1));
    playing_ = true;
    if (frame > frame_) {
        for (int f = frame_ + 1; f <= frame; ++f) ApplyFrame(f, f == frame);
    } else if (frame < frame_) {
        Rebuild(frame);
    }
    skipTick_ = true;
}

void MovieClip::GotoAndStop(int frame) {
    GotoAndPlay(frame);
    playing_ = false;
}

void MovieClip::SetText(const std::string& textName, const std::string& key) {
    texts_[textName] = key;
}

void MovieClip::SetText(const std::string& instance, const std::string& textName, const std::string& key) {
    if (MovieClip* child = Child(instance)) child->SetText(textName, key);
}

void MovieClip::SetLoadedMovies(const std::map<std::string, const Movie*>* movies) {
    loadedMovies_ = movies;
    for (auto& entry : displayList_) {
        if (entry.second.clip) entry.second.clip->SetLoadedMovies(movies);
    }
}

void MovieClip::Replace(const Movie* movie) {
    if (!movie) return;
    const auto found = movie->file.sprites.find(movie->file.rootId);
    if (found == movie->file.sprites.end()) return;

    movie_ = movie;
    sprite_ = &found->second;
    displayList_.clear();
    texts_.clear();
    frame_ = 0;
    playing_ = true;
    external_ = true;
    skipTick_ = true;
    ApplyFrame(0, true);
}

void MovieClip::Tick() {
    if (skipTick_) {
        skipTick_ = false;
    } else if (playing_ && FrameCount() > 1) {
        if (frame_ + 1 >= FrameCount()) Rebuild(0);   // 最後まで来たら先頭に戻る
        else ApplyFrame(frame_ + 1, true);
    }
    for (auto& entry : displayList_) {
        if (entry.second.clip) entry.second.clip->Tick();
    }
}

// ---------------------------------------------------------------------------
// タイムライン
// ---------------------------------------------------------------------------
namespace {
// Rebuild 中に使い回せる古い表示物
thread_local std::map<int, DisplayObject>* g_reuse = nullptr;

// ---- マスク（Placement::clipDepth）----
//   マスクの形（画面の座標の三角形。3つずつ）で、その上の深さに置かれたものを切り抜いて描く。
//   ステンシルを使わず、描く三角形をマスクの三角形で切って（Sutherland–Hodgman）画像の座標も補間する
struct ClipVertex {
    float x, y, u, v;
};
thread_local const std::vector<Vector2>* g_mask = nullptr;

// 描いている舞台の文字のフォント（Stage::SetTextFace）
thread_local FontFace g_stageFace = FontFace::Auto;

std::vector<ClipVertex> ClipTriangle(const ClipVertex (&tri)[3], const Vector2* mask) {
    std::vector<ClipVertex> poly(tri, tri + 3);
    // マスクの三角形の向き（どちら回りでも内側を判定できるように）
    const float area = (mask[1].x - mask[0].x) * (mask[2].y - mask[0].y) - (mask[1].y - mask[0].y) * (mask[2].x - mask[0].x);
    if (std::fabs(area) < 1e-6f) return {};
    const float sign = area > 0.0f ? 1.0f : -1.0f;
    for (int e = 0; e < 3 && !poly.empty(); ++e) {
        const Vector2 a = mask[e], b = mask[(e + 1) % 3];
        auto side = [&](const ClipVertex& p) { return sign * ((b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x)); };
        std::vector<ClipVertex> out;
        for (size_t i = 0; i < poly.size(); ++i) {
            const ClipVertex& cur = poly[i];
            const ClipVertex& next = poly[(i + 1) % poly.size()];
            const float sc = side(cur), sn = side(next);
            if (sc >= 0.0f) out.push_back(cur);
            if ((sc >= 0.0f) != (sn >= 0.0f)) {
                const float t = sc / (sc - sn);
                out.push_back(ClipVertex{cur.x + (next.x - cur.x) * t, cur.y + (next.y - cur.y) * t, cur.u + (next.u - cur.u) * t,
                                         cur.v + (next.v - cur.v) * t});
            }
        }
        poly = std::move(out);
    }
    return poly;
}
}

void MovieClip::ApplyFrame(int frame, bool runActions) {
    if (!sprite_ || frame < 0 || frame >= FrameCount()) return;

    std::vector<int> actions;
    for (const FrameCommand& cmd : sprite_->frames[size_t(frame)].commands) {
        switch (cmd.type) {
        case FrameCommand::Type::Place:
            Place(cmd.place);
            break;
        case FrameCommand::Type::Remove:
            displayList_.erase(cmd.depth);
            break;
        case FrameCommand::Type::Action:
            actions.push_back(cmd.actionId);
            break;
        default:
            break;
        }
    }
    frame_ = frame;
    if (runActions) {
        for (int id : actions) RunAction(id);
    }
}

// 先頭から目的のフレームまで組み立て直す。同じ配置のものは使い回して状態を保つ
void MovieClip::Rebuild(int targetFrame) {
    std::map<int, DisplayObject> old = std::move(displayList_);
    displayList_.clear();

    std::map<int, DisplayObject>* previous = g_reuse;
    g_reuse = &old;
    for (int f = 0; f <= targetFrame; ++f) ApplyFrame(f, f == targetFrame);
    g_reuse = previous;
}

void MovieClip::Place(const Placement& place) {
    const File& file = movie_->file;

    auto applyTransform = [&](DisplayObject& obj, bool reset) {
        const uint16_t flags = uint16_t(place.transformFlags);
        if (flags == kTransformNone) {
            if (reset) obj.matrix = Matrix();
        } else if (flags == kTransformPosition) {
            if (place.transformIndex >= 0 && size_t(place.transformIndex) < file.positions.size()) {
                obj.matrix = file.positions[size_t(place.transformIndex)];
            }
        } else if (place.transformIndex >= 0 && size_t(place.transformIndex) < file.transforms.size()) {
            obj.matrix = file.transforms[size_t(place.transformIndex)];
        }
        if (place.colorMult >= 0 && size_t(place.colorMult) < file.colors.size()) {
            obj.mult = file.colors[size_t(place.colorMult)];
        } else if (reset) {
            obj.mult = ColorF();
        }
        if (place.colorAdd >= 0 && size_t(place.colorAdd) < file.colors.size()) {
            obj.add = file.colors[size_t(place.colorAdd)];
        } else if (reset) {
            obj.add = ColorF{0.0f, 0.0f, 0.0f, 0.0f};
        }
        obj.blendMode = place.blendMode;
    };

    if (place.mode == 1) {
        // 同じ深度に同じ配置が残っていればそのまま使う（中身や再生状態を保つ）
        if (auto existing = displayList_.find(place.depth); existing != displayList_.end() &&
            existing->second.characterId == place.characterId &&
            existing->second.placementId == place.placementId) {
            applyTransform(existing->second, true);
            return;
        }

        DisplayObject obj;
        bool reused = false;
        if (g_reuse) {
            auto found = g_reuse->find(place.depth);
            if (found != g_reuse->end() && found->second.characterId == place.characterId &&
                found->second.placementId == place.placementId) {
                obj = std::move(found->second);
                g_reuse->erase(found);
                reused = true;
            }
        }
        obj.clipDepth = place.clipDepth;
        if (!reused) {
            obj.depth = place.depth;
            obj.characterId = place.characterId;
            obj.placementId = place.placementId;
            obj.name = file.Symbol(place.nameSymbol);
            obj.clip = CreateCharacter(place.characterId, obj.name, obj);
        }
        applyTransform(obj, true);
        displayList_[place.depth] = std::move(obj);
        return;
    }

    auto found = displayList_.find(place.depth);
    if (found == displayList_.end()) return;
    DisplayObject& obj = found->second;

    // 3: 中身の差し替え
    if (place.mode == 3 && place.characterId >= 0 && place.characterId != obj.characterId) {
        obj.characterId = place.characterId;
        obj.shape = nullptr;
        obj.text = nullptr;
        obj.clip = CreateCharacter(place.characterId, obj.name, obj);
    }
    applyTransform(obj, false);
}

std::unique_ptr<MovieClip> MovieClip::CreateCharacter(int characterId, const std::string& name, DisplayObject& object) {
    const File& file = movie_->file;
    if (auto shape = file.shapes.find(characterId); shape != file.shapes.end()) {
        object.shape = &shape->second;
        return nullptr;
    }
    if (auto text = file.texts.find(characterId); text != file.texts.end()) {
        object.text = &text->second;
        return nullptr;
    }
    if (auto sprite = file.sprites.find(characterId); sprite != file.sprites.end()) {
        // LoadMovie で登録された名前なら、そのムービーで作る
        const Movie* loaded = nullptr;
        if (loadedMovies_) {
            auto found = loadedMovies_->find(name_ + "/" + name);
            if (found == loadedMovies_->end()) found = loadedMovies_->find(name);
            if (found != loadedMovies_->end() && found->second != movie_) loaded = found->second;   // 自分の中に同じ名前があっても繰り返さない
        }
        auto clip = std::make_unique<MovieClip>(movie_, loaded ? nullptr : &sprite->second, name);
        clip->parent_ = this;
        clip->loadedMovies_ = loadedMovies_;
        if (loaded) clip->Replace(loaded);
        return clip;
    }
    return nullptr;
}

DisplayObject* MovieClip::FindSelf() const {
    if (!parent_) return nullptr;
    for (auto& entry : parent_->displayList_) {
        if (entry.second.clip.get() == this) return &entry.second;
    }
    return nullptr;
}

Vector2 MovieClip::Position() const {
    const DisplayObject* self = FindSelf();
    return self ? Vector2{self->matrix.x, self->matrix.y} : Vector2{0.0f, 0.0f};
}

Matrix MovieClip::PlacementMatrix() const {
    const DisplayObject* self = FindSelf();
    return self ? self->matrix : Matrix();
}

Matrix Concat(const Matrix& parent, const Matrix& child) {
    return Multiply(parent, child);
}

void MovieClip::SetPosition(Vector2 position) {
    if (DisplayObject* self = FindSelf()) {
        self->matrix.x = position.x;
        self->matrix.y = position.y;
    }
}

// フレームスクリプト（AVM1 のうち使われている命令だけ）
void MovieClip::RunAction(int actionId) {
    const File& file = movie_->file;
    if (actionId < 0 || size_t(actionId) >= file.actions.size()) return;

    // スクリプト同士が移動し合って止まらなくなるのを防ぐ
    static int depth = 0;
    if (depth > 8) return;
    struct Guard {
        Guard() { ++depth; }
        ~Guard() { --depth; }
    } guard;
    const std::vector<uint8_t>& code = file.actions[size_t(actionId)];

    int gotoFrame = -1;
    bool play = playing_;
    size_t i = 0;
    while (i < code.size()) {
        const uint8_t op = code[i++];
        if (op == 0x00) break;

        uint16_t length = 0;
        const uint8_t* data = nullptr;
        if (op >= 0x80) {
            if (i + 2 > code.size()) break;
            length = uint16_t(code[i] | (code[i + 1] << 8));
            data = &code[i + 2];
            i += 2 + length;
        }

        switch (op) {
        case 0x06: play = true; break;      // Play
        case 0x07: play = false; break;     // Stop
        case 0x81:                          // GotoFrame
            if (length >= 2) gotoFrame = data[0] | (data[1] << 8);
            play = false;
            break;
        case 0x8C:                          // GoToLabel（引数は文字列表の番号）
            if (length >= 2) gotoFrame = LabelFrame(file.Symbol(data[0] | (data[1] << 8)));
            play = false;
            break;
        default:
            break;
        }
    }

    // 移動先のフレームスクリプトが再生状態を決めるので、移動したときは上書きしない
    if (gotoFrame >= 0 && gotoFrame != frame_) {
        if (play) GotoAndPlay(gotoFrame);
        else GotoAndStop(gotoFrame);
        return;
    }
    playing_ = play;
}

// ---------------------------------------------------------------------------
// 描画
// ---------------------------------------------------------------------------
void MovieClip::CollectTriangles(const DisplayObject& obj, const Matrix& m, std::vector<Vector2>& out) {
    if (obj.shape) {
        for (const Graphic& g : obj.shape->graphics) {
            for (size_t t = 0; t + 2 < g.indices.size(); t += 3) {
                if (g.indices[t] >= g.vertices.size() || g.indices[t + 1] >= g.vertices.size() || g.indices[t + 2] >= g.vertices.size()) continue;
                for (int k = 0; k < 3; ++k) {
                    const Vertex& v = g.vertices[g.indices[t + size_t(k)]];
                    out.push_back(Vector2{m.a * v.x + m.c * v.y + m.x, m.b * v.x + m.d * v.y + m.y});
                }
            }
        }
    } else if (obj.clip && obj.clip->visible_) {
        for (const auto& entry : obj.clip->displayList_) CollectTriangles(entry.second, Multiply(m, entry.second.matrix), out);
    }
}

void MovieClip::Draw(const Matrix& parent, const ColorF& parentColor, const ColorF& parentAdd) const {
    if (!visible_ || !movie_) return;
    const File& file = movie_->file;

    // マスク: clipDepth のある物は描かずに形を覚え、その上の深さ（clipDepth まで）を切り抜く
    const std::vector<Vector2>* outerMask = g_mask;
    std::vector<Vector2> maskTriangles;
    int maskUntil = -1;
    struct MaskRestore {
        const std::vector<Vector2>* saved;
        ~MaskRestore() { g_mask = saved; }
    } restore{outerMask};

    for (const auto& entry : displayList_) {
        if (maskUntil >= 0 && entry.first > maskUntil) {
            g_mask = outerMask;
            maskUntil = -1;
        }
        if (hiddenDepths_.count(entry.first)) continue;
        const DisplayObject& obj = entry.second;
        const Matrix m = Multiply(parent, obj.matrix);
        if (obj.clipDepth > 0) {
            maskTriangles.clear();
            CollectTriangles(obj, m, maskTriangles);
            maskUntil = obj.clipDepth;
            g_mask = &maskTriangles;
            continue;
        }
        ColorF mult = obj.mult;
        // 別の深さの透明度に合わせる（ゲーム側の指定。ロード画面の曲名を帯と一緒に出し入れするなど）
        if (auto link = alphaLinks_.find(entry.first); link != alphaLinks_.end()) {
            if (auto source = displayList_.find(link->second); source != displayList_.end()) mult.a = source->second.mult.a;
        }
        if (auto fixed = fixedAlphas_.find(entry.first); fixed != fixedAlphas_.end()) mult.a = fixed->second;
        const ColorF color = Multiply(Multiply(parentColor, tint_), mult);
        // 親の乗算は子の加算にもかかる（Flash の ColorTransform の合成）
        const ColorF add{parentColor.r * obj.add.r + parentAdd.r, parentColor.g * obj.add.g + parentAdd.g,
                         parentColor.b * obj.add.b + parentAdd.b, parentColor.a * obj.add.a + parentAdd.a};
        if (color.a <= 0.0f && add.a <= 0.0f) continue;

        if (obj.blendMode == kBlendAdd) rlSetBlendMode(RL_BLEND_ADDITIVE);

        if (obj.clip) {
            obj.clip->Draw(m, color, add);
        } else if (obj.shape) {
            SetColorAdd(add);
            for (const Graphic& g : obj.shape->graphics) {
                Color tint{ToByte(color.r), ToByte(color.g), ToByte(color.b), ToByte(color.a)};
                unsigned int textureId = rlGetTextureIdDefault();
                const Texture2D* atlas = nullptr;
                bool flipV = false;
                if (g.fillType == 0) {
                    // 差し込み枠。登録されたテクスチャに塗り色（8ビット）を乗算して描く
                    // 図形が無名のときは、それを置いているムービークリップの名前で探す
                    const auto external = ExternalTextures().find(obj.name.empty() ? name_ : obj.name);
                    if (external == ExternalTextures().end() || !external->second.texture) continue;
                    textureId = external->second.texture->id;
                    flipV = external->second.flipY;
                    if (g.atlas >= 0 && size_t(g.atlas) < file.colors.size()) {
                        const ColorF& fill = file.colors[size_t(g.atlas)];
                        tint.r = (unsigned char)(tint.r * FillByte(fill.r) / 255);
                        tint.g = (unsigned char)(tint.g * FillByte(fill.g) / 255);
                        tint.b = (unsigned char)(tint.b * FillByte(fill.b) / 255);
                        tint.a = (unsigned char)(tint.a * FillByte(fill.a) / 255);
                    }
                } else if (movie_->textures) {
                    for (size_t a = 0; a < file.atlases.size(); ++a) {
                        if (file.atlases[a].id == g.atlas && a < movie_->textures->size()) {
                            atlas = &(*movie_->textures)[a];
                            textureId = atlas->id;
                        }
                    }
                }

                // 数ピクセルの画像を大きく引き伸ばす図形（看板の中の帯など）は、画像の端の画素が
                // 隣の透明な画素と混ざって線のように見える。引き伸ばす向きだけ、画像の範囲を半画素ずつ内側に寄せる
                float uMin = 0.0f, uMax = 0.0f, vMin = 0.0f, vMax = 0.0f, insetU = 0.0f, insetV = 0.0f;
                if (atlas && atlas->width > 0 && atlas->height > 0 && !g.vertices.empty()) {
                    float xMin = g.vertices[0].x, xMax = xMin, yMin = g.vertices[0].y, yMax = yMin;
                    uMin = uMax = g.vertices[0].u;
                    vMin = vMax = g.vertices[0].v;
                    for (const Vertex& v : g.vertices) {
                        xMin = std::min(xMin, v.x), xMax = std::max(xMax, v.x);
                        yMin = std::min(yMin, v.y), yMax = std::max(yMax, v.y);
                        uMin = std::min(uMin, v.u), uMax = std::max(uMax, v.u);
                        vMin = std::min(vMin, v.v), vMax = std::max(vMax, v.v);
                    }
                    const float texelsU = (uMax - uMin) * float(atlas->width);
                    const float texelsV = (vMax - vMin) * float(atlas->height);
                    const float drawnX = (xMax - xMin) * std::sqrt(m.a * m.a + m.b * m.b);
                    const float drawnY = (yMax - yMin) * std::sqrt(m.c * m.c + m.d * m.d);
                    if (texelsU > 1.0f && drawnX > texelsU * 1.5f) insetU = std::min(0.5f / float(atlas->width), (uMax - uMin) * 0.5f);
                    if (texelsV > 1.0f && drawnY > texelsV * 1.5f) insetV = std::min(0.5f / float(atlas->height), (vMax - vMin) * 0.5f);
                }

                // rlBegin(RL_TRIANGLES) はテクスチャ指定が既定に戻るため、
                // raylib と同じく RL_QUADS で描く（三角形は最後の頂点を重ねて四角形にする）
                // 画面の座標と画像の座標にした頂点
                auto project = [&](const Vertex& v) {
                    const float u = std::clamp(v.u, uMin + insetU, std::max(uMin + insetU, uMax - insetU));
                    const float tv = std::clamp(v.v, vMin + insetV, std::max(vMin + insetV, vMax - insetV));
                    return ClipVertex{m.a * v.x + m.c * v.y + m.x, m.b * v.x + m.d * v.y + m.y, insetU > 0.0f ? u : v.u,
                                      flipV ? 1.0f - (insetV > 0.0f ? tv : v.v) : (insetV > 0.0f ? tv : v.v)};
                };
                auto emit = [](const ClipVertex& v) {
                    rlTexCoord2f(v.u, v.v);
                    rlVertex2f(v.x, v.y);
                };
                rlSetTexture(textureId);
                rlBegin(RL_QUADS);
                rlColor4ub(tint.r, tint.g, tint.b, tint.a);
                for (size_t t = 0; t + 2 < g.indices.size(); t += 3) {
                    const uint16_t i0 = g.indices[t], i1 = g.indices[t + 1], i2 = g.indices[t + 2];
                    if (i0 >= g.vertices.size() || i1 >= g.vertices.size() || i2 >= g.vertices.size()) continue;
                    const ClipVertex tri[3] = {project(g.vertices[i0]), project(g.vertices[i1]), project(g.vertices[i2])};
                    if (!g_mask) {
                        emit(tri[0]);
                        emit(tri[1]);
                        emit(tri[2]);
                        emit(tri[2]);
                        continue;
                    }
                    // マスクがかかっているときは、マスクの三角形ごとに切り抜いた形だけ描く
                    for (size_t k = 0; k + 2 < g_mask->size(); k += 3) {
                        const std::vector<ClipVertex> poly = ClipTriangle(tri, &(*g_mask)[k]);
                        for (size_t p = 1; p + 1 < poly.size(); ++p) {
                            emit(poly[0]);
                            emit(poly[p]);
                            emit(poly[p + 1]);
                            emit(poly[p + 1]);
                        }
                    }
                }
                rlEnd();
                rlSetTexture(0);
            }
        } else if (obj.text) {
            SetColorAdd(ColorF{0.0f, 0.0f, 0.0f, 0.0f});   // 文字色に加算済み
            const TextField& field = *obj.text;
            Color textColor = WHITE;
            std::vector<std::string> lines = ParseHtmlText(field.initialHtml, &textColor);
            if (auto found = texts_.find(obj.name); found != texts_.end()) {
                lines = SplitLines(WordList::Get().Text(found->second));
            }

            // 文字の大きさは縦の倍率で決める（横だけ縮めて枠に収める配置がある）
            const float scaleX = std::sqrt(m.a * m.a + m.b * m.b);
            const float scaleY = std::sqrt(m.c * m.c + m.d * m.d);
            float size = field.size * scaleY;
            float lineHeight = (field.size + field.leading) * scaleY;
            Color outline{0, 0, 0, 0};
            float outlineWidth = 0.0f;
            if (textSwap_ && field.leading > 0.0f) {
                // ゲーム側で指定した文字（選曲のジャンルの看板）: 白い文字に、配置の色（加算の色 = ジャンルの色）の縁取り。
                // 縁取りの太さは文字の定義の値（field.leading）
                textColor = Color{255, 255, 255, ToByte(color.a + add.a)};
                outline = Color{ToByte(add.r), ToByte(add.g), ToByte(add.b), ToByte(color.a + add.a)};
                outlineWidth = field.leading * scaleY;
            } else {
                textColor.r = ToByte(textColor.r / 255.0f * color.r + add.r);
                textColor.g = ToByte(textColor.g / 255.0f * color.g + add.g);
                textColor.b = ToByte(textColor.b / 255.0f * color.b + add.b);
                textColor.a = ToByte(color.a + add.a);
                outline = OutlineFor(textColor);
                outlineWidth = size * 0.09f;
            }
            const auto style = textStyles_.find(obj.name);
            FontFace face = style != textStyles_.end() ? style->second.face : FontFace::Auto;
            if (face == FontFace::Auto) face = g_stageFace;
            if (style != textStyles_.end() && style->second.colors) {
                const TextStyle& s = style->second;
                const float alpha = std::clamp(color.a + add.a, 0.0f, 1.0f);
                textColor = Color{s.fill.r, s.fill.g, s.fill.b, ToByte(s.fill.a / 255.0f * alpha)};
                outline = Color{s.outline.r, s.outline.g, s.outline.b, ToByte(s.outline.a / 255.0f * alpha)};
                outlineWidth = size * s.outlineRatio;
            }

            // 表示範囲の中で揃える（範囲がなければ原点基準）
            Rect box{0.0f, 0.0f, 0.0f, 0.0f};
            if (field.bounds >= 0 && size_t(field.bounds) < file.bounds.size()) box = file.bounds[size_t(field.bounds)];
            float localX = box.left;
            TextAlign align = TextAlign::Left;
            if (field.align == 2) {
                localX = (box.left + box.right) * 0.5f;
                align = TextAlign::Center;
            } else if (field.align == 1) {
                localX = box.right;
                align = TextAlign::Right;
            }
            // 枠の幅に収まらない行があれば全体を縮める
            const float boxWidth = (box.right - box.left) * scaleX;
            if (boxWidth > 1.0f) {
                float widest = 0.0f;
                for (const std::string& line : lines) widest = std::max(widest, GameFont::Get().Measure(line.c_str(), size, face).x);
                if (widest > boxWidth) {
                    const float shrink = boxWidth / widest;
                    size *= shrink;
                    lineHeight *= shrink;
                }
            }

            // 枠の中で縦方向の中央に置く
            const float safeScaleY = std::max(scaleY, 0.0001f);
            const float textHeight = size + lineHeight * float(lines.size() - 1);
            const float boxHeight = (box.bottom - box.top) * scaleY;
            const float top = box.top + std::max(0.0f, (boxHeight - textHeight) * 0.5f) / safeScaleY + textOffsetY_ +
                              (style != textStyles_.end() ? style->second.offsetY : 0.0f);
            for (size_t l = 0; l < lines.size(); ++l) {
                const float localY = top + float(l) * lineHeight / safeScaleY;
                const float x = m.a * localX + m.c * localY + m.x;
                const float y = m.b * localX + m.d * localY + m.y;
                GameFont::Get().Draw(lines[l].c_str(), x, y, size, textColor, align, outline.a ? outlineWidth : 0.0f, outline, face);
            }
        }

        if (obj.blendMode == kBlendAdd) rlSetBlendMode(RL_BLEND_ALPHA);
    }
}

// ===========================================================================
// Stage
// ===========================================================================
bool Stage::Load(const std::string& path) {
    const Movie* movie = LoadMovieFile(path);
    if (!movie) return false;
    const auto root = movie->file.sprites.find(movie->file.rootId);
    if (root == movie->file.sprites.end()) return false;

    root_ = std::make_unique<MovieClip>(movie, &root->second, "root");
    frameRate_ = movie->file.frameRate > 0.0f ? movie->file.frameRate : 60.0f;
    accumulator_ = 0.0f;
    return true;
}

bool Stage::LoadMovie(const std::string& path, const std::string& instance) {
    const Movie* movie = LoadMovieFile(path);
    if (!movie || !root_) {
        TraceLog(LOG_WARNING, "Lumen: LoadMovie(%s, %s) に失敗しました", path.c_str(), instance.c_str());
        return false;
    }
    // 名前で覚えておき、今あるインスタンスはすぐ差し替える（入れ子の中も探す）。
    // "親/名前" で渡したときは、その親の直下の同じ名前だけを差し替える（よくある名前が別のムービーの中にもあるとき用。
    // 例: 選曲画面の main/option と、オプションのアイコンの中の option）
    const size_t slash = instance.rfind('/');
    const size_t parentStart = slash == std::string::npos ? std::string::npos : instance.rfind('/', slash - 1);
    const std::string name = slash == std::string::npos ? instance
                                                        : instance.substr(parentStart == std::string::npos ? 0 : parentStart + 1);
    loadedMovies_[name] = movie;
    root_->SetLoadedMovies(&loadedMovies_);
    if (MovieClip* clip = GetMovieClip(instance)) clip->Replace(movie);
    return true;
}

MovieClip* Stage::GetMovieClip(const std::string& path) {
    return root_ ? root_->Find(path) : nullptr;
}

void Stage::Update(float deltaTime) {
    if (!root_) return;
    const float step = 1.0f / frameRate_;
    accumulator_ = std::min(accumulator_ + deltaTime, step * 4.0f);
    while (accumulator_ >= step) {
        root_->Tick();
        accumulator_ -= step;
    }
}

void Stage::Draw(float x, float y, float scale) const {
    if (!root_) return;

    Matrix m;
    m.a = m.d = scale;
    m.x = x;
    m.y = y;

    const FontFace previous = g_stageFace;
    g_stageFace = textFace_;
    BeginBatch();
    DrawClip(root_.get(), m);
    EndBatch();
    g_stageFace = previous;
}

namespace {
bool g_batchShader = false;
}

void BeginBatch() {
    // 図形の向き（頂点の並び）がまちまちなので裏面カリングを切る
    rlDrawRenderBatchActive();
    rlDisableBackfaceCulling();
    const Shader& shader = AddShader().shader;
    g_batchShader = shader.id > 0 && AddShader().location >= 0;
    if (g_batchShader) BeginShaderMode(shader);
    SetColorAdd(ColorF{0.0f, 0.0f, 0.0f, 0.0f});
}

void DrawClip(const MovieClip* clip, const Matrix& matrix, float alpha) {
    if (!clip || !clip->IsVisible()) return;
    const ColorF noAdd{0.0f, 0.0f, 0.0f, 0.0f};
    ColorF color;
    color.a *= alpha;
    clip->Draw(matrix, color, noAdd);
    SetColorAdd(noAdd);
}

void EndBatch() {
    if (g_batchShader) EndShaderMode();
    g_batchShader = false;
    rlDrawRenderBatchActive();
    rlEnableBackfaceCulling();
}

} // namespace Lumen
