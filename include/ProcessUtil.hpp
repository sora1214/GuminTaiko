#pragma once
#include <string>

// コマンドを窓を出さずに実行して終わるまで待つ（cmd.exe /c で。std::system と違いコンソールの窓が一瞬出ない）。
// 戻り値は終了コード（起動できなければ -1）
int RunHidden(const std::string& command);

// デスクトップのフォルダ（UTF-8。OneDrive に移したデスクトップにも対応）。わからなければ空
std::string DesktopFolder();
