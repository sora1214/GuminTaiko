// ランチャーの Windows の部分（ファイルを選ぶ窓・プロセスの起動・エクスプローラーで開く）
// Windows のヘッダーは raylib.h と名前がぶつかるので、raylib を読み込まないこのファイルにまとめる
#include "gumin_launcher_win.hpp"

#include <windows.h>
#include <commdlg.h>
#include <shellapi.h>
#include <tlhelp32.h>
#include <winhttp.h>

#include <algorithm>
#include <cstdio>
#include <filesystem>

namespace LauncherWin {

namespace {

std::wstring Wide(const std::string& s) {
    if (s.empty()) return {};
    const int size = MultiByteToWideChar(CP_UTF8, 0, s.c_str(), int(s.size()), nullptr, 0);
    std::wstring out(size_t(size), L'\0');
    MultiByteToWideChar(CP_UTF8, 0, s.c_str(), int(s.size()), out.data(), size);
    return out;
}

std::string Narrow(const std::wstring& s) {
    if (s.empty()) return {};
    const int size = WideCharToMultiByte(CP_UTF8, 0, s.c_str(), int(s.size()), nullptr, 0, nullptr, nullptr);
    std::string out(size_t(size), '\0');
    WideCharToMultiByte(CP_UTF8, 0, s.c_str(), int(s.size()), out.data(), size, nullptr, nullptr);
    return out;
}

} // namespace

std::vector<std::string> PickFiles(void* owner, PickKind kind) {
    const wchar_t* filter = kind == PickKind::License ? L"証明書 (license.cert)\0*.cert;*.*\0\0" : L"曲 (*.tja;*.zip)\0*.tja;*.zip\0\0";
    const bool multiple = kind == PickKind::Songs;
    std::vector<wchar_t> buffer(64 * 1024, L'\0');
    OPENFILENAMEW ofn{};
    ofn.lStructSize = sizeof(ofn);
    ofn.hwndOwner = static_cast<HWND>(owner);
    ofn.lpstrFilter = filter;
    ofn.lpstrFile = buffer.data();
    ofn.nMaxFile = DWORD(buffer.size());
    ofn.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_EXPLORER | OFN_NOCHANGEDIR | (multiple ? OFN_ALLOWMULTISELECT : 0);
    std::vector<std::string> out;
    if (!GetOpenFileNameW(&ofn)) return out;
    // 複数: 「フォルダ\0ファイル\0ファイル\0\0」、1つ: 「パス\0」
    const wchar_t* p = buffer.data();
    const std::wstring first = p;
    p += first.size() + 1;
    if (*p == L'\0') {
        out.push_back(Narrow(first));
    } else {
        while (*p != L'\0') {
            const std::wstring name = p;
            out.push_back(Narrow((std::filesystem::path(first) / name).wstring()));
            p += name.size() + 1;
        }
    }
    return out;
}

bool Launch(const std::string& exe, const std::string& arguments, const std::string& workDir) {
    std::wstring command = L"\"" + Wide(exe) + L"\"";
    if (!arguments.empty()) command += L" " + Wide(arguments);
    STARTUPINFOW si{};
    si.cb = sizeof(si);
    PROCESS_INFORMATION pi{};
    const std::wstring dir = Wide(workDir);
    if (!CreateProcessW(nullptr, command.data(), nullptr, nullptr, FALSE, 0, nullptr, dir.empty() ? nullptr : dir.c_str(), &si, &pi)) {
        return false;
    }
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    return true;
}

void OpenWithShell(const std::string& path, const std::string& workDir) {
    const std::wstring dir = Wide(workDir);
    ShellExecuteW(nullptr, L"open", Wide(path).c_str(), nullptr, dir.empty() ? nullptr : dir.c_str(), SW_SHOWNORMAL);
}

bool RunHidden(const std::string& command) {
    STARTUPINFOW si{};
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_HIDE;
    PROCESS_INFORMATION pi{};
    std::wstring wide = Wide(command);
    if (!CreateProcessW(nullptr, wide.data(), nullptr, nullptr, FALSE, CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi)) return false;
    WaitForSingleObject(pi.hProcess, 10 * 60 * 1000);
    DWORD code = 1;
    GetExitCodeProcess(pi.hProcess, &code);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    return code == 0;
}

std::string BytesToUtf8(const std::string& bytes) {
    int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, bytes.c_str(), int(bytes.size()), nullptr, 0);
    UINT codePage = CP_UTF8;
    if (size <= 0) {
        codePage = 932;   // Shift-JIS
        size = MultiByteToWideChar(codePage, 0, bytes.c_str(), int(bytes.size()), nullptr, 0);
    }
    std::wstring out(size_t(std::max(size, 0)), L'\0');
    if (size > 0) MultiByteToWideChar(codePage, 0, bytes.c_str(), int(bytes.size()), out.data(), size);
    return Narrow(out);
}

