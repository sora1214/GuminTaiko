// GuminLicense: GuminTaiko の証明書（license.cert）を作るアプリ（開発の PC だけで使う。秘密鍵がいる）
//   GuminTaiko を別の PC に移したときに、その PC 用の証明書を作る。
//     1. 新しい PC で GuminTaiko を起動する → エラーの画面に「この PC の ID」が出る（クリップボードにも入る）
//     2. この PC（秘密鍵 keys\gumin_private.key がある PC）で GuminLicense を開き、その ID を貼り付けて「作成」
//     3. できた license.cert を、新しい PC の GuminTaiko のフォルダに入れる
//   秘密鍵はこのアプリに入れていない（入れると、誰でもどの PC 用の証明書も作れてしまうため）
//
//   操作: 欄をクリックして入力（Ctrl+V で貼り付け、Tab で次の欄）、Enter または「作成」ボタンで作る
//   確認用: GuminLicense [--machine ID] [--licensee 名前] [--expires YYYY-MM-DD] [--out パス] [--create 1]
//                        [--shot 出力.png --after 秒]
#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <string>
#include <system_error>
#include <vector>

#include "AppGuard.hpp"
#include "GameFont.hpp"
#include "GuardCrypto.hpp"
#include "ProcessUtil.hpp"
#include "raylib.h"

namespace fs = std::filesystem;

namespace {

constexpr int kWidth = 1000;
constexpr int kHeight = 620;
constexpr const char* kKeyPath = "keys/gumin_private.key";
constexpr const char* kAppFolder = "Z:\\GuminTaikoApp";

const Color kBack{250, 236, 210, 255};
const Color kInk{52, 26, 18, 255};
const Color kSub{120, 90, 60, 255};
const Color kPanel{255, 250, 238, 255};
const Color kGold{255, 206, 64, 255};
const Color kRed{236, 72, 48, 255};
const Color kGreen{40, 150, 70, 255};

enum FieldId { kMachine, kLicensee, kExpires, kOutput, kFieldCount };

struct Field {
    const char* label;
    const char* hint;
    std::string text;
};

struct Button {
    Rectangle rect;
    const char* label;
};

void Text(const std::string& text, float x, float y, float size, Color color, TextAlign align = TextAlign::Left) {
    GameFont::Get().Draw(text.c_str(), x, y, size, color, align);
}

std::vector<std::string> Codepoints(const std::string& s) {
    std::vector<std::string> out;
    for (size_t i = 0; i < s.size();) {
        size_t n = 1;
        const unsigned char c = static_cast<unsigned char>(s[i]);
        if (c >= 0xF0) n = 4;
        else if (c >= 0xE0) n = 3;
        else if (c >= 0xC0) n = 2;
        out.push_back(s.substr(i, n));
        i += n;
    }
    return out;
}

enum class Elide { Left, Right };   // 収まらないとき、どちら側を「…」にするか

// 枠（幅 width）に収める: まず文字を小さくし（minSize まで）、それでも入らなければ端を「…」にして縮める。描いた幅を返す
float FitText(const std::string& text, float x, float centerY, float width, float size, float minSize, Color color,
              TextAlign align = TextAlign::Left, Elide elide = Elide::Right) {
    if (text.empty()) return 0.0f;
    GameFont& font = GameFont::Get();
    float w = font.Measure(text.c_str(), size).x;
    if (w > width) {
        size = std::max(minSize, size * width / w);
        w = font.Measure(text.c_str(), size).x;
        // 大きさと幅はきっちり比例しないので、入るまで少しずつ小さくする
        while (w > width && size > minSize) {
            size = std::max(minSize, size - 0.5f);
            w = font.Measure(text.c_str(), size).x;
        }
    }
    std::string shown = text;
    if (w > width) {
        std::vector<std::string> cps = Codepoints(text);
        while (cps.size() > 1) {
            if (elide == Elide::Left) cps.erase(cps.begin());
            else cps.pop_back();
            std::string body;
            for (const std::string& cp : cps) body += cp;
            shown = elide == Elide::Left ? "…" + body : body + "…";
            w = font.Measure(shown.c_str(), size).x;
            if (w <= width) break;
        }
    }
    Text(shown, x, centerY - size * 0.5f, size, color, align);
    return w;
}

Rectangle FieldRect(int index) { return Rectangle{220.0f, 110.0f + float(index) * 90.0f, 520.0f, 50.0f}; }

bool DrawButton(const Button& b, bool enabled = true) {
    const bool hover = enabled && CheckCollisionPointRec(GetMousePosition(), b.rect);
    DrawRectangleRounded(b.rect, 0.35f, 8, !enabled ? Color{220, 210, 190, 255} : hover ? kGold : Color{255, 226, 140, 255});
    DrawRectangleRoundedLines(b.rect, 0.35f, 8, 2.0f, kInk);
    FitText(b.label, b.rect.x + b.rect.width * 0.5f, b.rect.y + b.rect.height * 0.5f, b.rect.width - 20.0f, 22.0f, 14.0f,
            enabled ? kInk : kSub, TextAlign::Center);
    return hover && IsMouseButtonPressed(MOUSE_BUTTON_LEFT);
}

std::string Trim(std::string s) {
    while (!s.empty() && std::isspace(static_cast<unsigned char>(s.back()))) s.pop_back();
    size_t start = 0;
    while (start < s.size() && std::isspace(static_cast<unsigned char>(s[start]))) ++start;
    return s.substr(start);
}

// UTF-8 の最後の1文字を消す
void PopCodepoint(std::string& s) {
    while (!s.empty()) {
        const unsigned char c = static_cast<unsigned char>(s.back());
        s.pop_back();
        if ((c & 0xC0) != 0x80) break;
    }
}

bool IsDate(const std::string& s) {
    if (s.size() != 10 || s[4] != '-' || s[7] != '-') return false;
    for (size_t i = 0; i < s.size(); ++i) {
        if (i != 4 && i != 7 && !std::isdigit(static_cast<unsigned char>(s[i]))) return false;
    }
    return true;
}

struct App {
    Field fields[kFieldCount] = {
        {"PC の ID", "新しい PC のエラー画面に出る ID を貼り付け", ""},
        {"名前", "証明書に書く持ち主の名前", ""},
        {"期限", "空なら無期限（YYYY-MM-DD で期限つき）", ""},
        {"保存先", "作った license.cert を書く場所", ""},
    };
    int focus = kMachine;
    std::string message;
    bool messageOk = false;

