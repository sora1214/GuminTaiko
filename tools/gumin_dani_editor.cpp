// GuminDaniEditor: 段位道場のお題（Dani/*.json）を作るアプリ
//   左で段位（五級〜達人）を選び、右で課題曲3曲・魂ゲージ・お題（3つまで）を決めて「保存」する。
//   課題曲は Songs にある TJA から選ぶ（曲名で検索）。JSON の形は include/DaniData.hpp のとおり
//
//   操作: マウスで操作する。数字の欄はクリックして打つ（Enter で決定）、◀ ▶ でも増減（Shift で 10 ずつ）
//   確認用: GuminDaniEditor [--level N] [--shot 出力.png --after 秒] [--click x,y@秒]
#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstdlib>
#include <filesystem>
#include <string>
#include <system_error>
#include <vector>

#include "AppGuard.hpp"
#include "DaniData.hpp"
#include "GameFont.hpp"
#include "SongDatabase.hpp"
#include "WordList.hpp"
#include "raylib.h"

using namespace GuminTaiko;
namespace fs = std::filesystem;

namespace {

constexpr int kWidth = 1600;
constexpr int kHeight = 900;

const Color kBack{250, 236, 210, 255};
const Color kInk{52, 26, 18, 255};
const Color kSub{120, 90, 60, 255};
const Color kPanel{255, 250, 238, 255};
const Color kGold{255, 206, 64, 255};
const Color kRed{236, 72, 48, 255};
const Color kGreen{40, 150, 70, 255};
const Color kDim{180, 160, 140, 255};

const char* const kCourseLabels[] = {"かんたん", "ふつう", "むずかしい", "おに", "おに裏"};
const char* const kExamLabels[] = {"なし", "良の数", "可の数", "不可の数", "コンボ数", "連打数", "スコア", "たたけた数"};

void Text(const std::string& text, float x, float y, float size, Color color, TextAlign align = TextAlign::Left) {
    GameFont::Get().Draw(text.c_str(), x, y, size, color, align);
}

// 幅に収めて描く（収まらなければ小さくし、それでも入らなければ後ろを「…」にする）
void FitText(const std::string& text, float x, float y, float width, float size, Color color, TextAlign align = TextAlign::Left) {
    GameFont& font = GameFont::Get();
    float w = font.Measure(text.c_str(), size).x;
    if (w > width) size = std::max(14.0f, size * width / w);
    std::string shown = text;
    while (font.Measure(shown.c_str(), size).x > width && !shown.empty()) {
        // UTF-8 の1文字ずつ後ろから消す
        size_t cut = shown.size() - 1;
        while (cut > 0 && (static_cast<unsigned char>(shown[cut]) & 0xC0) == 0x80) --cut;
        shown = shown.substr(0, cut);
        if (font.Measure((shown + "…").c_str(), size).x <= width) {
            shown += "…";
            break;
        }
    }
    Text(shown, x, y, size, color, align);
}

// マウスを受け付けないあいだ true（曲をえらぶ窓を開いているあいだの下の画面と、窓を開いたクリックを離すまでの窓）。
// 「曲をえらぶ」を押したクリックが、同じ位置に出てくる曲の行やボタンまで押してしまわないようにする
bool g_mouseBlocked = false;

// 確認用のクリック（--click x,y@秒）: その時刻に、その位置で左ボタンを数フレーム押したことにする
struct TestClick {
    Vector2 pos{};
    float time = -1.0f;
    int frames = 0;   // 押し始めてからのフレーム数（0: まだ 1: 押した瞬間 2〜4: 押したまま）
} g_testClick;

Vector2 MousePos() { return g_testClick.frames >= 1 && g_testClick.frames <= 4 ? g_testClick.pos : GetMousePosition(); }
bool MousePressed() { return g_testClick.frames == 1 || IsMouseButtonPressed(MOUSE_BUTTON_LEFT); }
bool MouseDown() { return (g_testClick.frames >= 1 && g_testClick.frames <= 4) || IsMouseButtonDown(MOUSE_BUTTON_LEFT); }

bool Hover(Rectangle r) { return !g_mouseBlocked && CheckCollisionPointRec(MousePos(), r); }
bool Clicked(Rectangle r) { return Hover(r) && MousePressed(); }

bool Button(Rectangle r, const std::string& label, bool enabled = true, bool selected = false) {
    const bool hover = enabled && Hover(r);
    DrawRectangleRounded(r, 0.3f, 8, !enabled ? Color{225, 215, 200, 255} : selected ? kGold : hover ? Color{255, 226, 140, 255} : kPanel);
    DrawRectangleRoundedLines(r, 0.3f, 8, 1.5f, enabled ? kInk : kDim);
    FitText(label, r.x + r.width * 0.5f, r.y + (r.height - 20.0f) * 0.5f, r.width - 12.0f, 20.0f, enabled ? kInk : kSub, TextAlign::Center);
    return enabled && hover && MousePressed();
}

std::string Lower(std::string s) {
    std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) { return char(std::tolower(c)); });
    return s;
}

