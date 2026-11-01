// gumin_sign: アプリの保護に使う鍵・署名・証明書を作る（開発の PC だけで使う。配置したアプリには入れない）
//   gumin_sign keygen [--force]
//       署名の鍵を作る。秘密鍵 keys/gumin_private.key（大事に保管する）と、公開鍵を埋め込む src/GuardPublicKey.inc を書く
//       （書いたら保護付きのビルドを作り直すこと）
//   gumin_sign manifest <アプリのフォルダ>
//       実行ファイルと Data/x64 のファイルのハッシュを署名して <アプリのフォルダ>/manifest.sig に書く
//   gumin_sign license <アプリのフォルダ> [--licensee 名前] [--machine MachineGuid] [--expires YYYY-MM-DD|never]
//       証明書 <アプリのフォルダ>/license.cert を書く（--machine を省くとこの PC）
//   gumin_sign update <アプリのフォルダ> <出力のフォルダ> [--version 版]
//       アップデートの配布物を作る（<出力>\files\ に配るファイル、<出力>\update.idx に署名つきの目録）
//   共通: --key 秘密鍵のパス（既定 keys/gumin_private.key）
#include <cstdio>
#include <ctime>
#include <filesystem>
#include <fstream>
#include <set>
#include <sstream>
#include <string>
#include <system_error>
#include <vector>

#include "AppGuard.hpp"
#include "GuardCrypto.hpp"

namespace fs = std::filesystem;

