// GuminLauncher: GuminTaiko のランチャー（配布して遊ぶためのアプリ）
//   ・遊ぶ: 画面（全画面・ウィンドウ）・描く速さ・垂直同期を決めて、ゲームを起動する（設定は Backup\launcher.ini に残す）
//   ・ファイル確認: 証明書（license.cert。この PC 用）と、プログラム・素材が書き換えられていないか（manifest.sig）を確かめる
//   ・ライセンス: この PC の ID をコピーする → 配布する人に送る → もらった license.cert を取り込む
//   ・曲の追加: 曲のフォルダ・.tja・.zip を、この窓にドラッグ＆ドロップ（または「曲の追加」）。Songs\創作譜面 に入る
//   ・着せかえ・段位道場のお題のアプリや、Songs・Backup のフォルダを開く
//   確認用: GuminLauncher [--shot 出力.png --after 秒] [--check 1] [--settings 1]
#include <algorithm>
#include <atomic>
#include <cctype>
#include <cmath>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <map>
#include <set>
#include <sstream>
#include <mutex>
#include <string>
#include <system_error>
#include <thread>
#include <vector>

#include "AppGuard.hpp"
#include "GameFont.hpp"
#include "GuardCrypto.hpp"
#include "raylib.h"
#include "gumin_launcher_win.hpp"

namespace fs = std::filesystem;