struct NumberField {
    int* value = nullptr;
    int minValue = 0, maxValue = 9999999;
};

struct App {
    int level = 6;
    DaniCourse course;
    bool dirty = false;
    std::string message;
    bool messageOk = true;
    float messageTime = 0.0f;

    // 曲を選ぶ窓
    int pickingSong = -1;          // 選んでいる課題曲（0〜2）。-1 なら閉じている
    bool pickerReady = false;      // 曲をえらぶ窓を開いたクリックを離した（離すまで窓のクリックは受け付けない）
    std::string search;
    int scroll = 0;
    std::vector<const SongInfo*> results;

    // 数字の入力
    int* editing = nullptr;
    std::string editText;
    int editMin = 0, editMax = 0;

    void Show(const std::string& text, bool ok) {
        message = text;
        messageOk = ok;
        messageTime = 4.0f;
    }

    void Open(int newLevel) {
        level = std::clamp(newLevel, 1, kDaniLevelCount);
        if (const DaniCourse* c = DaniDatabase::Get().Course(level)) {
            course = *c;
        } else {
            course = DaniCourse();
            course.level = level;
            course.gaugeRed = 90;
            course.gaugeGold = 100;
            course.exams[0].type = DaniExamType::Good;
            course.exams[0].total = true;
        }
        dirty = false;
        pickingSong = -1;
        editing = nullptr;
    }

    void Save() {
        for (const DaniSong& s : course.songs) {
            if (s.tja.empty()) {
                Show("課題曲を3曲とも選んでください", false);
                return;
            }
        }
        course.level = level;
        const std::string path = DaniDatabase::DefaultPath(level);
        // 同じ段位の別の名前のファイルは消す（1つの段位に1ファイル）
        std::error_code ec;
        if (!course.file.empty() && fs::u8path(course.file) != fs::u8path(path)) fs::remove(fs::u8path(course.file), ec);
        if (!DaniDatabase::SaveFile(path, course)) {
            Show("保存できません: " + path, false);
            return;
        }
        course.file = path;
        DaniDatabase::Get().Reload();
        dirty = false;
        Show("保存しました: " + path, true);
    }

    void Delete() {
        if (course.file.empty()) return;
        std::error_code ec;
        fs::remove(fs::u8path(course.file), ec);
        DaniDatabase::Get().Reload();
        Show(std::string(DaniName(level)) + " のお題を消しました", true);
        Open(level);
    }

    void UpdateSearch() {
        results.clear();
        const std::string needle = Lower(search);
        for (const SongInfo& song : SongDatabase::Get().AllSongs()) {
            if (song.sample) continue;   // TJA のない曲（サンプルの譜面）はお題にできない
            if (!song.fromFumen && song.genreNo != kGenreCustom) continue;   // お題にできるのは fumen の TJA と創作譜面
            const std::string title = WordList::Get().Text("song_" + song.id);
            const std::string sub = WordList::Get().Text("song_sub_" + song.id);
            if (needle.empty() || Lower(title).find(needle) != std::string::npos || Lower(sub).find(needle) != std::string::npos) {
                results.push_back(&song);
            }
        }
        scroll = 0;
    }

    void StartEdit(int* value, int minValue, int maxValue) {
        editing = value;
        editText = std::to_string(*value);
        editMin = minValue;
        editMax = maxValue;
    }

    void FinishEdit() {
        if (!editing) return;
        const int v = editText.empty() ? 0 : std::atoi(editText.c_str());
        const int clamped = std::clamp(v, editMin, editMax);
        if (clamped != *editing) dirty = true;
        *editing = clamped;
        editing = nullptr;
    }

