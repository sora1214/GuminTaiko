#pragma once
#include <map>
#include <memory>
#include <set>
#include <string>
#include <vector>

#include "GameFont.hpp"
#include "Lumen.hpp"
#include "raylib.h"

// Lumen の再生エンジン
// lua 側の Lumen / MovieClip の操作（GetMovieClip, GotoAndPlay, LoadMovie など）に合わせた API を持つ。
namespace Lumen {

// 読み込んだ .nulm と、対応する .nutexb のテクスチャ
struct Movie {
    std::string path;
    File file;
    const std::vector<Texture2D>* textures = nullptr;
};

class MovieClip;

// 表示リストの1要素（ある深度に置かれたもの）
struct DisplayObject {
    int depth = 0;
    int characterId = -1;
    int placementId = -1;
    std::string name;
    Matrix matrix;
    ColorF mult;
    ColorF add{0.0f, 0.0f, 0.0f, 0.0f};
    int blendMode = 0;
    int clipDepth = 0;        // マスク（Placement::clipDepth）
    const Shape* shape = nullptr;
    const TextField* text = nullptr;
    std::unique_ptr<MovieClip> clip;
};

class MovieClip {
public:
    MovieClip(const Movie* movie, const Sprite* sprite, std::string name);

    // ---- lua と同じ操作 ----
    MovieClip* Child(const std::string& name);          // 直下のインスタンス
    MovieClip* Find(const std::string& path);           // "a/b/c" 形式、または子孫を名前で探す
    bool GotoAndPlay(const std::string& label);
    bool GotoAndStop(const std::string& label);
    void GotoAndPlay(int frame);
    void GotoAndStop(int frame);
    void Play() { playing_ = true; }
    void Stop() { playing_ = false; }
    bool IsPlay() const { return playing_ && FrameCount() > 1; }
    void SetVisible(bool visible) { visible_ = visible; }
    bool IsVisible() const { return visible_; }
    // テキストを差し替える（lua: mc:SetText(textName, key) / mc:SetText(instance, textName, key)）
    // textName はテキストの配置名、instance は直下の子インスタンス名。key は描画時に WordList で文言に変換する
    void SetText(const std::string& textName, const std::string& key);
    void SetText(const std::string& instance, const std::string& textName, const std::string& key);

    // 親から見た位置（lua: mc.x / mc.y）。タイムラインが動かすと上書きされる
    Vector2 Position() const;
    void SetPosition(Vector2 position);
    // 親の中での配置（位置・拡大・回転）
    Matrix PlacementMatrix() const;
    // 名前のない図形も含め、この深さに置かれたものを描かない（タイムラインが置き直しても隠したまま）
    void HideDepth(int depth) { hiddenDepths_.insert(depth); }
    // このクリップの中身すべての色に掛ける（ゲーム側で色を変えるとき用。元のデータにはない）
    void SetTint(const ColorF& tint) { tint_ = tint; }
    // このクリップに直接置かれた文字を、クリップの座標で縦にずらす（ゲーム側で位置を合わせるとき用。元のデータにはない）
    void SetTextOffsetY(float offset) { textOffsetY_ = offset; }
    // このクリップに直接置かれた縁取りつきの文字を、白い文字に配置の色（加算の色）の縁取りで描く（選曲のジャンルの看板用）
    void SetTextSwapColors(bool swap) { textSwap_ = swap; }
    // depth に置かれたものの透明度を、sourceDepth に置かれたものの透明度にそろえる（元のデータにはない）
    void LinkDepthAlpha(int depth, int sourceDepth) { alphaLinks_[depth] = sourceDepth; }
    // depth に置かれたものの透明度を、動きに関係なく alpha で固定する（元のデータにはない。ロード画面のヒントを常に見せるなど）
    void FixDepthAlpha(int depth, float alpha) { fixedAlphas_[depth] = alpha; }
    // このクリップに直接置かれた textName の文字の色・縁取り・縦の位置を決める（ゲーム側で本家の見た目に合わせる用。
    // 元のデータにはない）。outlineRatio は文字の大きさに対する縁取りの太さ、offsetY はクリップの座標で下向きが正
    struct TextStyle {
        Color fill{255, 255, 255, 255};
        Color outline{0, 0, 0, 255};
        float outlineRatio = 0.0f;
        float offsetY = 0.0f;
        FontFace face = FontFace::Auto;   // ゲーム内フォントの選び方
        bool colors = true;               // false なら色と縁取りは元のデータのまま（フォントと位置だけ変える）
    };
    void SetTextStyle(const std::string& textName, const TextStyle& style) { textStyles_[textName] = style; }