bool Download(const std::string& url, const std::string& dest, std::atomic<uint64_t>* bytes, const std::atomic<bool>* cancel, std::string& error) {
    const std::wstring wideUrl = Wide(url);
    URL_COMPONENTS parts{};
    parts.dwStructSize = sizeof(parts);
    wchar_t host[256] = {}, path[4096] = {};
    parts.lpszHostName = host;
    parts.dwHostNameLength = DWORD(sizeof(host) / sizeof(host[0]));
    parts.lpszUrlPath = path;
    parts.dwUrlPathLength = DWORD(sizeof(path) / sizeof(path[0]));
    if (!WinHttpCrackUrl(wideUrl.c_str(), 0, 0, &parts)) {
        error = "URL がちがいます: " + url;
        return false;
    }
    HINTERNET session = WinHttpOpen(L"GuminTaikoLauncher/1.0", WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, nullptr, nullptr, 0);
    if (!session) {
        error = "通信を始められません";
        return false;
    }
    HINTERNET connection = WinHttpConnect(session, host, parts.nPort, 0);
    HINTERNET request = connection ? WinHttpOpenRequest(connection, L"GET", path, nullptr, WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES,
                                                        parts.nScheme == INTERNET_SCHEME_HTTPS ? WINHTTP_FLAG_SECURE : 0)
                                  : nullptr;
    bool ok = false;
    FILE* file = nullptr;
    if (request && WinHttpSendRequest(request, WINHTTP_NO_ADDITIONAL_HEADERS, 0, WINHTTP_NO_REQUEST_DATA, 0, 0, 0) &&
        WinHttpReceiveResponse(request, nullptr)) {
        DWORD status = 0, size = sizeof(status);
        WinHttpQueryHeaders(request, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER, WINHTTP_HEADER_NAME_BY_INDEX, &status, &size,
                            WINHTTP_NO_HEADER_INDEX);
        if (status != 200) {
            error = "サーバーが " + std::to_string(status) + " を返しました: " + url;
        } else {
            file = _wfopen(Wide(dest).c_str(), L"wb");
            if (!file) {
                error = "保存できません: " + dest;
            } else {
                std::vector<char> buffer(256 * 1024);
                ok = true;
                for (;;) {
                    if (cancel && cancel->load()) {
                        error = "中止しました";
                        ok = false;
                        break;
                    }
                    DWORD got = 0;
                    if (!WinHttpReadData(request, buffer.data(), DWORD(buffer.size()), &got)) {
                        error = "受け取りに失敗しました: " + url;
                        ok = false;
                        break;
                    }
                    if (got == 0) break;
                    if (std::fwrite(buffer.data(), 1, got, file) != got) {
                        error = "書き込みに失敗しました（空き容量を確かめてください）";
                        ok = false;
                        break;
                    }
                    if (bytes) *bytes += got;
                }
            }
        }
    } else if (error.empty()) {
        error = "つながりません: " + url;
    }
    if (file) std::fclose(file);
    if (request) WinHttpCloseHandle(request);
    if (connection) WinHttpCloseHandle(connection);
    WinHttpCloseHandle(session);
    return ok;
}

bool IsProgramRunning(const std::string& exeName) {
    const std::wstring name = Wide(exeName);
    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snapshot == INVALID_HANDLE_VALUE) return false;
    PROCESSENTRY32W entry{};
    entry.dwSize = sizeof(entry);
    bool found = false;
    for (BOOL more = Process32FirstW(snapshot, &entry); more; more = Process32NextW(snapshot, &entry)) {
        if (_wcsicmp(entry.szExeFile, name.c_str()) == 0) {
            found = true;
            break;
        }
    }
    CloseHandle(snapshot);
    return found;
}

} // namespace LauncherWin