    // 数字の欄（◀ 数字 ▶）
    void Number(Rectangle r, int* value, int minValue, int maxValue, const char* suffix = "") {
        const float arrow = 34.0f;
        const Rectangle left{r.x, r.y, arrow, r.height};
        const Rectangle right{r.x + r.width - arrow, r.y, arrow, r.height};
        const Rectangle body{r.x + arrow + 4.0f, r.y, r.width - arrow * 2.0f - 8.0f, r.height};
        const int step = (IsKeyDown(KEY_LEFT_SHIFT) || IsKeyDown(KEY_RIGHT_SHIFT)) ? 10 : 1;
        if (Button(left, "◀")) {
            FinishEdit();
            *value = std::clamp(*value - step, minValue, maxValue);
            dirty = true;
        }
        if (Button(right, "▶")) {
            FinishEdit();
            *value = std::clamp(*value + step, minValue, maxValue);
            dirty = true;
        }
        const bool active = editing == value;
        DrawRectangleRounded(body, 0.2f, 8, WHITE);
        DrawRectangleRoundedLines(body, 0.2f, 8, active ? 2.5f : 1.5f, active ? kRed : kSub);
        const std::string shown = active ? editText + (std::fmod(GetTime(), 1.0) < 0.5 ? "|" : "") : std::to_string(*value) + suffix;
        FitText(shown, body.x + body.width * 0.5f, body.y + (body.height - 22.0f) * 0.5f, body.width - 8.0f, 22.0f, kInk, TextAlign::Center);
        if (Clicked(body)) {
            FinishEdit();
            StartEdit(value, minValue, maxValue);
        }
    }

    void KeyInput() {
        if (editing) {
            for (int c = GetCharPressed(); c > 0; c = GetCharPressed()) {
                if (c >= '0' && c <= '9' && editText.size() < 7) editText += char(c);
            }
            if ((IsKeyPressed(KEY_BACKSPACE) || IsKeyPressedRepeat(KEY_BACKSPACE)) && !editText.empty()) editText.pop_back();
            if (IsKeyPressed(KEY_ENTER) || IsKeyPressed(KEY_KP_ENTER) || IsKeyPressed(KEY_TAB)) FinishEdit();
            if (IsKeyPressed(KEY_ESCAPE)) editing = nullptr;
            return;
        }
        if (pickingSong >= 0) {
            bool changed = false;
            for (int c = GetCharPressed(); c > 0; c = GetCharPressed()) {
                int bytes = 0;
                const char* utf8 = CodepointToUTF8(c, &bytes);
                search.append(utf8, size_t(bytes));
                changed = true;
            }
            if ((IsKeyPressed(KEY_BACKSPACE) || IsKeyPressedRepeat(KEY_BACKSPACE)) && !search.empty()) {
                size_t cut = search.size() - 1;
                while (cut > 0 && (static_cast<unsigned char>(search[cut]) & 0xC0) == 0x80) --cut;
                search.erase(cut);
                changed = true;
            }
            if ((IsKeyDown(KEY_LEFT_CONTROL) || IsKeyDown(KEY_RIGHT_CONTROL)) && IsKeyPressed(KEY_V)) {
                if (const char* clip = GetClipboardText()) search += clip;
                changed = true;
            }
            if (changed) UpdateSearch();
            if (IsKeyPressed(KEY_ESCAPE)) pickingSong = -1;
            return;
        }
        if ((IsKeyDown(KEY_LEFT_CONTROL) || IsKeyDown(KEY_RIGHT_CONTROL)) && IsKeyPressed(KEY_S)) Save();
    }

    // ---- 画面 ----
    void DrawLevels() {
        Text("段位", 24.0f, 76.0f, 22.0f, kSub);
        for (int l = 1; l <= kDaniLevelCount; ++l) {
            // 20 個（五級〜達人と外伝）と下の説明が窓に収まる間隔
            const Rectangle r{20.0f, 104.0f + float(l - 1) * 38.0f, 200.0f, 32.0f};
            const DaniCourse* c = DaniDatabase::Get().Course(l);
            std::string label = DaniName(l);
            if (c) label += c->Playable() ? "  ●" : "  ！";
            if (Button(r, label, true, l == level)) {
                FinishEdit();
                if (dirty) Show("保存していない変更は消えました", false);
                Open(l);
            }
        }
        Text("● お題あり  ！ 曲が見つからない", 20.0f, 104.0f + float(kDaniLevelCount) * 38.0f, 16.0f, kSub);
    }

