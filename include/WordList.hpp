#pragma once
#include <map>
#include <string>

// 画面に出す文言の表（Data/x64/datatable/wordlist.bin = gzip 圧縮された JSON）
// Lumen の SetText に渡されるキーを日本語の文言に変換する。
// "user_name_p1" のようにゲーム中に変わる文言は Set で登録する。
class WordList {
public:
    static WordList& Get() {
        static WordList instance;
        return instance;
    }

    // キーに対応する文言。見つからなければキーをそのまま返す
    const std::string& Text(const std::string& key);

    // 動的な文言を登録する（wordlist.bin より優先）
    void Set(const std::string& key, const std::string& text) { overrides_[key] = text; }

private:
    WordList() = default;
    void Load();

    bool loaded_ = false;
    std::map<std::string, std::string> words_;
    std::map<std::string, std::string> overrides_;
};
