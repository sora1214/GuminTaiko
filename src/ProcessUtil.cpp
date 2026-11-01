// Windows の API を使うので raylib.h は読まない（名前がぶつかる）
#include "ProcessUtil.hpp"

#include <vector>

#include <windows.h>
#include <shlobj.h>

std::string DesktopFolder() {
    PWSTR path = nullptr;
    std::string out;
    if (SUCCEEDED(SHGetKnownFolderPath(FOLDERID_Desktop, 0, nullptr, &path))) {
        const int size = WideCharToMultiByte(CP_UTF8, 0, path, -1, nullptr, 0, nullptr, nullptr);
        std::vector<char> buf(static_cast<size_t>(size));
        WideCharToMultiByte(CP_UTF8, 0, path, -1, buf.data(), size, nullptr, nullptr);
        out = buf.data();
    }
    CoTaskMemFree(path);
    return out;
}

int RunHidden(const std::string& command) {
    const std::string line = "cmd.exe /c \"" + command + "\"";
    const int size = MultiByteToWideChar(CP_UTF8, 0, line.c_str(), -1, nullptr, 0);
    std::vector<wchar_t> wide(static_cast<size_t>(size));
    MultiByteToWideChar(CP_UTF8, 0, line.c_str(), -1, wide.data(), size);

    STARTUPINFOW si{};
    si.cb = sizeof(si);
    PROCESS_INFORMATION pi{};
    if (!CreateProcessW(nullptr, wide.data(), nullptr, nullptr, FALSE, CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi)) return -1;
    WaitForSingleObject(pi.hProcess, INFINITE);
    DWORD code = 1;
    GetExitCodeProcess(pi.hProcess, &code);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    return int(code);
}