    void DrawSongs() {
        const float x = 250.0f;
        Text("課題曲", x, 76.0f, 22.0f, kSub);
        for (int i = 0; i < kDaniSongCount; ++i) {
            DaniSong& song = course.songs[size_t(i)];
            const float y = 106.0f + float(i) * 64.0f;
            const Rectangle row{x, y, 1320.0f, 56.0f};
            DrawRectangleRounded(row, 0.2f, 8, kPanel);
            Text(std::to_string(i + 1) + "曲目", x + 14.0f, y + 16.0f, 22.0f, kInk);
            const SongInfo* info = song.tja.empty() ? nullptr : SongDatabase::Get().FindSongByTja(song.tja);
            std::string title = song.tja.empty() ? "（未選択）" : info ? WordList::Get().Text("song_" + info->id) : "見つからない: " + song.tja;
            FitText(title, x + 100.0f, y + 8.0f, 520.0f, 24.0f, info ? kInk : kRed);
            if (info) {
                const int star = info->stars[size_t(song.course)];
                FitText(star > 0 ? "★" + std::to_string(star) : "この難易度の譜面がありません", x + 100.0f, y + 34.0f, 520.0f, 16.0f, star > 0 ? kSub : kRed);
            }
            if (Button({x + 640.0f, y + 10.0f, 130.0f, 36.0f}, "曲をえらぶ")) {
                FinishEdit();
                pickingSong = i;
                pickerReady = false;
                search.clear();
                UpdateSearch();
            }
            // 難易度
            for (int c = 0; c < 5; ++c) {
                const bool has = info && info->stars[size_t(c)] > 0;
                const Rectangle cr{x + 786.0f + float(c) * 93.0f, y + 10.0f, 89.0f, 36.0f};
                if (Button(cr, kCourseLabels[c], true, song.course == c) && song.course != c) {
                    song.course = c;
                    dirty = true;
                }
                if (!has) DrawRectangleRounded(cr, 0.3f, 8, Color{255, 255, 255, 110});
            }
            if (Button({x + 1256.0f, y + 10.0f, 56.0f, 36.0f}, song.hidden ? "？？？" : "表示", true, song.hidden)) {
                song.hidden = !song.hidden;
                dirty = true;
            }
        }
    }

    void DrawGaugeAndExams() {
        const float x = 250.0f;
        float y = 312.0f;
        Text("合格条件", x, y, 22.0f, kSub);
        y += 30.0f;
        // 魂ゲージ
        DrawRectangleRounded({x, y, 1320.0f, 56.0f}, 0.2f, 8, kPanel);
        Text("魂ゲージ", x + 14.0f, y + 16.0f, 22.0f, kInk);
        Text("赤", x + 330.0f, y + 16.0f, 22.0f, kRed);
        Number({x + 360.0f, y + 10.0f, 170.0f, 36.0f}, &course.gaugeRed, 0, 100, " %以上");
        Text("金", x + 560.0f, y + 16.0f, 22.0f, Color{200, 150, 20, 255});
        Number({x + 590.0f, y + 10.0f, 170.0f, 36.0f}, &course.gaugeGold, 0, 100, " %以上");
        y += 70.0f;

        for (int e = 0; e < kDaniExamCount; ++e) {
            DaniExam& exam = course.exams[size_t(e)];
            const float h = exam.type == DaniExamType::None ? 56.0f : 104.0f;
            DrawRectangleRounded({x, y, 1320.0f, h}, 0.12f, 8, kPanel);
            Text("お題 " + std::to_string(e + 1), x + 14.0f, y + 16.0f, 22.0f, kInk);
            // 種類
            for (int t = 0; t < 8; ++t) {
                if (Button({x + 120.0f + float(t) * 112.0f, y + 10.0f, 106.0f, 36.0f}, kExamLabels[t], true, int(exam.type) == t) && int(exam.type) != t) {
                    exam.type = DaniExamType(t);
                    dirty = true;
                }
            }
            if (exam.type == DaniExamType::None) {
                y += h + 10.0f;
                continue;
            }
            // 通し・1曲ごと
            if (Button({x + 1030.0f, y + 10.0f, 130.0f, 36.0f}, "3曲通し", true, exam.total) && !exam.total) {
                exam.total = true;
                dirty = true;
            }
            if (Button({x + 1170.0f, y + 10.0f, 130.0f, 36.0f}, "1曲ごと", true, !exam.total) && exam.total) {
                exam.total = false;
                dirty = true;
            }
            const char* cond = exam.LessThan() ? " 未満" : " 以上";
            const int maxValue = exam.type == DaniExamType::Score ? 99999999 : 99999;
            // 通しは1組、1曲ごとは3組を横に並べる
            const float ry = y + 56.0f;
            for (int s = 0; s < (exam.total ? 1 : kDaniSongCount); ++s) {
                const float gx = x + 20.0f + float(s) * 430.0f;
                Text(exam.total ? "通し" : std::to_string(s + 1) + "曲目", gx, ry + 8.0f, 20.0f, kSub);
                Text("赤", gx + 62.0f, ry + 8.0f, 20.0f, kRed);
                Number({gx + 86.0f, ry, 150.0f, 36.0f}, &exam.red[size_t(s)], 0, maxValue, cond);
                Text("金", gx + 244.0f, ry + 8.0f, 20.0f, Color{200, 150, 20, 255});
                Number({gx + 268.0f, ry, 150.0f, 36.0f}, &exam.gold[size_t(s)], 0, maxValue, cond);
            }
            y += h + 10.0f;
        }
    }

