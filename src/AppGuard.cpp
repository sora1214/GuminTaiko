// Windows の API を使うので raylib.h は読まない（名前がぶつかる）
#include "AppGuard.hpp"

#include <algorithm>
#include <atomic>
#include <cctype>
#include <cstring>
#include <mutex>
#include <thread>
#include <ctime>
#include <fstream>
#include <map>
#include <set>
#include <sstream>
#include <system_error>

#include <windows.h>

#include "GuardCrypto.hpp"
#include "GuardPublicKey.inc"

namespace fs = std::filesystem;

namespace AppGuard {

namespace {

constexpr uint64_t kFullHashLimit = 256 * 1024;   // これ以下のファイルは全体のハッシュ
constexpr uint64_t kSampleSize = 64 * 1024;        // 大きいファイルは先頭・真ん中・末尾をこの大きさずつ

std::wstring Wide(const std::string& s) {
    if (s.empty()) return {};
    const int size = MultiByteToWideChar(CP_UTF8, 0, s.c_str(), int(s.size()), nullptr, 0);
    std::wstring out(size_t(size), L'\0');
    MultiByteToWideChar(CP_UTF8, 0, s.c_str(), int(s.size()), out.data(), size);
    return out;
}

// ランチャーなどが、画面を出さずに理由だけ受け取るとき（Verify）
thread_local std::string* g_problemSink = nullptr;

void Fail(const std::string& message) {
    if (g_problemSink) {
        *g_problemSink = message;
        return;
    }
    const std::string text = message + "\n\nGuminTaiko を起動できません。";
    MessageBoxW(nullptr, Wide(text).c_str(), L"GuminTaiko", MB_OK | MB_ICONERROR);
}

void CopyToClipboard(const std::string& text) {
    const std::wstring wide = Wide(text);
    if (!OpenClipboard(nullptr)) return;
    EmptyClipboard();
    if (HGLOBAL mem = GlobalAlloc(GMEM_MOVEABLE, (wide.size() + 1) * sizeof(wchar_t))) {
        std::memcpy(GlobalLock(mem), wide.c_str(), (wide.size() + 1) * sizeof(wchar_t));
        GlobalUnlock(mem);
        if (!SetClipboardData(CF_UNICODETEXT, mem)) GlobalFree(mem);
    }
    CloseClipboard();
}

// 証明書の問題: この PC の ID を出してクリップボードにも入れる（ライセンス作成アプリ GuminLicense に貼り付けて証明書を作る）
void FailLicense(const std::string& message) {
    if (g_problemSink) {
        *g_problemSink = message;
        return;
    }
    const std::string id = GuardCrypto::MachineId();
    CopyToClipboard(id);
    Fail(message + "\n\nこの PC の ID: " + id +
         "\n（クリップボードにコピーしました。ライセンス作成アプリ GuminLicense に貼り付けて証明書を作り、"
         "できた license.cert を GuminTaiko のフォルダに入れてください）");
}

bool ReadText(const fs::path& path, std::string& out) {
    std::ifstream ifs(path, std::ios::binary);
    if (!ifs) return false;
    std::stringstream ss;
    ss << ifs.rdbuf();
    out = ss.str();
    return true;
}

// key=value の行
std::map<std::string, std::string> ParseLines(const std::string& text) {
    std::map<std::string, std::string> values;
    std::istringstream in(text);
    std::string line;
    while (std::getline(in, line)) {
        if (!line.empty() && line.back() == '\r') line.pop_back();
        const size_t eq = line.find('=');
        if (eq != std::string::npos && line.compare(0, 5, "file=") != 0) values[line.substr(0, eq)] = line.substr(eq + 1);
    }
    return values;
}

bool VerifySigned(const std::string& text, std::string& body) {
    std::string signatureHex;
    std::vector<uint8_t> signature;
    return SplitSigned(text, body, signatureHex) && GuardCrypto::FromHex(signatureHex, signature) &&
           GuardCrypto::Verify(kGuardPublicKey, kGuardPublicKeySize, body, signature);
}

std::string Today() {
    const std::time_t now = std::time(nullptr);
    std::tm tm{};
    localtime_s(&tm, &now);
    char buf[16];
    std::strftime(buf, sizeof(buf), "%Y-%m-%d", &tm);
    return buf;
}

bool CheckLicense(const fs::path& dir) {
    std::string text, body;
    if (!ReadText(dir / kLicenseFile, text)) {
        FailLicense("証明書（" + std::string(kLicenseFile) + "）がありません。");
        return false;
    }
    if (kGuardPublicKeySize == 0 || !VerifySigned(text, body)) {
        FailLicense("証明書が正しくありません（書き換えられているか、このアプリ用のものではありません）。");
        return false;
    }
    const auto values = ParseLines(body);
    auto value = [&](const char* key) {
        auto found = values.find(key);
        return found != values.end() ? found->second : std::string();
    };
    if (value("product") != kProduct) {
        Fail("証明書がこのアプリ用のものではありません。");
        return false;
    }
    if (value("machine") != GuardCrypto::MachineId()) {
        FailLicense("証明書がこの PC 用のものではありません。");
        return false;
    }
    const std::string expires = value("expires");
    if (!expires.empty() && expires != "never" && Today() > expires) {
        FailLicense("証明書の期限（" + expires + "）が切れています。");
        return false;
    }
    return true;
}

bool CheckManifest(const fs::path& dir) {
    std::string text, body;
    if (!ReadText(dir / kManifestFile, text)) {
        Fail("改変の検知に使うファイル（" + std::string(kManifestFile) + "）がありません。");
        return false;
    }
    if (!VerifySigned(text, body)) {
        Fail(std::string(kManifestFile) + " が正しくありません（書き換えられています）。");
        return false;
    }
    if (ParseLines(body)["product"] != kProduct) {
        Fail(std::string(kManifestFile) + " がこのアプリ用のものではありません。");
        return false;
    }

    // file=モード|大きさ|ハッシュ|パス
    struct Entry {
        char mode;
        uint64_t size;
        std::string digest;
    };
    std::map<std::string, Entry> entries;
    std::istringstream in(body);
    std::string line;
    while (std::getline(in, line)) {
        if (line.compare(0, 5, "file=") != 0) continue;
        std::istringstream fields(line.substr(5));
        std::string mode, size, digest, path;
        std::getline(fields, mode, '|');
        std::getline(fields, size, '|');
        std::getline(fields, digest, '|');
        std::getline(fields, path);
        if (mode.size() != 1 || path.empty()) continue;
        entries[path] = Entry{mode[0], std::strtoull(size.c_str(), nullptr, 10), digest};
    }

    // 足されたファイル・消されたファイル
    const std::vector<std::string> files = ProtectedFiles(dir);
    const std::set<std::string> onDisk(files.begin(), files.end());
    for (const std::string& file : files) {
        if (!entries.count(file)) {
            Fail("アプリのファイルが足されています:\n" + file);
            return false;
        }
    }
    for (const auto& [path, entry] : entries) {
        if (!onDisk.count(path)) {
            Fail("アプリのファイルがありません:\n" + path);
            return false;
        }
    }
    // 中身（2 万ファイルあるので、いくつかのスレッドで分けて確かめる）
    std::vector<const std::pair<const std::string, Entry>*> list;
    for (const auto& item : entries) list.push_back(&item);
    std::atomic<size_t> next{0};
    std::atomic<bool> bad{false};
    std::mutex badMutex;
    std::string badPath;
    auto worker = [&] {
        for (size_t i = next++; i < list.size() && !bad; i = next++) {
            const std::string& path = list[i]->first;
            const Entry& entry = list[i]->second;
            const fs::path full = dir / fs::u8path(path);
            std::error_code ec;
            const uint64_t size = fs::file_size(full, ec);
            char mode = 0;
            if (ec || size != entry.size || FileDigest(full, size, mode) != entry.digest || mode != entry.mode) {
                std::lock_guard<std::mutex> lock(badMutex);
                if (!bad) badPath = path;
                bad = true;
            }
        }
    };
    const unsigned count = std::clamp(std::thread::hardware_concurrency(), 2u, 8u);
    std::vector<std::thread> threads;
    for (unsigned t = 0; t < count; ++t) threads.emplace_back(worker);
    for (std::thread& t : threads) t.join();
    if (bad) {
        Fail("アプリのファイルが書き換えられています:\n" + badPath);
        return false;
    }
    return true;
}

} // namespace

std::vector<std::string> ProtectedFiles(const fs::path& appDir) {
    std::vector<std::string> files;
    std::error_code ec;
    // 実行ファイル（と一緒に置く DLL）
    for (const auto& entry : fs::directory_iterator(appDir, ec)) {
        if (!entry.is_regular_file()) continue;
        std::string ext = entry.path().extension().u8string();
        std::transform(ext.begin(), ext.end(), ext.begin(), [](unsigned char c) { return char(std::tolower(c)); });
        if (ext == ".exe" || ext == ".dll") files.push_back(entry.path().filename().u8string());
    }
    // 素材（Data/cache は音の変換結果を書くので含めない）と、ゲームが呼ぶ音の変換ツール
    // （fs::relative はパスを1つずつ解決して遅いので、アプリのフォルダの分を文字で取り除く）
    const std::string base = appDir.generic_u8string();
    const size_t skip = base.size() + (base.empty() || base.back() == '/' ? 0 : 1);
    for (const fs::path& root : {appDir / "Data" / "x64", appDir / "third_party" / "vgmstream"}) {
        ec.clear();
        for (auto it = fs::recursive_directory_iterator(root, ec); !ec && it != fs::recursive_directory_iterator(); it.increment(ec)) {
            if (!it->is_regular_file()) continue;
            std::string relative = it->path().generic_u8string().substr(skip);
            // 曲の TJA（Data/x64/fumen）と曲の並び（songs_index）は、Songs と同じく自由に足したり変えたりしてよい
            if (relative.rfind("Data/x64/fumen/", 0) == 0 || relative.rfind("Data/x64/datatable/songs_index/", 0) == 0) continue;
            // fumen の TJA の音源（Data/x64/sound の ogg・mp3・wav）も同じ。本家の音（nus3bank）は確かめる
            if (relative.rfind("Data/x64/sound/", 0) == 0) {
                std::string ext = it->path().extension().u8string();
                std::transform(ext.begin(), ext.end(), ext.begin(), [](unsigned char c) { return char(std::tolower(c)); });
                if (ext == ".ogg" || ext == ".mp3" || ext == ".wav") continue;
            }
            files.push_back(std::move(relative));
        }
    }
    std::sort(files.begin(), files.end());
    return files;
}

std::string FileDigest(const fs::path& path, uint64_t size, char& mode) {
    std::ifstream ifs(path, std::ios::binary);
    if (!ifs) return {};
    GuardCrypto::Sha256 sha;
    std::vector<char> buffer(size_t(std::min<uint64_t>(std::max<uint64_t>(size, 1), kFullHashLimit)));
    if (size <= kFullHashLimit) {
        mode = 'f';
        ifs.read(buffer.data(), std::streamsize(size));
        sha.Update(buffer.data(), size_t(ifs.gcount()));
    } else {
        mode = 's';
        const std::string sizeText = std::to_string(size);
        sha.Update(sizeText.data(), sizeText.size());
        for (uint64_t offset : {uint64_t(0), size / 2 - kSampleSize / 2, size - kSampleSize}) {
            ifs.seekg(std::streamoff(offset));
            ifs.read(buffer.data(), std::streamsize(kSampleSize));
            sha.Update(buffer.data(), size_t(ifs.gcount()));
        }
    }
    const GuardCrypto::Digest digest = sha.Finish();
    return GuardCrypto::ToHex(digest.data(), digest.size());
}

bool SplitSigned(const std::string& text, std::string& body, std::string& signatureHex) {
    const size_t pos = text.rfind("\nsignature=");
    if (pos == std::string::npos) return false;
    body = text.substr(0, pos + 1);
    signatureHex = text.substr(pos + 11);
    while (!signatureHex.empty() && (signatureHex.back() == '\n' || signatureHex.back() == '\r')) signatureHex.pop_back();
    return true;
}

bool IssueLicense(const std::vector<uint8_t>& privateKey, const std::string& licensee, const std::string& machine,
                  const std::string& expires, std::string& out) {
    const std::time_t now = std::time(nullptr);
    std::tm tm{};
    localtime_s(&tm, &now);
    char issued[32];
    std::strftime(issued, sizeof(issued), "%Y-%m-%d %H:%M:%S", &tm);
    std::ostringstream body;
    body << "GuminTaiko License\nversion=1\nproduct=" << kProduct << "\nlicensee=" << licensee << "\nmachine=" << machine
         << "\nissued=" << issued << "\nexpires=" << (expires.empty() ? "never" : expires) << "\n";
    std::vector<uint8_t> signature;
    if (!GuardCrypto::Sign(privateKey, body.str(), signature)) return false;
    out = body.str() + "signature=" + GuardCrypto::ToHex(signature.data(), signature.size()) + "\n";
    return true;
}

bool IsMachineId(const std::string& id) {
    if (id.size() != 36) return false;
    for (size_t i = 0; i < id.size(); ++i) {
        const bool dash = i == 8 || i == 13 || i == 18 || i == 23;
        if (dash ? id[i] != '-' : !std::isxdigit(static_cast<unsigned char>(id[i]))) return false;
    }
    return true;
}

bool Verify(const fs::path& dir, std::string& problem, bool checkFiles) {
#ifdef GUMIN_PROTECT
    problem.clear();
    g_problemSink = &problem;
    bool ok = CheckLicense(dir);
    if (ok && checkFiles) ok = CheckManifest(dir);
    g_problemSink = nullptr;
    return ok;
#else
    (void)dir;
    (void)checkFiles;
    problem.clear();
    return true;   // 保護なしのビルド（開発用）は確かめない
#endif
}

bool VerifySignedText(const std::string& text, std::string& body) {
#ifdef GUMIN_PROTECT
    return VerifySigned(text, body);
#else
    // 保護なしのビルド（開発用）は公開鍵を持たないので、署名は確かめず、本文だけ取り出す
    std::string signatureHex;
    return SplitSigned(text, body, signatureHex);
#endif
}

bool IsProtectedBuild() {
#ifdef GUMIN_PROTECT
    return true;
#else
    return false;
#endif
}

bool CheckAtStartup() {
#ifdef GUMIN_PROTECT
    wchar_t exe[MAX_PATH] = {};
    GetModuleFileNameW(nullptr, exe, MAX_PATH);
    const fs::path dir = fs::path(exe).parent_path();
    SetCurrentDirectoryW(dir.c_str());
    return CheckLicense(dir) && CheckManifest(dir);
#else
    return true;
#endif
}

} // namespace AppGuard
