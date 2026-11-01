#pragma once
#include <map>
#include <string>
#include <vector>

// Data/x64/datatable/*.bin（gzip 圧縮された JSON: {"items":[{...}, ...]}）の読み込み
namespace DataTable {

// gzip を展開する。失敗したら空文字列
std::string Gunzip(const unsigned char* data, int size);

// pos の位置にある JSON 文字列（先頭の " を含む）を読み、pos を閉じ " の次へ進める
std::string ReadJsonString(const std::string& json, size_t& pos);

// 1件分の値（文字列はそのまま、数値と真偽値は書かれた文字のまま）
struct Item {
    std::map<std::string, std::string> values;

    const std::string& Text(const std::string& key) const;
    int Int(const std::string& key, int fallback = 0) const;
    bool Bool(const std::string& key) const { return Text(key) == "true"; }
};

// items の各要素（入れ子のない平らなオブジェクト）を読む。読めなければ空
std::vector<Item> Load(const std::string& path);

} // namespace DataTable