    void DrawPicker() {
        if (pickingSong < 0) return;
        // 窓を開いたクリックを離すまでは、窓の中のクリックを受け付けない
        if (!pickerReady && !MouseDown()) pickerReady = true;
        g_mouseBlocked = !pickerReady;
        DrawRectangle(0, 0, kWidth, kHeight, Color{0, 0, 0, 120});
        const Rectangle box{200.0f, 80.0f, 1200.0f, 740.0f};
        DrawRectangleRounded(box, 0.04f, 8, kBack);
        Text(std::to_string(pickingSong + 1) + "曲目の課題曲をえらぶ", box.x + 24.0f, box.y + 18.0f, 26.0f, kInk);
        const Rectangle field{box.x + 24.0f, box.y + 60.0f, 900.0f, 44.0f};
        DrawRectangleRounded(field, 0.2f, 8, WHITE);
        DrawRectangleRoundedLines(field, 0.2f, 8, 2.0f, kRed);
        const std::string shown = search.empty() ? "曲名で検索（キーボードで入力）" : search + (std::fmod(GetTime(), 1.0) < 0.5 ? "|" : "");
        FitText(shown, field.x + 12.0f, field.y + 10.0f, field.width - 24.0f, 22.0f, search.empty() ? kDim : kInk);
        if (Button({box.x + 950.0f, box.y + 60.0f, 110.0f, 44.0f}, "クリア")) {
            search.clear();
            UpdateSearch();
        }
        if (Button({box.x + 1070.0f, box.y + 60.0f, 110.0f, 44.0f}, "とじる")) pickingSong = -1;

        constexpr int kRows = 14;
        const float wheel = GetMouseWheelMove();
        if (wheel != 0.0f) scroll = std::clamp(scroll - int(wheel) * 3, 0, std::max(0, int(results.size()) - kRows));
        for (int r = 0; r < kRows && scroll + r < int(results.size()); ++r) {
            const SongInfo* song = results[size_t(scroll + r)];
            const Rectangle row{box.x + 24.0f, box.y + 120.0f + float(r) * 42.0f, 1152.0f, 38.0f};
            const bool hover = Hover(row);
            DrawRectangleRounded(row, 0.2f, 8, hover ? Color{255, 226, 140, 255} : kPanel);
            FitText(WordList::Get().Text("song_" + song->id), row.x + 12.0f, row.y + 8.0f, 560.0f, 22.0f, kInk);
            FitText(SongDatabase::TjaRelativePath(*song), row.x + 590.0f, row.y + 11.0f, 420.0f, 16.0f, kSub);
            std::string stars;
            for (int c = 0; c < 5; ++c) {
                static const char* const kShort[] = {"か", "ふ", "む", "鬼", "裏"};
                if (song->stars[size_t(c)] > 0) stars += std::string(kShort[c]) + std::to_string(song->stars[size_t(c)]) + " ";
            }
            FitText(stars, row.x + 1020.0f, row.y + 11.0f, 128.0f, 14.0f, kSub);
            if (hover && MousePressed()) {
                DaniSong& target = course.songs[size_t(pickingSong)];
                target.tja = SongDatabase::TjaRelativePath(*song);
                // 選んだ難易度の譜面がなければ、いちばん上の難易度にする
                if (song->stars[size_t(target.course)] <= 0) {
                    for (int c = 4; c >= 0; --c) {
                        if (song->stars[size_t(c)] > 0) {
                            target.course = c;
                            break;
                        }
                    }
                }
                dirty = true;
                pickingSong = -1;
                return;
            }
        }
        Text(std::to_string(results.size()) + " 曲（ホイールで送る）", box.x + 24.0f, box.y + box.height - 34.0f, 18.0f, kSub);
    }