    void Show(const std::string& text, bool ok) {
        message = text;
        messageOk = ok;
    }

    // 証明書を作って保存する
    void Create() {
        std::string machine = Trim(fields[kMachine].text);
        std::transform(machine.begin(), machine.end(), machine.begin(), [](unsigned char c) { return char(std::tolower(c)); });
        if (!AppGuard::IsMachineId(machine)) {
            Show("PC の ID の形がちがいます（xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx）", false);
            focus = kMachine;
            return;
        }
        std::string expires = Trim(fields[kExpires].text);
        if (expires.empty()) expires = "never";
        if (expires != "never" && !IsDate(expires)) {
            Show("期限は YYYY-MM-DD の形で書いてください（空なら無期限）", false);
            focus = kExpires;
            return;
        }
        std::string licensee = Trim(fields[kLicensee].text);
        licensee.erase(std::remove(licensee.begin(), licensee.end(), '\n'), licensee.end());
        if (licensee.empty()) licensee = "owner";

        std::ifstream keyFile(kKeyPath, std::ios::binary);
        if (!keyFile) {
            Show("秘密鍵（keys\\gumin_private.key）が見つかりません。鍵のある PC で開いてください", false);
            return;
        }
        const std::vector<uint8_t> key((std::istreambuf_iterator<char>(keyFile)), std::istreambuf_iterator<char>());
        std::string cert;
        if (!AppGuard::IssueLicense(key, licensee, machine, expires, cert)) {
            Show("証明書を作れません（秘密鍵が壊れているかもしれません）", false);
            return;
        }

        fs::path out = fs::u8path(Trim(fields[kOutput].text));
        std::error_code ec;
        if (out.empty()) out = fs::u8path(AppGuard::kLicenseFile);
        if (fs::is_directory(out, ec)) out /= AppGuard::kLicenseFile;
        if (out.has_parent_path()) fs::create_directories(out.parent_path(), ec);
        if (fs::exists(out, ec)) fs::permissions(out, fs::perms::owner_write, fs::perm_options::add, ec);   // 読み取り専用を外す
        std::ofstream ofs(out, std::ios::binary | std::ios::trunc);
        if (!ofs || !(ofs << cert)) {
            Show("保存できません: " + out.u8string(), false);
            return;
        }
        fields[kOutput].text = out.u8string();
        Show("作成しました: " + out.u8string() + "（" + machine + "）", true);
    }