    // ---- 情報 ----
    const std::string& Name() const { return name_; }
    int CurrentFrame() const { return frame_; }
    int FrameCount() const { return sprite_ ? int(sprite_->frames.size()) : 0; }
    int LabelFrame(const std::string& label) const;
    const Movie* GetMovie() const { return movie_; }
    const std::map<int, DisplayObject>& DisplayList() const { return displayList_; }

    // 別の .nulm のルートで中身を置き換える（lua: Lumen.LoadMovie）
    void Replace(const Movie* movie);
    void SetLoadedMovies(const std::map<std::string, const Movie*>* movies);   // 子孫にも伝える

    void Tick();
    // parentAdd は色変換の加算成分（Flash の ColorTransform と同じく 乗算 → 加算 の順）
    void Draw(const Matrix& parent, const ColorF& parentColor, const ColorF& parentAdd) const;

private:
    void ApplyFrame(int frame, bool runActions);
    void Rebuild(int targetFrame);
    void Place(const Placement& place);
    void RunAction(int actionId);
    std::unique_ptr<MovieClip> CreateCharacter(int characterId, const std::string& name, DisplayObject& object);

    DisplayObject* FindSelf() const;
    // マスクの形を画面の座標の三角形（3点ずつ）にして集める（ムービークリップなら中身をたどる）
    static void CollectTriangles(const DisplayObject& obj, const Matrix& m, std::vector<Vector2>& out);

    friend class Stage;
    const Movie* movie_ = nullptr;
    const Sprite* sprite_ = nullptr;
    MovieClip* parent_ = nullptr;
    // Stage::LoadMovie で登録したインスタンス名 → ムービー（あとから置かれたインスタンスにも差し込む）
    const std::map<std::string, const Movie*>* loadedMovies_ = nullptr;
    std::string name_;
    int frame_ = 0;
    bool playing_ = true;
    bool visible_ = true;
    bool external_ = false;           // LoadMovie で差し込まれた
    bool skipTick_ = true;            // 作られたフレームでは進めない
    std::map<int, DisplayObject> displayList_;
    std::map<std::string, std::string> texts_;   // テキストの配置名 → 表示する文字
    std::set<int> hiddenDepths_;
    ColorF tint_{1.0f, 1.0f, 1.0f, 1.0f};
    float textOffsetY_ = 0.0f;
    bool textSwap_ = false;
    std::map<std::string, TextStyle> textStyles_;
    std::map<int, int> alphaLinks_;
    std::map<int, float> fixedAlphas_;
};

// 1枚の画面（ルートのムービー + LoadMovie で差し込んだムービー）
class Stage {
public:
    bool Load(const std::string& path);                                   // "lumen/000_default/entry/entry"
    // 指定インスタンスの中身を差し替える。まだ置かれていない（タイムラインがあとで置く）インスタンスにも効く
    bool LoadMovie(const std::string& path, const std::string& instance);
    MovieClip* GetMovieClip(const std::string& path);
    MovieClip* Root() { return root_.get(); }

    void Update(float deltaTime);
    void Draw(float x = 0.0f, float y = 0.0f, float scale = 1.0f) const;
    // この舞台の文字をすべてこのフォントで描く（文字ごとの SetTextStyle で face を決めたものはそちらが優先。元のデータにはない）
    void SetTextFace(FontFace face) { textFace_ = face; }

private:
    FontFace textFace_ = FontFace::Auto;
    std::unique_ptr<MovieClip> root_;
    std::map<std::string, const Movie*> loadedMovies_;
    float accumulator_ = 0.0f;
    float frameRate_ = 60.0f;
};

// 1つのムービークリップを、指定した変換で描く（音符のように同じ絵をいくつも並べるとき用）。
// 描く前後に BeginBatch / EndBatch を1回ずつ呼ぶ。clip の配置（親の中での位置）は使わない
Matrix Concat(const Matrix& parent, const Matrix& child);   // 親 × 子
void BeginBatch();
void DrawClip(const MovieClip* clip, const Matrix& matrix, float alpha = 1.0f);
void EndBatch();

// 読み込んだムービーのキャッシュ
const Movie* LoadMovieFile(const std::string& path);
void UnloadAllMovies();

// 単色塗りの図形（fill=0）は、ゲーム側が描いた絵（3D のどんちゃんなど）の差し込み枠になっている。
// 配置名に対してテクスチャを登録すると、その枠に描く（塗り色は乗算）。登録がなければ何も描かない。
// flipY は RenderTexture のように上下が逆のテクスチャを渡すとき true にする
void SetExternalTexture(const std::string& name, const Texture2D* texture, bool flipY = false);
void ClearExternalTextures();

} // namespace Lumen