    void Draw() {
        ClearBackground(kBack);
        DrawRectangle(0, 0, kWidth, 56, kRed);
        Text("GuminTaiko 段位道場 お題の作成", 24.0f, 12.0f, 30.0f, WHITE);
        Text(std::string(DaniName(level)) + (dirty ? "（未保存）" : ""), float(kWidth) - 24.0f, 14.0f, 28.0f, WHITE, TextAlign::Right);
        // 曲をえらぶ窓を開いているあいだ、下の画面のボタンは押せない
        const bool pickerOpen = pickingSong >= 0;
        g_mouseBlocked = pickerOpen;
        DrawLevels();
        DrawSongs();
        DrawGaugeAndExams();
        if (Button({1250.0f, float(kHeight) - 64.0f, 150.0f, 46.0f}, "保存（Ctrl+S）", true, dirty)) {
            FinishEdit();
            Save();
        }
        if (Button({1420.0f, float(kHeight) - 64.0f, 150.0f, 46.0f}, "お題を消す", !course.file.empty())) Delete();
        if (messageTime > 0.0f) FitText(message, 250.0f, float(kHeight) - 52.0f, 980.0f, 20.0f, messageOk ? kGreen : kRed);
        g_mouseBlocked = false;
        DrawPicker();
        g_mouseBlocked = false;
    }
};

} // namespace

int main(int argc, char** argv) {
    // 保護付きのビルド: 証明書と改変の検知（ゲームと同じ）
    if (!AppGuard::CheckAtStartup()) return 1;
    // ゲームのフォルダ（Songs・Dani・Data のあるところ）で動かす
    if (!DirectoryExists("Data")) {
        ChangeDirectory(GetApplicationDirectory());
        if (!DirectoryExists("Data") && DirectoryExists("../Data")) ChangeDirectory("..");
    }
    int level = 6;
    std::string shot;
    float after = 1.5f;
    for (int i = 1; i + 1 < argc; i += 2) {
        const std::string key = argv[i];
        if (key == "--level") level = std::atoi(argv[i + 1]);
        else if (key == "--shot") shot = argv[i + 1];
        else if (key == "--after") after = float(std::atof(argv[i + 1]));
        else if (key == "--click") std::sscanf(argv[i + 1], "%f,%f@%f", &g_testClick.pos.x, &g_testClick.pos.y, &g_testClick.time);
    }

    SetTraceLogLevel(LOG_WARNING);
    SetConfigFlags(FLAG_MSAA_4X_HINT | FLAG_VSYNC_HINT);
    InitWindow(kWidth, kHeight, "GuminTaiko 段位道場 お題の作成");
    SetTargetFPS(60);
    SetExitKey(KEY_NULL);

    App app;
    app.Open(level);
    float time = 0.0f;
    while (!WindowShouldClose()) {
        const float dt = GetFrameTime();
        time += std::min(dt, 0.1f);   // 曲の読み込みで長くなった最初のフレームで、確認用の時刻が飛ばないように
        app.messageTime = std::max(0.0f, app.messageTime - dt);
        if (g_testClick.time >= 0.0f && time >= g_testClick.time) ++g_testClick.frames;
        app.KeyInput();
        BeginDrawing();
        app.Draw();
        EndDrawing();
        if (!shot.empty() && time >= after) {
            TakeScreenshot(shot.c_str());
            break;
        }
    }
    GameFont::Get().Unload();
    CloseWindow();
    return 0;
}