    void Input() {
        // 欄をクリック
        for (int i = 0; i < kFieldCount; ++i) {
            if (IsMouseButtonPressed(MOUSE_BUTTON_LEFT) && CheckCollisionPointRec(GetMousePosition(), FieldRect(i))) focus = i;
        }
        if (IsKeyPressed(KEY_TAB)) focus = (focus + ((IsKeyDown(KEY_LEFT_SHIFT) || IsKeyDown(KEY_RIGHT_SHIFT)) ? kFieldCount - 1 : 1)) % kFieldCount;
        std::string& text = fields[focus].text;
        for (int c = GetCharPressed(); c > 0; c = GetCharPressed()) {
            int bytes = 0;
            const char* utf8 = CodepointToUTF8(c, &bytes);
            text.append(utf8, size_t(bytes));
        }
        if (IsKeyPressed(KEY_BACKSPACE) || IsKeyPressedRepeat(KEY_BACKSPACE)) PopCodepoint(text);
        if ((IsKeyDown(KEY_LEFT_CONTROL) || IsKeyDown(KEY_RIGHT_CONTROL)) && IsKeyPressed(KEY_V)) {
            if (const char* clip = GetClipboardText()) text += Trim(clip);
        }
        if (IsKeyPressed(KEY_ENTER) || IsKeyPressed(KEY_KP_ENTER)) Create();
    }

