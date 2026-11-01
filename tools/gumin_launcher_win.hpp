#pragma once
#include <atomic>
#include <cstdint>
#include <string>
#include <vector>

// ランチャーの Windows の部分（パスはすべて UTF-8）
namespace LauncherWin {

enum class PickKind { License, Songs };
// ファイルを選ぶ窓（owner はウィンドウのハンドル）。選ばなければ空
std::vector<std::string> PickFiles(void* owner, PickKind kind);
// プログラムを起動する（待たない）
bool Launch(const std::string& exe, const std::string& arguments, const std::string& workDir);
// エクスプローラーで開く（フォルダ）、またはそのプログラムを開く
void OpenWithShell(const std::string& path, const std::string& workDir);
// 窓を出さずに実行して、終わるまで待つ。成功（終了コード 0）なら true
bool RunHidden(const std::string& command);
// TJA の中の文字（UTF-8 か Shift-JIS の並び）を UTF-8 にする
std::string BytesToUtf8(const std::string& bytes);

// URL（http / https）のファイルを dest に保存する。bytes に受け取ったバイト数を足していく。cancel が true になったらやめる。失敗なら error に理由
bool Download(const std::string& url, const std::string& dest, std::atomic<uint64_t>* bytes, const std::atomic<bool>* cancel, std::string& error);
// その名前（"GuminTaiko.exe" など）のプログラムが動いているか
bool IsProgramRunning(const std::string& exeName);

} // namespace LauncherWin
