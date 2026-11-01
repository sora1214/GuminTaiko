#pragma once
#include <cstdint>
#include <filesystem>
#include <string>
#include <vector>

// アプリの保護（自分用に配置したアプリ C:\GuminTaiko などで使う）
//   ・証明書 license.cert: この PC（MachineGuid）向けに署名したもの。ないか、違う PC のものなら起動しない
//   ・改変の検知 manifest.sig: 実行ファイルと Data/x64 のすべてのファイルの大きさとハッシュを署名したもの。
//     違うファイル・足したファイル・消したファイルがあれば起動しない（Songs・Backup・Data/cache は自由に変えてよい）
//   署名の秘密鍵は開発の PC だけにあり（keys/gumin_private.key）、公開鍵は実行ファイルに埋め込む（GuardPublicKey.inc）。
//   保護付きのビルド（CMake の GUMIN_PROTECT=ON）だけで確かめ、ふだんの開発のビルドでは何もしない
namespace AppGuard {

constexpr const char* kLicenseFile = "license.cert";
constexpr const char* kManifestFile = "manifest.sig";
constexpr const char* kProduct = "GuminTaiko";

// 起動時の確認。問題があればメッセージを出して false（呼んだ側はそのまま終わる）。
// 実行ファイルのあるフォルダを作業フォルダにする
bool CheckAtStartup();

// 画面を出さずに確かめる（ランチャー用）。証明書（license.cert）と、checkFiles なら改変の検知（manifest.sig）も。
// 問題があれば理由を problem に入れて false。保護なしのビルドでは常に true
bool Verify(const std::filesystem::path& dir, std::string& problem, bool checkFiles);
// 署名つきのテキスト（「signature=」の行つき）を確かめて、本文を body に入れる（アップデートの目録に使う）。
// 保護なしのビルドでは署名を確かめない（開発用）
bool VerifySignedText(const std::string& text, std::string& body);
// 保護付きのビルドか
bool IsProtectedBuild();

// ---- 署名ツール（tools/gumin_sign）と共通 ----
// 守るファイル（appDir からの相対パス。/ 区切り、UTF-8）
std::vector<std::string> ProtectedFiles(const std::filesystem::path& appDir);
// ファイルのハッシュ（小さいファイルは全体、大きいファイルは大きさと先頭・真ん中・末尾）。mode は 'f' か 's'
std::string FileDigest(const std::filesystem::path& path, uint64_t size, char& mode);
// 「signature=」の行より前（署名する部分）と、署名の16進を分ける
bool SplitSigned(const std::string& text, std::string& body, std::string& signatureHex);

// ---- 証明書を作る（gumin_sign と GuminLicense で共通。秘密鍵がいる）----
// machine: 発行先の PC の MachineGuid、expires: YYYY-MM-DD か never。できた証明書の中身を out に入れる
bool IssueLicense(const std::vector<uint8_t>& privateKey, const std::string& licensee, const std::string& machine,
                  const std::string& expires, std::string& out);
// MachineGuid の形（xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx）か
bool IsMachineId(const std::string& id);

} // namespace AppGuard