namespace {

constexpr int kWidth = 1280;
constexpr int kHeight = 720;
constexpr const char* kSettingsPath = "Backup/launcher.ini";
constexpr const char* kSongsFolder = "Songs";
constexpr const char* kCustomFolder = "創作譜面";   // 一覧に出る曲の置き場（本家の曲は songs_index にあるものだけが出る）

const Color kBack{250, 236, 210, 255};
const Color kInk{52, 26, 18, 255};
const Color kSub{120, 90, 60, 255};
const Color kPanel{255, 250, 238, 255};
const Color kGold{255, 206, 64, 255};
const Color kRed{236, 72, 48, 255};
const Color kGreen{40, 150, 70, 255};

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

enum class Elide { Left, Right };

// 枠（幅 width）に収める: まず文字を小さくし（minSize まで）、それでも入らなければ端を「…」にして縮める。描いた幅を返す
float FitText(const std::string& text, float x, float centerY, float width, float size, float minSize, Color color,
              TextAlign align = TextAlign::Left, Elide elide = Elide::Right) {
    if (text.empty()) return 0.0f;
    GameFont& font = GameFont::Get();
    float w = font.Measure(text.c_str(), size).x;
    if (w > width) {
        size = std::max(minSize, size * width / w);
        w = font.Measure(text.c_str(), size).x;
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
    GameFont::Get().Draw(shown.c_str(), x, centerY - size * 0.5f, size, color, align);
    return w;
}

struct Button {
    Rectangle rect;
    std::string label;
};

bool DrawButton(const Button& b, bool enabled = true, bool selected = false, Color fill = Color{255, 226, 140, 255}) {
    const bool hover = enabled && CheckCollisionPointRec(GetMousePosition(), b.rect);
    Color back = !enabled ? Color{220, 210, 190, 255} : selected ? kRed : hover ? kGold : fill;
    DrawRectangleRounded(b.rect, 0.35f, 8, back);
    DrawRectangleRoundedLines(b.rect, 0.35f, 8, 2.0f, kInk);
    FitText(b.label, b.rect.x + b.rect.width * 0.5f, b.rect.y + b.rect.height * 0.5f, b.rect.width - 20.0f, 22.0f, 13.0f,
            !enabled ? kSub : selected ? WHITE : kInk, TextAlign::Center);
    return hover && IsMouseButtonPressed(MOUSE_BUTTON_LEFT);
}

// ---------------------------------------------------------------------------
// 設定
// ---------------------------------------------------------------------------
struct Settings {
    bool windowed = false;
    int fps = 120;      // 演奏中の描く速さ（--play-fps）
    bool vsync = true;  // 垂直同期（--vsync）
    std::string updateUrl;   // 更新元（空なら update_url.txt）
};

constexpr int kFpsChoices[] = {60, 120, 144, 240};

std::string TrimmedValue(std::string s) {
    while (!s.empty() && std::isspace(static_cast<unsigned char>(s.back()))) s.pop_back();
    size_t start = 0;
    while (start < s.size() && std::isspace(static_cast<unsigned char>(s[start]))) ++start;
    return s.substr(start);
}

Settings LoadSettings() {
    Settings s;
    std::ifstream ifs(kSettingsPath);
    std::string line;
    while (std::getline(ifs, line)) {
        const size_t eq = line.find('=');
        if (eq == std::string::npos) continue;
        const std::string key = line.substr(0, eq);
        const int value = std::atoi(line.c_str() + eq + 1);
        if (key == "windowed") s.windowed = value != 0;
        else if (key == "fps" && value > 0) s.fps = value;
        else if (key == "vsync") s.vsync = value != 0;
        else if (key == "update_url") s.updateUrl = TrimmedValue(line.substr(eq + 1));
    }
    return s;
}

void SaveSettings(const Settings& s) {
    std::error_code ec;
    fs::create_directories("Backup", ec);
    std::ofstream ofs(kSettingsPath, std::ios::trunc);
    if (!ofs) return;
    ofs << "windowed=" << (s.windowed ? 1 : 0) << "\nfps=" << s.fps << "\nvsync=" << (s.vsync ? 1 : 0) << '\n';
    if (!s.updateUrl.empty()) ofs << "update_url=" << s.updateUrl << '\n';
}

// ---------------------------------------------------------------------------
// 曲の追加（Songs\創作譜面 に入れる）
// ---------------------------------------------------------------------------
fs::path UniqueDir(const fs::path& base, const std::wstring& name) {
    std::error_code ec;
    fs::path dir = base / name;
    for (int n = 2; fs::exists(dir, ec); ++n) dir = base / (name + L" (" + std::to_wstring(n) + L")");
    return dir;
}

std::wstring SafeName(std::wstring name) {
    for (wchar_t& c : name) {
        if (wcschr(L"\\/:*?\"<>|", c)) c = L'_';
    }
    while (!name.empty() && (name.back() == L' ' || name.back() == L'.')) name.pop_back();
    return name.empty() ? L"曲" : name;
}

// .tja の WAVE: に書かれた音源の名前（同じフォルダにあるもの）
fs::path WaveOf(const fs::path& tja) {
    std::ifstream ifs(tja, std::ios::binary);
    std::string line;
    while (std::getline(ifs, line)) {
        if (line.compare(0, 5, "WAVE:") == 0 || line.compare(0, 5, "wave:") == 0) {
            while (!line.empty() && (line.back() == '\r' || line.back() == '\n' || line.back() == ' ')) line.pop_back();
            std::string value = line.substr(5);
            while (!value.empty() && value.front() == ' ') value.erase(value.begin());
            return value.empty() ? fs::path() : fs::u8path(LauncherWin::BytesToUtf8(value));
        }
    }
    return {};
}

// 1つ追加する。入れたフォルダの名前を返す（できなければ空）
std::wstring AddSong(const fs::path& source) {
    std::error_code ec;
    const fs::path base = fs::path(kSongsFolder) / kCustomFolder;
    fs::create_directories(base, ec);

    if (fs::is_directory(source, ec)) {
        const fs::path dest = UniqueDir(base, SafeName(source.filename().wstring()));
        fs::copy(source, dest, fs::copy_options::recursive, ec);
        return ec ? std::wstring() : dest.filename().wstring();
    }
    std::wstring ext = source.extension().wstring();
    std::transform(ext.begin(), ext.end(), ext.begin(), [](wchar_t c) { return wchar_t(std::towlower(c)); });
    if (ext == L".tja") {
        // .tja と、WAVE: の音源（と同じ名前の画像）を、曲の名前のフォルダに入れる
        const fs::path dest = UniqueDir(base, SafeName(source.stem().wstring()));
        fs::create_directories(dest, ec);
        fs::copy_file(source, dest / source.filename(), ec);
        if (ec) return {};
        const fs::path wave = WaveOf(source);
        if (!wave.empty()) fs::copy_file(source.parent_path() / wave, dest / wave, fs::copy_options::skip_existing, ec);
        for (const wchar_t* image : {L".png", L".jpg", L".jpeg"}) {
            fs::path candidate = source;
            candidate.replace_extension(image);
            if (fs::exists(candidate, ec)) fs::copy_file(candidate, dest / candidate.filename(), fs::copy_options::skip_existing, ec);
        }
        return dest.filename().wstring();
    }
    if (ext == L".zip") {
        // Windows の tar（zip も開ける）で展開する
        const fs::path dest = UniqueDir(base, SafeName(source.stem().wstring()));
        fs::create_directories(dest, ec);
        const bool ok = LauncherWin::RunHidden("tar.exe -xf \"" + source.u8string() + "\" -C \"" + dest.u8string() + "\"");
        if (!ok) {
            fs::remove_all(dest, ec);
            return {};
        }
        return dest.filename().wstring();
    }
    return {};
}

// ---------------------------------------------------------------------------
// アプリ
// ---------------------------------------------------------------------------
// ファイルの SHA-256（16進）
std::string Sha256File(const fs::path& path) {
    std::ifstream ifs(path, std::ios::binary);
    if (!ifs) return {};
    GuardCrypto::Sha256 sha;
    std::vector<char> buffer(1 << 20);
    while (ifs) {
        ifs.read(buffer.data(), std::streamsize(buffer.size()));
        const std::streamsize got = ifs.gcount();
        if (got > 0) sha.Update(buffer.data(), size_t(got));
    }
    const GuardCrypto::Digest digest = sha.Finish();
    return GuardCrypto::ToHex(digest.data(), digest.size());
}

// URL に入れるパス（UTF-8 の1バイトずつ %XX。/ と英数字などはそのまま）
std::string PercentEncode(const std::string& path) {
    std::string out;
    char buf[4];
    for (const unsigned char c : path) {
        if (std::isalnum(c) || c == '-' || c == '.' || c == '_' || c == '~' || c == '/') {
            out += char(c);
        } else {
            std::snprintf(buf, sizeof(buf), "%%%02X", c);
            out += buf;
        }
    }
    return out;
}

std::string TrimText(std::string s) {
    while (!s.empty() && std::isspace(static_cast<unsigned char>(s.back()))) s.pop_back();
    size_t start = 0;
    while (start < s.size() && std::isspace(static_cast<unsigned char>(s[start]))) ++start;
    return s.substr(start);
}

// 大きさの文字（1MB 未満は KB）
std::string FormatSize(uint64_t bytes) {
    char buf[32];
    if (bytes >= 1024ull * 1024ull) std::snprintf(buf, sizeof(buf), "%.1f MB", double(bytes) / (1024.0 * 1024.0));
    else std::snprintf(buf, sizeof(buf), "%.0f KB", double(bytes) / 1024.0);
    return buf;
}

// 「github:ユーザー/リポジトリ[@ブランチ]」を、GitHub の raw の URL（リポジトリの update フォルダ）にする。それ以外はそのまま
std::string ResolveSource(std::string source) {
    if (source.rfind("github:", 0) != 0) return source;
    source = source.substr(7);
    std::string branch = "main";
    const size_t at = source.find('@');
    if (at != std::string::npos) {
        branch = source.substr(at + 1);
        source = source.substr(0, at);
    }
    return "https://raw.githubusercontent.com/" + source + "/" + branch + "/update";
}

bool IsUrl(const std::string& s) { return s.rfind("http://", 0) == 0 || s.rfind("https://", 0) == 0; }

struct App {
    Settings settings;
    fs::path appDir;
    std::string machineId;

    // ファイル確認（別のスレッドで走らせる。2 万ファイルあるので数秒かかる）
    enum class Check { Idle, Running, Ok, Bad };
    std::atomic<Check> check{Check::Idle};
    std::mutex mutex;
    std::string problem;       // 確認の結果（問題の理由）
    bool licenseProblem = false;
    std::thread worker;

    std::string message;
    bool messageOk = true;
    float messageTime = 0.0f;
    bool launching = false;

    void Show(const std::string& text, bool ok) {
        message = text;
        messageOk = ok;
        messageTime = float(GetTime());
    }

    void StartCheck() {
        if (check == Check::Running) return;
        if (worker.joinable()) worker.join();
        check = Check::Running;
        worker = std::thread([this] {
            std::string reason;
            const bool ok = AppGuard::Verify(appDir, reason, true);
            std::lock_guard<std::mutex> lock(mutex);
            problem = reason;
            // 証明書の問題か（そうなら、この PC の ID を送って証明書をもらう）
            licenseProblem = !ok && (reason.find("証明書") != std::string::npos);
            check = ok ? Check::Ok : Check::Bad;
        });
    }

    // ---------------------------------------------------------------------
    // アップデート: 更新元（URL かフォルダ）の update.idx（署名つきの目録）と、いまのファイルをくらべて、
    // 違うファイルだけを取ってきて入れ替える。取ってきたファイルは SHA-256 で確かめ、入れ替えたあと manifest.sig で全体を確かめる
    // ---------------------------------------------------------------------
    enum class Upd { Idle, NoSource, Checking, UpToDate, Available, Downloading, Applying, Done, Error };
    struct UpdFile {
        std::string path;
        uint64_t size = 0;
        std::string hash;
    };
    std::atomic<Upd> upd{Upd::Idle};
    std::string updateSource;               // 更新元（http(s):// の URL か、フォルダ）
    std::string updText;                    // 状態の文（mutex で守る）
    std::string updRelease;                 // 更新元の版
    std::vector<UpdFile> updTodo;
    std::vector<std::string> updRemove;
    uint64_t updTotal = 0;                  // 取ってくる大きさ
    std::atomic<uint64_t> updBytes{0};
    std::atomic<bool> updCancel{false};
    std::thread updWorker;
    bool relaunch = false;                  // ランチャー自身が新しくなったので、終わったら開き直す
    bool autoUpdate = false;                // 確認用（--update 1）: 確認から適用まで自動で行って、結果をログに書く

    void Log(const std::string& text) {
        std::error_code ec;
        fs::create_directories(appDir / "Backup", ec);
        std::ofstream ofs(appDir / "Backup" / "launcher.log", std::ios::app);
        ofs << text << '\n';
    }

    void SetUpdText(const std::string& text) {
        std::lock_guard<std::mutex> lock(mutex);
        updText = text;
    }

    void LoadUpdateSource() {
        // Backup\launcher.ini の update_url= が先。なければ update_url.txt（アプリのフォルダ。配布する人が入れておく）
        updateSource = settings.updateUrl;
        std::string line;
        if (updateSource.empty()) {
            std::ifstream txt(appDir / "update_url.txt");
            if (std::getline(txt, line)) updateSource = TrimText(line);
        }
        updateSource = ResolveSource(updateSource);
        while (!updateSource.empty() && (updateSource.back() == '/' || updateSource.back() == '\\')) updateSource.pop_back();
        if (updateSource.empty()) {
            upd = Upd::NoSource;
            SetUpdText("更新元が決まっていません");
        }
    }

    // 更新元から1つ取ってくる（URL ならダウンロード、フォルダならコピー）
    bool Fetch(const std::string& relative, const fs::path& dest, std::string& error) {
        std::error_code ec;
        fs::create_directories(dest.parent_path(), ec);
        if (IsUrl(updateSource)) return LauncherWin::Download(updateSource + "/" + PercentEncode(relative), dest.u8string(), &updBytes, &updCancel, error);
        const fs::path source = fs::u8path(updateSource) / fs::u8path(relative);
        if (!fs::exists(source, ec)) {
            error = "更新元にありません: " + relative;
            return false;
        }
        const uint64_t size = fs::file_size(source, ec);
        fs::copy_file(source, dest, fs::copy_options::overwrite_existing, ec);
        if (ec) {
            error = "コピーできません: " + relative + "（" + ec.message() + "）";
            return false;
        }
        updBytes += size;
        return true;
    }

    void StartUpdateCheck() {
        if (updateSource.empty() || upd == Upd::Checking || upd == Upd::Downloading || upd == Upd::Applying) return;
        if (updWorker.joinable()) updWorker.join();
        upd = Upd::Checking;
        SetUpdText("更新を確認しています…");
        updWorker = std::thread([this] { CheckUpdate(); });
    }

    void CheckUpdate() {
        std::string error;
        const fs::path tmp = appDir / "Backup" / "update";
        const fs::path index = tmp / "update.idx";
        std::error_code ec;
        fs::remove(index, ec);
        if (!Fetch("update.idx", index, error)) {
            // 404: GitHub のリポジトリが非公開（raw は認証なしでは読めない）か、アップデートをまだ上げていない
            SetUpdText(error.find("404") != std::string::npos ? "更新元が見つかりません（GitHub のリポジトリが非公開か、アップデートが上がっていません）"
                                                              : "更新元につながりません（通信を確かめてください）");
            Log("update check: " + error);
            upd = Upd::Error;
            return;
        }
        std::ifstream ifs(index, std::ios::binary);
        std::stringstream ss;
        ss << ifs.rdbuf();
        std::string body;
        if (!AppGuard::VerifySignedText(ss.str(), body)) {
            SetUpdText("更新の目録の署名が正しくありません（使いません）");
            Log("update check: bad signature");
            upd = Upd::Error;
            return;
        }
        std::vector<UpdFile> remote;
        std::string release, product;
        std::istringstream in(body);
        std::string line;
        while (std::getline(in, line)) {
            if (!line.empty() && line.back() == '\r') line.pop_back();
            if (line.compare(0, 8, "product=") == 0) product = line.substr(8);
            else if (line.compare(0, 8, "release=") == 0) release = line.substr(8);
            else if (line.compare(0, 5, "file=") == 0) {
                std::istringstream fields(line.substr(5));
                std::string size, hash, path;
                std::getline(fields, size, '|');
                std::getline(fields, hash, '|');
                std::getline(fields, path);
                if (!path.empty() && !hash.empty() && path.find("..") == std::string::npos && path[0] != '/' && path.find(':') == std::string::npos) {
                    remote.push_back({path, std::strtoull(size.c_str(), nullptr, 10), hash});
                }
            }
        }
        if (product != AppGuard::kProduct || remote.empty()) {
            SetUpdText("更新の目録がこのゲーム用のものではありません");
            upd = Upd::Error;
            return;
        }
        // いまのファイルとくらべる（大きさが同じものだけ、中身のハッシュも見る）
        std::vector<UpdFile> todo;
        std::set<std::string> remotePaths;
        uint64_t total = 0;
        for (const UpdFile& file : remote) {
            remotePaths.insert(file.path);
            const fs::path local = appDir / fs::u8path(file.path);
            const uint64_t size = fs::exists(local, ec) ? fs::file_size(local, ec) : uint64_t(-1);
            if (size != file.size || Sha256File(local) != file.hash) {
                todo.push_back(file);
                total += file.size;
            }
        }
        // なくなったファイル（守る対象で、更新元の目録にないもの）
        std::vector<std::string> removed;
        for (const std::string& local : AppGuard::ProtectedFiles(appDir)) {
            if (!remotePaths.count(local)) removed.push_back(local);
        }
        {
            std::lock_guard<std::mutex> lock(mutex);
            updTodo = todo;
            updRemove = removed;
            updTotal = total;
            updRelease = release;
        }
        if (todo.empty() && removed.empty()) {
            SetUpdText("最新です（版 " + release + "）");
            upd = Upd::UpToDate;
        } else {
            SetUpdText("更新があります（版 " + release + "、" + std::to_string(todo.size()) + " ファイル、" + FormatSize(total) + "）");
            upd = Upd::Available;
        }
        Log("update check: " + std::to_string(todo.size()) + " files, " + std::to_string(removed.size()) + " removed, release " + release);
    }

    void StartUpdateApply() {
        if (upd != Upd::Available) return;
        if (LauncherWin::IsProgramRunning("GuminTaiko.exe") || LauncherWin::IsProgramRunning("GuminDressUp.exe") ||
            LauncherWin::IsProgramRunning("GuminDaniEditor.exe")) {
            Show("ゲームと着せかえ・お題のアプリを終了してから、アップデートしてください", false);
            return;
        }
        if (updWorker.joinable()) updWorker.join();
        upd = Upd::Downloading;
        updBytes = 0;
        updCancel = false;
        updWorker = std::thread([this] { ApplyUpdate(); });
    }

    void ApplyUpdate() {
        std::vector<UpdFile> todo;
        std::vector<std::string> removed;
        {
            std::lock_guard<std::mutex> lock(mutex);
            todo = updTodo;
            removed = updRemove;
        }
        const fs::path stage = appDir / "Backup" / "update" / "files";
        std::error_code ec;
        std::string error;
        // 1. 取ってきて、ハッシュを確かめる
        for (const UpdFile& file : todo) {
            const fs::path dest = stage / fs::u8path(file.path);
            if (!Fetch("files/" + file.path, dest, error) || Sha256File(dest) != file.hash) {
                if (error.empty()) error = "ファイルが壊れています: " + file.path;
                SetUpdText("アップデートに失敗しました: " + error);
                Log("update failed: " + error);
                upd = Upd::Error;
                return;
            }
        }
        // 2. 入れ替える（manifest.sig は最後）
        upd = Upd::Applying;
        SetUpdText("ファイルを入れ替えています…");
        auto clearReadOnly = [&](const fs::path& path) {
            if (fs::exists(path, ec)) fs::permissions(path, fs::perms::owner_write, fs::perm_options::add, ec);
        };
        std::stable_sort(todo.begin(), todo.end(), [](const UpdFile& a, const UpdFile& b) {
            return (a.path == AppGuard::kManifestFile) < (b.path == AppGuard::kManifestFile);
        });
        for (const UpdFile& file : todo) {
            const fs::path source = stage / fs::u8path(file.path);
            const fs::path dest = appDir / fs::u8path(file.path);
            fs::create_directories(dest.parent_path(), ec);
            clearReadOnly(dest);
            if (file.path == "GuminLauncher.exe" && fs::exists(dest, ec)) {
                // 動いている自分は上書きできないが、名前は変えられる。新しい版を置いて、次に開き直す
                fs::path old = dest;
                old += ".old";
                fs::remove(old, ec);
                fs::rename(dest, old, ec);
                relaunch = true;
            }
            fs::rename(source, dest, ec);
            if (ec) {
                ec.clear();
                fs::copy_file(source, dest, fs::copy_options::overwrite_existing, ec);
                fs::remove(source, ec);
            }
            if (ec) {
                SetUpdText("入れ替えに失敗しました: " + file.path + "（" + ec.message() + "）");
                Log("update apply failed: " + file.path + " " + ec.message());
                upd = Upd::Error;
                return;
            }
        }
        for (const std::string& path : removed) {
            const fs::path target = appDir / fs::u8path(path);
            clearReadOnly(target);
            fs::remove(target, ec);
        }
        fs::copy_file(appDir / "Backup" / "update" / "update.idx", appDir / "update.idx", fs::copy_options::overwrite_existing, ec);
        fs::remove_all(appDir / "Backup" / "update" / "files", ec);
        // 3. 全体を確かめる（manifest.sig と、いまのファイルが合っているか）
        std::string reason;
        // （証明書は、更新とは別のもの。まだ入れていなくても、ファイルだけを確かめる）
        if (!AppGuard::Verify(appDir, reason, true, false)) {
            SetUpdText("更新はしましたが、確認に失敗しました: " + reason);
            Log("update verify failed: " + reason);
            upd = Upd::Error;
            return;
        }
        {
            std::lock_guard<std::mutex> lock(mutex);
            updTodo.clear();
            updRemove.clear();
        }
        SetUpdText("アップデートしました（版 " + updRelease + "）");
        Log("update done: release " + updRelease);
        upd = Upd::Done;
        StartCheck();   // 証明書も含めて、もう一度確かめる
    }

    bool UpdateBusy() const { return upd == Upd::Checking || upd == Upd::Downloading || upd == Upd::Applying; }

    bool CanPlay() const { return (check == Check::Ok || check == Check::Idle || !AppGuard::IsProtectedBuild()) && !UpdateBusy(); }

    void Play() {
        const fs::path exe = appDir / "GuminTaiko.exe";
        std::error_code ec;
        if (!fs::exists(exe, ec)) {
            Show("GuminTaiko.exe が見つかりません", false);
            return;
        }
        SaveSettings(settings);
        std::string arguments;
        if (settings.windowed) arguments += "--windowed 1 ";
        arguments += "--play-fps " + std::to_string(settings.fps);
        arguments += settings.vsync ? " --vsync 1" : " --vsync 0";
        if (!LauncherWin::Launch(exe.u8string(), arguments, appDir.u8string())) {
            Show("起動できませんでした", false);
            return;
        }
        launching = true;   // 起動したので、ランチャーは閉じる
    }

    void OpenTool(const char* name) {
        const fs::path exe = appDir / name;
        std::error_code ec;
        if (!fs::exists(exe, ec)) {
            Show(std::string(name) + " が見つかりません", false);
            return;
        }
        LauncherWin::OpenWithShell(exe.u8string(), appDir.u8string());
    }

    void OpenFolder(const fs::path& folder) {
        std::error_code ec;
        fs::create_directories(folder, ec);
        LauncherWin::OpenWithShell(folder.u8string(), "");
    }

    void CopyId() {
        SetClipboardText(machineId.c_str());
        Show("この PC の ID をコピーしました（配布する人に送ってください）", true);
    }

    void ImportLicense() {
        const std::vector<std::string> files = LauncherWin::PickFiles(GetWindowHandle(), LauncherWin::PickKind::License);
        if (files.empty()) return;
        std::error_code ec;
        const fs::path dest = appDir / AppGuard::kLicenseFile;
        if (fs::exists(dest, ec)) fs::permissions(dest, fs::perms::owner_write, fs::perm_options::add, ec);
        fs::copy_file(fs::u8path(files.front()), dest, fs::copy_options::overwrite_existing, ec);
        if (ec) {
            Show("証明書を入れられません: " + ec.message(), false);
            return;
        }
        Show("証明書を入れました。確認します…", true);
        StartCheck();
    }

    void AddSongs(const std::vector<fs::path>& sources) {
        int added = 0, failed = 0;
        for (const fs::path& source : sources) {
            if (AddSong(source).empty()) ++failed;
            else ++added;
        }
        if (added > 0) {
            Show(std::to_string(added) + " 件を Songs\\創作譜面 に追加しました" +
                     (failed > 0 ? "（" + std::to_string(failed) + " 件は追加できませんでした）" : "") +
                     "。次にゲームを起動すると「創作譜面」に出ます",
                 failed == 0);
        } else if (failed > 0) {
            Show("追加できませんでした（曲のフォルダ・.tja・.zip を入れてください）", false);
        }
    }

    // ---- 見た目（HoYoverse のランチャーのような、大きな絵・暗い半透明のパネル・金色の「起動」ボタン） ----
    Texture2D art{};
    bool quit = false;
    bool settingsOpen = false;
    bool dragging = false;
    Vector2 dragStart{};
    float hoverAnim[16] = {};

    void LoadArt() {
        if (FileExists("Data/x64/launcher/launcher_bg.png")) {
            art = LoadTexture("Data/x64/launcher/launcher_bg.png");
            if (art.id != 0) SetTextureFilter(art, TEXTURE_FILTER_BILINEAR);
        }
    }

    static Color A(Color c, float a) { return Color{c.r, c.g, c.b, (unsigned char)std::clamp(a * 255.0f, 0.0f, 255.0f)}; }

    // 影つきの文字
    static void Label(const std::string& text, float x, float y, float size, Color color, TextAlign align = TextAlign::Left) {
        GameFont::Get().Draw(text.c_str(), x + 2.0f, y + 2.0f, size, Color{0, 0, 0, 150}, align);
        GameFont::Get().Draw(text.c_str(), x, y, size, color, align);
    }

    void Input() {
        if (IsFileDropped()) {
            FilePathList dropped = LoadDroppedFiles();
            std::vector<fs::path> sources;
            for (unsigned i = 0; i < dropped.count; ++i) sources.push_back(fs::u8path(dropped.paths[i]));
            UnloadDroppedFiles(dropped);
            AddSongs(sources);
        }
        if (IsKeyPressed(KEY_ESCAPE)) {
            if (settingsOpen) settingsOpen = false;
        }
        // 窓の上の帯をつかんで動かす（窓の枠がないので）
        const Vector2 mouse = GetMousePosition();
        if (IsMouseButtonPressed(MOUSE_BUTTON_LEFT) && mouse.y < 80.0f && mouse.x < float(kWidth) - 200.0f && !settingsOpen) {
            dragging = true;
            dragStart = mouse;
        }
        if (!IsMouseButtonDown(MOUSE_BUTTON_LEFT)) dragging = false;
        if (dragging) {
            const Vector2 pos = GetWindowPosition();
            SetWindowPosition(int(pos.x + mouse.x - dragStart.x), int(pos.y + mouse.y - dragStart.y));
        }
    }

    // 丸いアイコンのボタン（下の段）。クリックされたら true
    bool IconButton(int slot, float cx, float cy, const char* glyph, const char* label, Color tint, bool enabled = true) {
        const float radius = 34.0f;
        const bool hover = enabled && !settingsOpen && CheckCollisionPointCircle(GetMousePosition(), Vector2{cx, cy}, radius);
        float& anim = hoverAnim[slot];
        anim += ((hover ? 1.0f : 0.0f) - anim) * 0.25f;
        const float r = radius + anim * 4.0f;
        DrawCircle(int(cx), int(cy + 3), r + 2, Color{0, 0, 0, 90});
        DrawCircle(int(cx), int(cy), r, A(Color{20, 22, 32, 255}, 0.62f + anim * 0.2f));
        DrawCircleLines(int(cx), int(cy), r, A(tint, 0.55f + anim * 0.45f));
        DrawCircleLines(int(cx), int(cy), r - 1.0f, A(tint, 0.25f + anim * 0.4f));
        GameFont::Get().Draw(glyph, cx, cy - 15.0f, 30.0f, enabled ? tint : Color{150, 150, 150, 255}, TextAlign::Center);
        Label(label, cx, cy + radius + 10.0f, 15.0f, Color{235, 235, 245, 255}, TextAlign::Center);
        return hover && IsMouseButtonPressed(MOUSE_BUTTON_LEFT);
    }

    // 窓の右上の小さなボタン（図形で描く）。0: 設定 1: 最小化 2: 閉じる
    bool WindowButton(int kind, float cx, float cy) {
        const bool hover = CheckCollisionPointCircle(GetMousePosition(), Vector2{cx, cy}, 20.0f) && !(settingsOpen && kind != 2);
        float& anim = hoverAnim[10 + kind];
        anim += ((hover ? 1.0f : 0.0f) - anim) * 0.3f;
        DrawCircle(int(cx), int(cy), 20.0f, Color{255, 255, 255, (unsigned char)(anim * 60.0f)});
        const Color c = Color{255, 255, 255, (unsigned char)(190 + anim * 65.0f)};
        if (kind == 0) {   // 歯車
            DrawCircleLines(int(cx), int(cy), 7.0f, c);
            DrawCircleLines(int(cx), int(cy), 6.0f, c);
            for (int i = 0; i < 8; ++i) {
                const float angle = float(i) * 3.14159265f / 4.0f;
                DrawLineEx(Vector2{cx + std::cos(angle) * 8.0f, cy + std::sin(angle) * 8.0f},
                           Vector2{cx + std::cos(angle) * 11.5f, cy + std::sin(angle) * 11.5f}, 3.0f, c);
            }
        } else if (kind == 1) {   // 最小化
            DrawLineEx(Vector2{cx - 8.0f, cy + 2.0f}, Vector2{cx + 8.0f, cy + 2.0f}, 2.5f, c);
        } else {   // 閉じる
            DrawLineEx(Vector2{cx - 7.0f, cy - 7.0f}, Vector2{cx + 7.0f, cy + 7.0f}, 2.5f, c);
            DrawLineEx(Vector2{cx + 7.0f, cy - 7.0f}, Vector2{cx - 7.0f, cy + 7.0f}, 2.5f, c);
        }
        return hover && IsMouseButtonPressed(MOUSE_BUTTON_LEFT);
    }

    // 半透明の暗いパネル
    static void Panel(Rectangle r, float alpha = 0.55f) {
        DrawRectangleRounded(Rectangle{r.x + 2, r.y + 4, r.width, r.height}, 0.08f, 10, Color{0, 0, 0, 70});
        DrawRectangleRounded(r, 0.08f, 10, Color{14, 16, 26, (unsigned char)(alpha * 255.0f)});
        DrawRectangleRoundedLines(r, 0.08f, 10, 1.5f, Color{255, 255, 255, 40});
    }

    // 設定の中の小さなボタン（選んでいると金色）
    bool Chip(Rectangle r, const std::string& text, bool selected, bool enabled = true) {
        const bool hover = enabled && CheckCollisionPointRec(GetMousePosition(), r);
        const Color back = selected ? Color{255, 196, 70, 255} : hover ? Color{255, 255, 255, 60} : Color{255, 255, 255, 28};
        DrawRectangleRounded(r, 0.5f, 10, enabled ? back : Color{255, 255, 255, 14});
        if (!selected) DrawRectangleRoundedLines(r, 0.5f, 10, 1.2f, Color{255, 255, 255, hover ? (unsigned char)130 : (unsigned char)60});
        FitText(text, r.x + r.width * 0.5f, r.y + r.height * 0.5f, r.width - 16.0f, 20.0f, 12.0f,
                !enabled ? Color{170, 170, 180, 255} : selected ? Color{50, 30, 10, 255} : Color{240, 240, 248, 255}, TextAlign::Center);
        return hover && IsMouseButtonPressed(MOUSE_BUTTON_LEFT) && !(r.width <= 0);
    }

    void DrawStartButton(Rectangle r, bool enabled, const std::string& label, float progress) {
        const bool hover = enabled && !settingsOpen && CheckCollisionPointRec(GetMousePosition(), r);
        float& anim = hoverAnim[9];
        anim += ((hover ? 1.0f : 0.0f) - anim) * 0.2f;
        // 光
        const float pulse = 0.5f + 0.5f * std::sin(float(GetTime()) * 2.2f);
        if (enabled) {
            for (int i = 4; i >= 1; --i) {
                const float grow = float(i) * 5.0f + anim * 4.0f;
                DrawRectangleRounded(Rectangle{r.x - grow, r.y - grow, r.width + grow * 2, r.height + grow * 2}, 0.5f, 16,
                                     Color{255, 190, 60, (unsigned char)((14.0f + pulse * 8.0f + anim * 14.0f) / float(i))});
            }
        }
        DrawRectangleRounded(Rectangle{r.x, r.y + 5, r.width, r.height}, 0.5f, 16, Color{0, 0, 0, 110});
        const Color top = enabled ? Color{255, 226, 120, 255} : Color{150, 150, 158, 255};
        const Color bottom = enabled ? Color{255, 168, 40, 255} : Color{110, 110, 120, 255};
        DrawRectangleRounded(r, 0.5f, 16, bottom);
        DrawRectangleRounded(Rectangle{r.x, r.y, r.width, r.height * 0.55f}, 0.5f, 16, A(top, 0.9f));
        if (progress >= 0.0f) {   // ダウンロードの進み: 暗い板の上に、金色が左から伸びる
            DrawRectangleRounded(r, 0.5f, 16, Color{30, 32, 46, 235});
            const float fill = std::clamp(progress, 0.0f, 1.0f) * r.width;
            if (fill > 8.0f) {
                DrawRectangleRounded(Rectangle{r.x, r.y, fill, r.height}, 0.5f, 16, Color{255, 176, 48, 255});
                DrawRectangleRounded(Rectangle{r.x, r.y, fill, r.height * 0.5f}, 0.5f, 16, Color{255, 222, 120, 230});
            }
        }
        DrawRectangleRoundedLines(r, 0.5f, 16, 2.0f, Color{255, 255, 255, (unsigned char)(150 + anim * 90.0f)});
        const float cy = r.y + r.height * 0.5f;
        FitText(label, r.x + r.width * 0.5f, cy, r.width - 40.0f, 40.0f, 20.0f,
                progress >= 0.0f ? Color{255, 255, 255, 255} : enabled ? Color{86, 40, 8, 255} : Color{70, 70, 78, 255}, TextAlign::Center);
    }

    void Draw() {
        const float w = float(kWidth), h = float(kHeight);
        ClearBackground(Color{12, 14, 22, 255});
        // ---- 背景の絵 ----
        if (art.id != 0) {
            DrawTexturePro(art, Rectangle{0, 0, float(art.width), float(art.height)}, Rectangle{0, 0, w, h}, Vector2{0, 0}, 0.0f, WHITE);
        } else {
            DrawRectangleGradientV(0, 0, kWidth, kHeight, Color{40, 50, 90, 255}, Color{14, 16, 30, 255});
        }
        // 文字が読めるよう、左と下を暗くする
        DrawRectangleGradientH(0, 0, 760, kHeight, Color{8, 10, 20, 200}, Color{8, 10, 20, 0});
        DrawRectangleGradientV(0, kHeight - 260, kWidth, 260, Color{8, 10, 20, 0}, Color{8, 10, 20, 215});
        DrawRectangleGradientV(0, 0, kWidth, 110, Color{8, 10, 20, 150}, Color{8, 10, 20, 0});

        // ---- 上の帯 ----
        Label("GuminTaiko", 52.0f, 24.0f, 46.0f, WHITE);
        Label("LAUNCHER", 56.0f, 76.0f, 16.0f, Color{255, 205, 90, 255});
        DrawRectangle(52, 100, 46, 3, Color{255, 196, 70, 255});
        if (WindowButton(0, w - 140.0f, 44.0f)) settingsOpen = !settingsOpen;
        if (WindowButton(1, w - 92.0f, 44.0f)) MinimizeWindow();
        if (WindowButton(2, w - 44.0f, 44.0f)) quit = true;

        // ---- ステータスのカード ----
        std::string status;
        Color dot = Color{150, 150, 160, 255};
        {
            std::lock_guard<std::mutex> lock(mutex);
            switch (check.load()) {
                case Check::Idle:
                    status = AppGuard::IsProtectedBuild() ? "ファイルを確認していません" : "開発用のビルドです（確認しません）";
                    break;
                case Check::Running:
                    status = "ファイルを確認しています…";
                    dot = Color{255, 205, 90, 255};
                    break;
                case Check::Ok:
                    status = "準備できました。遊べます";
                    dot = Color{90, 220, 130, 255};
                    break;
                case Check::Bad:
                    status = problem;
                    dot = Color{255, 96, 90, 255};
                    break;
            }
        }
        const Rectangle statusCard{52.0f, 140.0f, 470.0f, 196.0f};
        Panel(statusCard);
        Label("ステータス", statusCard.x + 24.0f, statusCard.y + 16.0f, 20.0f, Color{255, 205, 90, 255});
        DrawCircle(int(statusCard.x + 30), int(statusCard.y + 68), 7.0f, dot);
        DrawCircle(int(statusCard.x + 30), int(statusCard.y + 68), 11.0f, A(dot, 0.25f));
        {
            std::vector<std::string> lines;
            std::string line;
            for (const char c : status) {
                if (c == '\n') {
                    lines.push_back(line);
                    line.clear();
                } else {
                    line += c;
                }
            }
            lines.push_back(line);
            float y = lines.size() > 1 ? 62.0f : 68.0f;
            for (size_t i = 0; i < lines.size() && i < 2; ++i) {
                FitText(lines[i], statusCard.x + 52.0f, statusCard.y + y, statusCard.width - 76.0f, 22.0f, 12.0f, Color{240, 240, 248, 255},
                        TextAlign::Left, Elide::Left);
                y += 26.0f;
            }
        }
        FitText("この PC の ID", statusCard.x + 24.0f, statusCard.y + 112.0f, 120.0f, 15.0f, 12.0f, Color{170, 175, 195, 255});
        FitText(machineId, statusCard.x + 140.0f, statusCard.y + 112.0f, 230.0f, 15.0f, 10.0f, Color{210, 214, 230, 255});
        if (Chip({statusCard.x + 378.0f, statusCard.y + 98.0f, 76.0f, 30.0f}, "コピー", false, !settingsOpen)) CopyId();
        // アップデートの行
        DrawRectangle(int(statusCard.x + 24), int(statusCard.y + 142), int(statusCard.width - 48), 1, Color{255, 255, 255, 40});
        {
            std::string text;
            {
                std::lock_guard<std::mutex> lock(mutex);
                text = updText.empty() ? "更新を確認していません" : updText;
            }
            const Upd u = upd.load();
            const Color color = u == Upd::Available ? Color{255, 205, 90, 255} : u == Upd::Error ? Color{255, 130, 120, 255} : Color{210, 214, 230, 255};
            FitText(text, statusCard.x + 24.0f, statusCard.y + 168.0f, 330.0f, 17.0f, 11.0f, color, TextAlign::Left, Elide::Left);
            if (Chip({statusCard.x + 366.0f, statusCard.y + 152.0f, 88.0f, 32.0f}, "更新確認", false, !settingsOpen && !UpdateBusy() && !updateSource.empty())) {
                StartUpdateCheck();
            }
        }

        // ---- 曲を追加のカード ----
        const Rectangle songCard{52.0f, 352.0f, 470.0f, 134.0f};
        const bool hot = !settingsOpen && CheckCollisionPointRec(GetMousePosition(), songCard);
        Panel(songCard, hot ? 0.72f : 0.55f);
        if (hot) DrawRectangleRoundedLines(songCard, 0.08f, 10, 2.0f, Color{255, 196, 70, 200});
        Label("曲を追加", songCard.x + 24.0f, songCard.y + 16.0f, 20.0f, Color{255, 205, 90, 255});
        FitText("曲のフォルダ・.tja・.zip を、この窓にドラッグ＆ドロップ", songCard.x + 24.0f, songCard.y + 62.0f, songCard.width - 48.0f, 18.0f, 12.0f,
                Color{235, 235, 245, 255});
        FitText("Songs\\創作譜面 に入り、ゲームの「創作譜面」に出ます", songCard.x + 24.0f, songCard.y + 86.0f, songCard.width - 48.0f, 15.0f, 11.0f,
                Color{170, 175, 195, 255});
        if (Chip({songCard.x + 24.0f, songCard.y + 98.0f, 150.0f, 28.0f}, "選んで追加…", false, !settingsOpen)) {
            std::vector<fs::path> picked;
            for (const std::string& file : LauncherWin::PickFiles(GetWindowHandle(), LauncherWin::PickKind::Songs)) picked.push_back(fs::u8path(file));
            AddSongs(picked);
        }

        // ---- 下の段の丸いボタン ----
        const float rowY = h - 92.0f;
        if (IconButton(0, 82.0f, rowY, "着", "着せかえ", Color{255, 140, 170, 255})) OpenTool("GuminDressUp.exe");
        if (IconButton(1, 192.0f, rowY, "段", "段位道場のお題", Color{120, 200, 255, 255})) OpenTool("GuminDaniEditor.exe");
        if (IconButton(2, 302.0f, rowY, "曲", "Songs", Color{150, 235, 160, 255})) OpenFolder(appDir / kSongsFolder / kCustomFolder);
        if (IconButton(3, 412.0f, rowY, "保", "Backup", Color{255, 205, 90, 255})) OpenFolder(appDir / "Backup");
        // Data\x64: 曲の追加は fumen（TJA）と sound（ogg・mp3）に入れる。ほかの素材は守られていて、書き換えると起動しなくなる
        if (IconButton(4, 522.0f, rowY, "素", "Data", Color{190, 160, 255, 255})) OpenFolder(appDir / "Data" / "x64");

        // ---- 起動ボタン ----
        const bool canPlay = CanPlay();
        const Rectangle startRect{w - 470.0f, h - 150.0f, 410.0f, 92.0f};
        const bool clicked = !settingsOpen && CheckCollisionPointRec(GetMousePosition(), startRect) && IsMouseButtonPressed(MOUSE_BUTTON_LEFT);
        const Upd u = upd.load();
        if (u == Upd::Available) {
            // 更新があるあいだは、HoYoverse のランチャーと同じように、起動ボタンが「アップデート」になる
            uint64_t total;
            {
                std::lock_guard<std::mutex> lock(mutex);
                total = updTotal;
            }
            DrawStartButton(startRect, true, "アップデート（" + FormatSize(total) + "）", -1.0f);
            if (clicked) StartUpdateApply();
        } else if (u == Upd::Downloading || u == Upd::Applying) {
            float progress = 1.0f;
            uint64_t total;
            {
                std::lock_guard<std::mutex> lock(mutex);
                total = updTotal;
            }
            if (u == Upd::Downloading && total > 0) progress = std::min(1.0f, float(double(updBytes.load()) / double(total)));
            DrawStartButton(startRect, false,
                            u == Upd::Applying ? std::string("入れ替えています…") : "ダウンロード中 " + std::to_string(int(progress * 100.0f)) + "%", progress);
        } else {
            DrawStartButton(startRect, canPlay, "ゲームを起動", -1.0f);
            if (canPlay && clicked) Play();
        }
        FitText(std::string("画面: ") + (settings.windowed ? "ウィンドウ" : "フルスクリーン") + "  /  " + std::to_string(settings.fps) + " FPS  /  垂直同期 " +
                    (settings.vsync ? "あり" : "なし"),
                startRect.x + startRect.width * 0.5f, startRect.y - 24.0f, startRect.width, 16.0f, 11.0f, Color{225, 228, 240, 255}, TextAlign::Center);

        // ---- メッセージ ----
        if (!message.empty() && GetTime() - messageTime < 8.0) {
            const float fade = std::clamp(float(8.0 - (GetTime() - messageTime)), 0.0f, 1.0f);
            const float mw = std::min(w - 120.0f, 900.0f);
            const Rectangle box{w * 0.5f - mw * 0.5f, 28.0f, mw, 46.0f};
            DrawRectangleRounded(box, 0.5f, 12, Color{14, 16, 26, (unsigned char)(210.0f * fade)});
            DrawRectangleRoundedLines(box, 0.5f, 12, 1.5f, A(messageOk ? Color{90, 220, 130, 255} : Color{255, 96, 90, 255}, fade));
            FitText(message, box.x + box.width * 0.5f, box.y + box.height * 0.5f, box.width - 40.0f, 20.0f, 12.0f,
                    A(Color{245, 245, 250, 255}, fade), TextAlign::Center, Elide::Left);
        }

        if (settingsOpen) DrawSettings();
    }

    void DrawSettings() {
        const float w = float(kWidth), h = float(kHeight);
        DrawRectangle(0, 0, kWidth, kHeight, Color{4, 6, 12, 170});
        const Rectangle box{w * 0.5f - 330.0f, h * 0.5f - 225.0f, 660.0f, 450.0f};
        Panel(box, 0.9f);
        Label("設定", box.x + 36.0f, box.y + 26.0f, 30.0f, WHITE);
        DrawRectangle(int(box.x + 36), int(box.y + 70), 46, 3, Color{255, 196, 70, 255});
        if (WindowButton(2, box.x + box.width - 38.0f, box.y + 40.0f)) settingsOpen = false;

        float y = box.y + 100.0f;
        auto section = [&](const char* name) { FitText(name, box.x + 36.0f, y + 18.0f, 150.0f, 20.0f, 13.0f, Color{255, 205, 90, 255}); };
        section("画面");
        if (Chip({box.x + 200.0f, y, 190.0f, 38.0f}, "フルスクリーン", !settings.windowed)) settings.windowed = false;
        if (Chip({box.x + 404.0f, y, 190.0f, 38.0f}, "ウィンドウ", settings.windowed)) settings.windowed = true;
        y += 62.0f;
        section("描く速さ（FPS）");
        for (int i = 0; i < 4; ++i) {
            if (Chip({box.x + 200.0f + float(i) * 102.0f, y, 94.0f, 38.0f}, std::to_string(kFpsChoices[i]), settings.fps == kFpsChoices[i])) {
                settings.fps = kFpsChoices[i];
            }
        }
        y += 62.0f;
        section("垂直同期");
        if (Chip({box.x + 200.0f, y, 190.0f, 38.0f}, "あり", settings.vsync)) settings.vsync = true;
        if (Chip({box.x + 404.0f, y, 190.0f, 38.0f}, "なし", !settings.vsync)) settings.vsync = false;
        y += 52.0f;
        FitText("演奏中の FPS は、モニターの更新回数に合わせると、いちばんなめらかです", box.x + 36.0f, y + 8.0f, box.width - 72.0f, 14.0f, 11.0f,
                Color{170, 175, 195, 255});
        y += 42.0f;
        DrawRectangle(int(box.x + 36), int(y), int(box.width - 72), 1, Color{255, 255, 255, 40});
        y += 22.0f;
        section("証明書・確認");
        if (Chip({box.x + 200.0f, y, 140.0f, 38.0f}, "ID をコピー", false)) CopyId();
        if (Chip({box.x + 350.0f, y, 140.0f, 38.0f}, "証明書を入れる", false)) ImportLicense();
        if (Chip({box.x + 500.0f, y, 124.0f, 38.0f}, "ファイル確認", false, check != Check::Running)) StartCheck();
        y += 48.0f;
        FitText("証明書は PC ごとのものです。ID を配布する人に送り、もらった license.cert を入れてください", box.x + 36.0f, y + 8.0f,
                box.width - 72.0f, 14.0f, 11.0f, Color{170, 175, 195, 255});
    }};

} // namespace

int main(int argc, char** argv) {
    // 自分のフォルダ（ゲームのフォルダ）で動かす。開発のビルドのフォルダから動かしたときは、1つ上を探す
    ChangeDirectory(GetApplicationDirectory());
    if (!DirectoryExists("Data") && DirectoryExists("../Data")) ChangeDirectory("..");

    App app;
    app.appDir = fs::current_path();
    app.settings = LoadSettings();
    app.machineId = GuardCrypto::MachineId();

    std::string shot;
    float after = 1.0f;
    bool autoCheck = false;
    bool openSettings = false;
    for (int i = 1; i + 1 < argc; i += 2) {
        const std::string key = argv[i], value = argv[i + 1];
        if (key == "--shot") shot = value;
        else if (key == "--after") after = float(std::atof(value.c_str()));
        else if (key == "--check") autoCheck = std::atoi(value.c_str()) != 0;
        else if (key == "--settings") openSettings = std::atoi(value.c_str()) != 0;
        else if (key == "--update") app.autoUpdate = std::atoi(value.c_str()) != 0;
    }

    SetTraceLogLevel(LOG_WARNING);
    SetConfigFlags(FLAG_MSAA_4X_HINT | FLAG_VSYNC_HINT | FLAG_WINDOW_UNDECORATED);
    InitWindow(kWidth, kHeight, "GuminTaiko ランチャー");
    SetTargetFPS(60);
    SetExitKey(KEY_NULL);
    app.LoadArt();
    app.LoadUpdateSource();
    {
        std::error_code ec;
        fs::remove(app.appDir / "GuminLauncher.exe.old", ec);   // 前の版（アップデートで入れ替えたもの）
    }
    app.settingsOpen = openSettings;

    // 起動したらすぐ、証明書とファイルを確かめる
    if (AppGuard::IsProtectedBuild() || autoCheck) app.StartCheck();
    // 更新元があれば、裏で更新を確認する
    app.StartUpdateCheck();

    float time = 0.0f;
    while (!WindowShouldClose() && !app.launching && !app.quit) {
        time += GetFrameTime();
        app.Input();
        if (app.autoUpdate) {   // 確認用: 更新を確認 → あれば適用 → 結果をログに書いて終わる
            const App::Upd u = app.upd.load();
            if (u == App::Upd::Available) app.StartUpdateApply();
            else if (u == App::Upd::UpToDate || u == App::Upd::Done || u == App::Upd::Error || u == App::Upd::NoSource) {
                std::string text;
                {
                    std::lock_guard<std::mutex> lock(app.mutex);
                    text = app.updText;
                }
                app.Log("auto update result: " + text);
                break;
            }
        }
        BeginDrawing();
        app.Draw();
        EndDrawing();
        if (!shot.empty() && time >= after) {
            TakeScreenshot(shot.c_str());
            break;
        }
    }
    if (app.worker.joinable()) app.worker.join();
    SaveSettings(app.settings);
    if (app.updWorker.joinable()) app.updWorker.join();
    if (app.art.id != 0) UnloadTexture(app.art);
    GameFont::Get().Unload();
    CloseWindow();
    if (app.relaunch) LauncherWin::Launch((app.appDir / "GuminLauncher.exe").u8string(), "", app.appDir.u8string());   // 新しくなったランチャーを開き直す
    return 0;
}
