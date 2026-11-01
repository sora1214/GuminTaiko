// Windows の API を使うので raylib.h は読まない（名前がぶつかる）
#include "GuardCrypto.hpp"

#include <windows.h>
#include <bcrypt.h>

namespace GuardCrypto {

namespace {

bool Ok(NTSTATUS status) { return status >= 0; }

std::string Utf8(const std::wstring& w) {
    if (w.empty()) return {};
    const int size = WideCharToMultiByte(CP_UTF8, 0, w.c_str(), int(w.size()), nullptr, 0, nullptr, nullptr);
    std::string out(size_t(size), '\0');
    WideCharToMultiByte(CP_UTF8, 0, w.c_str(), int(w.size()), out.data(), size, nullptr, nullptr);
    return out;
}

// ECDSA P-256 の鍵を blob から読み込む
BCRYPT_KEY_HANDLE ImportKey(BCRYPT_ALG_HANDLE alg, LPCWSTR type, const uint8_t* blob, size_t size) {
    BCRYPT_KEY_HANDLE key = nullptr;
    if (!Ok(BCryptImportKeyPair(alg, nullptr, type, &key, const_cast<PUCHAR>(blob), ULONG(size), 0))) return nullptr;
    return key;
}

} // namespace

// アルゴリズムを開くのは重い（ファイルごとに開くと 2 万ファイルで十数秒かかる）ので、1回開いて使い回す。
// 開いたアルゴリズムはスレッドをまたいで使える
static BCRYPT_ALG_HANDLE Sha256Algorithm() {
    static BCRYPT_ALG_HANDLE alg = [] {
        BCRYPT_ALG_HANDLE handle = nullptr;
        if (!Ok(BCryptOpenAlgorithmProvider(&handle, BCRYPT_SHA256_ALGORITHM, nullptr, 0))) handle = nullptr;
        return handle;
    }();
    return alg;
}

Sha256::Sha256() {
    BCRYPT_HASH_HANDLE hash = nullptr;
    if (BCRYPT_ALG_HANDLE alg = Sha256Algorithm(); alg && Ok(BCryptCreateHash(alg, &hash, nullptr, 0, nullptr, 0, 0))) hash_ = hash;
}

Sha256::~Sha256() {
    if (hash_) BCryptDestroyHash(static_cast<BCRYPT_HASH_HANDLE>(hash_));
}

void Sha256::Update(const void* data, size_t size) {
    if (!hash_ || size == 0) return;
    BCryptHashData(static_cast<BCRYPT_HASH_HANDLE>(hash_), static_cast<PUCHAR>(const_cast<void*>(data)), ULONG(size), 0);
}

Digest Sha256::Finish() {
    Digest digest{};
    if (hash_) BCryptFinishHash(static_cast<BCRYPT_HASH_HANDLE>(hash_), digest.data(), ULONG(digest.size()), 0);
    return digest;
}

Digest Hash(const std::string& data) {
    Sha256 sha;
    sha.Update(data.data(), data.size());
    return sha.Finish();
}

bool GenerateKey(std::vector<uint8_t>& privateBlob, std::vector<uint8_t>& publicBlob) {
    BCRYPT_ALG_HANDLE alg = nullptr;
    if (!Ok(BCryptOpenAlgorithmProvider(&alg, BCRYPT_ECDSA_P256_ALGORITHM, nullptr, 0))) return false;
    BCRYPT_KEY_HANDLE key = nullptr;
    bool ok = Ok(BCryptGenerateKeyPair(alg, &key, 256, 0)) && Ok(BCryptFinalizeKeyPair(key, 0));
    auto exportBlob = [&](LPCWSTR type, std::vector<uint8_t>& out) {
        ULONG size = 0;
        if (!Ok(BCryptExportKey(key, nullptr, type, nullptr, 0, &size, 0))) return false;
        out.resize(size);
        return Ok(BCryptExportKey(key, nullptr, type, out.data(), size, &size, 0));
    };
    ok = ok && exportBlob(BCRYPT_ECCPRIVATE_BLOB, privateBlob) && exportBlob(BCRYPT_ECCPUBLIC_BLOB, publicBlob);
    if (key) BCryptDestroyKey(key);
    BCryptCloseAlgorithmProvider(alg, 0);
    return ok;
}

bool Sign(const std::vector<uint8_t>& privateBlob, const std::string& message, std::vector<uint8_t>& signature) {
    BCRYPT_ALG_HANDLE alg = nullptr;
    if (!Ok(BCryptOpenAlgorithmProvider(&alg, BCRYPT_ECDSA_P256_ALGORITHM, nullptr, 0))) return false;
    bool ok = false;
    if (BCRYPT_KEY_HANDLE key = ImportKey(alg, BCRYPT_ECCPRIVATE_BLOB, privateBlob.data(), privateBlob.size())) {
        Digest digest = Hash(message);
        ULONG size = 0;
        if (Ok(BCryptSignHash(key, nullptr, digest.data(), ULONG(digest.size()), nullptr, 0, &size, 0))) {
            signature.resize(size);
            ok = Ok(BCryptSignHash(key, nullptr, digest.data(), ULONG(digest.size()), signature.data(), size, &size, 0));
        }
        BCryptDestroyKey(key);
    }
    BCryptCloseAlgorithmProvider(alg, 0);
    return ok;
}

bool Verify(const uint8_t* publicBlob, size_t publicSize, const std::string& message, const std::vector<uint8_t>& signature) {
    if (!publicBlob || publicSize == 0 || signature.empty()) return false;
    BCRYPT_ALG_HANDLE alg = nullptr;
    if (!Ok(BCryptOpenAlgorithmProvider(&alg, BCRYPT_ECDSA_P256_ALGORITHM, nullptr, 0))) return false;
    bool ok = false;
    if (BCRYPT_KEY_HANDLE key = ImportKey(alg, BCRYPT_ECCPUBLIC_BLOB, publicBlob, publicSize)) {
        Digest digest = Hash(message);
        ok = Ok(BCryptVerifySignature(key, nullptr, digest.data(), ULONG(digest.size()), const_cast<PUCHAR>(signature.data()),
                                      ULONG(signature.size()), 0));
        BCryptDestroyKey(key);
    }
    BCryptCloseAlgorithmProvider(alg, 0);
    return ok;
}

std::string MachineId() {
    wchar_t value[128] = {};
    DWORD size = sizeof(value);
    if (RegGetValueW(HKEY_LOCAL_MACHINE, L"SOFTWARE\\Microsoft\\Cryptography", L"MachineGuid", RRF_RT_REG_SZ | RRF_SUBKEY_WOW6464KEY,
                     nullptr, value, &size) != ERROR_SUCCESS) {
        return {};
    }
    return Utf8(value);
}

std::string ToHex(const uint8_t* data, size_t size) {
    static const char kDigits[] = "0123456789abcdef";
    std::string out;
    out.reserve(size * 2);
    for (size_t i = 0; i < size; ++i) {
        out += kDigits[data[i] >> 4];
        out += kDigits[data[i] & 15];
    }
    return out;
}

bool FromHex(const std::string& hex, std::vector<uint8_t>& out) {
    if (hex.size() % 2 != 0) return false;
    auto nibble = [](char c) {
        if (c >= '0' && c <= '9') return c - '0';
        if (c >= 'a' && c <= 'f') return c - 'a' + 10;
        if (c >= 'A' && c <= 'F') return c - 'A' + 10;
        return -1;
    };
    out.clear();
    for (size_t i = 0; i < hex.size(); i += 2) {
        const int hi = nibble(hex[i]), lo = nibble(hex[i + 1]);
        if (hi < 0 || lo < 0) return false;
        out.push_back(uint8_t(hi * 16 + lo));
    }
    return true;
}

} // namespace GuardCrypto