namespace {

std::string Now() {
    const std::time_t now = std::time(nullptr);
    std::tm tm{};
    localtime_s(&tm, &now);
    char buf[32];
    std::strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", &tm);
    return buf;
}

bool ReadBinary(const fs::path& path, std::vector<uint8_t>& out) {
    std::ifstream ifs(path, std::ios::binary);
    if (!ifs) return false;
    out.assign(std::istreambuf_iterator<char>(ifs), std::istreambuf_iterator<char>());
    return true;
}

bool WriteText(const fs::path& path, const std::string& text) {
    std::error_code ec;
    if (fs::exists(path, ec)) fs::permissions(path, fs::perms::owner_write, fs::perm_options::add, ec);   // 読み取り専用を外す
    std::ofstream ofs(path, std::ios::binary | std::ios::trunc);
    if (!ofs) return false;
    ofs << text;
    return bool(ofs);
}

// 署名して「signature=」の行を足す
bool SignAndWrite(const fs::path& keyPath, const std::string& body, const fs::path& out) {
    std::vector<uint8_t> key, signature;
    if (!ReadBinary(keyPath, key)) {
        std::fprintf(stderr, "秘密鍵 %s を読めません（先に keygen）\n", keyPath.u8string().c_str());
        return false;
    }
    if (!GuardCrypto::Sign(key, body, signature)) {
        std::fprintf(stderr, "署名できません\n");
        return false;
    }
    if (!WriteText(out, body + "signature=" + GuardCrypto::ToHex(signature.data(), signature.size()) + "\n")) {
        std::fprintf(stderr, "%s に書けません\n", out.u8string().c_str());
        return false;
    }
    return true;
}

int KeyGen(bool force) {
    const fs::path privatePath = "keys/gumin_private.key";
    std::error_code ec;
    if (fs::exists(privatePath, ec) && !force) {
        std::fprintf(stderr, "鍵はもうあります（作り直すと、今までの証明書と署名は使えなくなります。--force で作り直す）\n");
        return 1;
    }
    std::vector<uint8_t> privateBlob, publicBlob;
    if (!GuardCrypto::GenerateKey(privateBlob, publicBlob)) {
        std::fprintf(stderr, "鍵を作れません\n");
        return 1;
    }
    fs::create_directories("keys", ec);
    std::ofstream(privatePath, std::ios::binary).write(reinterpret_cast<const char*>(privateBlob.data()), std::streamsize(privateBlob.size()));
    std::ofstream("keys/gumin_public.key", std::ios::binary)
        .write(reinterpret_cast<const char*>(publicBlob.data()), std::streamsize(publicBlob.size()));
    std::ostringstream inc;
    inc << "// 署名の公開鍵（tools/gumin_sign keygen が書く。ここを手で変えないこと）\n";
    inc << "static const unsigned char kGuardPublicKey[] = {";
    for (size_t i = 0; i < publicBlob.size(); ++i) inc << (i % 12 == 0 ? "\n    " : " ") << "0x" << GuardCrypto::ToHex(&publicBlob[i], 1) << ",";
    inc << "\n};\nstatic const size_t kGuardPublicKeySize = sizeof(kGuardPublicKey);\n";
    if (!WriteText("src/GuardPublicKey.inc", inc.str())) {
        std::fprintf(stderr, "src/GuardPublicKey.inc に書けません（ゲームのフォルダで実行してください）\n");
        return 1;
    }
    std::printf("鍵を作りました: %s（大事に保管。アプリと一緒に置かないこと）\n", privatePath.u8string().c_str());
    return 0;
}

int Manifest(const fs::path& appDir, const fs::path& keyPath) {
    std::ostringstream body;
    body << "GuminTaiko Manifest\nversion=1\nproduct=" << AppGuard::kProduct << "\ncreated=" << Now() << "\n";
    size_t count = 0;
    for (const std::string& file : AppGuard::ProtectedFiles(appDir)) {
        const fs::path path = appDir / fs::u8path(file);
        std::error_code ec;
        const uint64_t size = fs::file_size(path, ec);
        if (ec) continue;
        char mode = 0;
        const std::string digest = AppGuard::FileDigest(path, size, mode);
        body << "file=" << mode << '|' << size << '|' << digest << '|' << file << "\n";
        ++count;
    }
    if (!SignAndWrite(keyPath, body.str(), appDir / AppGuard::kManifestFile)) return 1;
    std::printf("%zu 個のファイルを署名しました: %s\n", count, (appDir / AppGuard::kManifestFile).u8string().c_str());
    return 0;
}

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

// アップデートの配布物を作る: <出力>\files\ に配るファイルを置き、<出力>\update.idx（署名つきの目録）を書く
//   配るファイル = 署名した manifest.sig と、それが守るファイル（実行ファイル・Data/x64 の素材など）。曲・Backup・証明書は入れない
int Update(const fs::path& appDir, const fs::path& outDir, const std::string& version, const fs::path& keyPath) {
    std::vector<std::string> files = AppGuard::ProtectedFiles(appDir);
    files.push_back(AppGuard::kManifestFile);
    std::ostringstream body;
    body << "GuminTaiko Update\nversion=1\nproduct=" << AppGuard::kProduct << "\nrelease=" << version << "\ncreated=" << Now() << "\n";
    std::error_code ec;
    size_t copied = 0, same = 0;
    for (const std::string& file : files) {
        const fs::path source = appDir / fs::u8path(file);
        const uint64_t size = fs::file_size(source, ec);
        if (ec) {
            std::fprintf(stderr, "%s を読めません\n", file.c_str());
            return 1;
        }
        const std::string hash = Sha256File(source);
        body << "file=" << size << '|' << hash << '|' << file << "\n";
        const fs::path dest = outDir / "files" / fs::u8path(file);
        if (fs::exists(dest, ec) && fs::file_size(dest, ec) == size && Sha256File(dest) == hash) {
            ++same;
            continue;
        }
        fs::create_directories(dest.parent_path(), ec);
        // 前に置いたものが読み取り専用（配置したアプリの実行ファイルは読み取り専用）だと、上書きできない
        if (fs::exists(dest, ec)) fs::permissions(dest, fs::perms::owner_write, fs::perm_options::add, ec);
        fs::copy_file(source, dest, fs::copy_options::overwrite_existing, ec);
        if (!ec) fs::permissions(dest, fs::perms::owner_write, fs::perm_options::add, ec);   // コピーも読み取り専用になるので、外しておく
        if (ec) {
            std::fprintf(stderr, "%s にコピーできません: %s\n", dest.u8string().c_str(), ec.message().c_str());
            return 1;
        }
        ++copied;
    }
    // 目録にないファイル（前の版の残り）は消す
    size_t removed = 0;
    std::set<std::string> keep;
    for (const std::string& file : files) keep.insert(fs::u8path(file).generic_u8string());
    const fs::path filesDir = outDir / "files";
    std::vector<fs::path> stale;
    for (auto it = fs::recursive_directory_iterator(filesDir, ec); !ec && it != fs::recursive_directory_iterator(); it.increment(ec)) {
        if (!it->is_regular_file()) continue;
        const std::string relative = fs::relative(it->path(), filesDir, ec).generic_u8string();
        if (!keep.count(relative)) stale.push_back(it->path());
    }
    for (const fs::path& path : stale) {
        fs::permissions(path, fs::perms::owner_write, fs::perm_options::add, ec);
        fs::remove(path, ec);
        ++removed;
    }
    fs::create_directories(outDir, ec);
    if (!SignAndWrite(keyPath, body.str(), outDir / "update.idx")) return 1;
    std::printf("アップデートの配布物を作りました: %s\n  版 %s / %zu 個（新しく置いた %zu・同じ %zu・消した %zu）\n",
                outDir.u8string().c_str(), version.c_str(), files.size(), copied, same, removed);
    return 0;
}

int License(const fs::path& appDir, const fs::path& keyPath, const std::string& licensee, std::string machine, const std::string& expires) {
    if (machine.empty()) machine = GuardCrypto::MachineId();
    if (machine.empty()) {
        std::fprintf(stderr, "この PC の MachineGuid を読めません\n");
        return 1;
    }
    std::vector<uint8_t> key;
    std::string cert;
    if (!ReadBinary(keyPath, key) || !AppGuard::IssueLicense(key, licensee, machine, expires, cert)) {
        std::fprintf(stderr, "証明書を作れません（秘密鍵 %s）\n", keyPath.u8string().c_str());
        return 1;
    }
    if (!WriteText(appDir / AppGuard::kLicenseFile, cert)) {
        std::fprintf(stderr, "%s に書けません\n", (appDir / AppGuard::kLicenseFile).u8string().c_str());
        return 1;
    }
    std::printf("証明書を書きました: %s（%s / %s）\n", (appDir / AppGuard::kLicenseFile).u8string().c_str(), licensee.c_str(),
                machine.c_str());
    return 0;
}

} // namespace

