#pragma once
#include <array>
#include <cstdint>
#include <string>
#include <vector>

// アプリの保護（証明書と改変の検知）に使う暗号（Windows の CNG: SHA-256 と ECDSA P-256）
//   鍵・署名は CNG の形のまま（公開鍵 BCRYPT_ECCPUBLIC_BLOB 72 バイト、秘密鍵 BCRYPT_ECCPRIVATE_BLOB 104 バイト、署名 r||s 64 バイト）
namespace GuardCrypto {

using Digest = std::array<uint8_t, 32>;

// SHA-256 を少しずつ計算する
class Sha256 {
public:
    Sha256();
    ~Sha256();
    Sha256(const Sha256&) = delete;
    Sha256& operator=(const Sha256&) = delete;
    void Update(const void* data, size_t size);
    Digest Finish();

private:
    void* hash_ = nullptr;
};
Digest Hash(const std::string& data);

bool GenerateKey(std::vector<uint8_t>& privateBlob, std::vector<uint8_t>& publicBlob);
bool Sign(const std::vector<uint8_t>& privateBlob, const std::string& message, std::vector<uint8_t>& signature);
bool Verify(const uint8_t* publicBlob, size_t publicSize, const std::string& message, const std::vector<uint8_t>& signature);

// この PC を表す ID（HKLM\SOFTWARE\Microsoft\Cryptography\MachineGuid）
std::string MachineId();

std::string ToHex(const uint8_t* data, size_t size);
bool FromHex(const std::string& hex, std::vector<uint8_t>& out);

} // namespace GuardCrypto