    void Draw() {
        ClearBackground(kBack);
        DrawRectangle(0, 0, kWidth, 60, kRed);
        FitText("GuminTaiko ライセンス作成", 24.0f, 30.0f, float(kWidth) - 48.0f, 30.0f, 20.0f, WHITE);
        FitText("別の PC に GuminTaiko を移したときに、その PC 用の証明書（license.cert）を作ります", 24.0f, 84.0f,
                float(kWidth) - 48.0f, 20.0f, 14.0f, kSub);

        for (int i = 0; i < kFieldCount; ++i) {
            const Rectangle r = FieldRect(i);
            FitText(fields[i].label, 40.0f, r.y + r.height * 0.5f, 160.0f, 26.0f, 16.0f, kInk);
            DrawRectangleRounded(r, 0.2f, 8, kPanel);
            DrawRectangleRoundedLines(r, 0.2f, 8, i == focus ? 3.0f : 1.5f, i == focus ? kRed : kSub);
            // 入力した文字は枠に収める（長いときは小さくし、それでも入らなければ左を「…」にして右端＝入力しているところを見せる）
            constexpr float kPad = 14.0f;
            const float inner = r.width - kPad * 2.0f - 6.0f;   // カーソルのぶんをあける
            const float midY = r.y + r.height * 0.5f;
            const std::string& t = fields[i].text;
            float drawn = 0.0f;
            if (!t.empty()) drawn = FitText(t, r.x + kPad, midY, inner, 24.0f, 16.0f, kInk, TextAlign::Left, Elide::Left);
            else FitText(fields[i].hint, r.x + kPad, midY, inner, 20.0f, 14.0f, Color{kSub.r, kSub.g, kSub.b, 150});
            if (i == focus && std::fmod(GetTime(), 1.0) < 0.5) {
                DrawRectangle(int(r.x + kPad + drawn) + 2, int(r.y + 10.0f), 2, int(r.height - 20.0f), kInk);
            }
        }

        // 欄の横のボタン
        const Button self{{760.0f, FieldRect(kMachine).y, 100.0f, 50.0f}, "この PC"};
        const Button paste{{870.0f, FieldRect(kMachine).y, 110.0f, 50.0f}, "貼り付け"};
        const Button never{{760.0f, FieldRect(kExpires).y, 120.0f, 50.0f}, "無期限"};
        const Button desktop{{760.0f, FieldRect(kOutput).y, 130.0f, 50.0f}, "デスクトップ"};
        const Button appDir{{898.0f, FieldRect(kOutput).y, 82.0f, 50.0f}, "アプリ"};
        if (DrawButton(self)) fields[kMachine].text = GuardCrypto::MachineId();
        if (DrawButton(paste)) {
            if (const char* clip = GetClipboardText()) fields[kMachine].text = Trim(clip);
        }
        if (DrawButton(never)) fields[kExpires].text.clear();
        if (DrawButton(desktop)) fields[kOutput].text = (fs::u8path(DesktopFolder()) / AppGuard::kLicenseFile).u8string();
        if (DrawButton(appDir)) fields[kOutput].text = (fs::path(kAppFolder) / AppGuard::kLicenseFile).u8string();

        const Button create{{380.0f, 470.0f, 240.0f, 60.0f}, "作成"};
        if (DrawButton(create)) Create();
        if (!message.empty()) {
            FitText(message, float(kWidth) * 0.5f, 560.0f, float(kWidth) - 48.0f, 22.0f, 15.0f, messageOk ? kGreen : kRed,
                    TextAlign::Center, Elide::Left);
        }
        FitText("「アプリ」: この PC の Z:\\GuminTaikoApp に書く  「この PC」: この PC の ID を入れる", 24.0f, float(kHeight) - 22.0f,
                float(kWidth) - 48.0f, 18.0f, 14.0f, kSub);
    }
};

} // namespace

int main(int argc, char** argv) {
    // 秘密鍵（keys）とフォント（Data）のあるゲームのフォルダで動かす
    if (!DirectoryExists("keys") || !DirectoryExists("Data")) {
        ChangeDirectory(GetApplicationDirectory());
        if (!DirectoryExists("keys") && DirectoryExists("../keys")) ChangeDirectory("..");
    }

    App app;
    const char* user = std::getenv("USERNAME");
    app.fields[kLicensee].text = user ? user : "owner";
    app.fields[kOutput].text = (fs::u8path(DesktopFolder()) / AppGuard::kLicenseFile).u8string();
    std::string shot;
    float after = 1.0f;
    bool autoCreate = false;
    for (int i = 1; i + 1 < argc; i += 2) {
        const std::string key = argv[i], value = argv[i + 1];
        if (key == "--machine") app.fields[kMachine].text = value;
        else if (key == "--licensee") app.fields[kLicensee].text = value;
        else if (key == "--expires") app.fields[kExpires].text = value;
        else if (key == "--out") app.fields[kOutput].text = value;
        else if (key == "--create") autoCreate = std::atoi(value.c_str()) != 0;
        else if (key == "--shot") shot = value;
        else if (key == "--after") after = float(std::atof(value.c_str()));
    }

    SetTraceLogLevel(LOG_WARNING);
    SetConfigFlags(FLAG_MSAA_4X_HINT | FLAG_VSYNC_HINT);
    InitWindow(kWidth, kHeight, "GuminTaiko ライセンス作成");
    SetTargetFPS(60);
    SetExitKey(KEY_NULL);
    if (autoCreate) app.Create();

    float time = 0.0f;
    while (!WindowShouldClose()) {
        time += GetFrameTime();
        app.Input();
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