int main(int argc, char** argv) {
    if (argc < 2) {
        std::printf("使い方: gumin_sign keygen [--force] | manifest <フォルダ> | license <フォルダ> [--licensee 名前] [--machine ID] "
                    "[--expires YYYY-MM-DD|never]\n");
        return 1;
    }
    const std::string command = argv[1];
    fs::path keyPath = "keys/gumin_private.key";
    std::string licensee = "owner", machine, expires = "never";
    bool force = false;
    std::string version = "0";
    std::vector<std::string> args;
    for (int i = 2; i < argc; ++i) {
        const std::string a = argv[i];
        if (a == "--force") force = true;
        else if (a == "--key" && i + 1 < argc) keyPath = fs::u8path(argv[++i]);
        else if (a == "--licensee" && i + 1 < argc) licensee = argv[++i];
        else if (a == "--machine" && i + 1 < argc) machine = argv[++i];
        else if (a == "--expires" && i + 1 < argc) expires = argv[++i];
        else if (a == "--version" && i + 1 < argc) version = argv[++i];
        else args.push_back(a);
    }
    if (command == "keygen") return KeyGen(force);
    if (command == "manifest" && !args.empty()) return Manifest(fs::u8path(args[0]), keyPath);
    if (command == "update" && args.size() >= 2) return Update(fs::u8path(args[0]), fs::u8path(args[1]), version, keyPath);
    if (command == "license" && !args.empty()) return License(fs::u8path(args[0]), keyPath, licensee, machine, expires);
    std::fprintf(stderr, "コマンドがちがいます: %s\n", command.c_str());
    return 1;
}
