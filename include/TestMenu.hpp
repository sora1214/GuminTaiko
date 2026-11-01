#pragma once
#include <map>
#include <memory>
#include <string>
#include <vector>

// テストモードのメニュー定義（Data/x64/testmode/TestMode.xml）
//   <root width="96" height="30" top-menu=... test-sw-off-menu=...>
//     <menu id=...> <layout type="Header|Center|Footer" padding-x=...> 項目... </layout> </menu>
//     <text-data id=... data=.../>
//   項目: text-item / menu-item / select-item / cmd-item / toggle-item / digit-item / data-item /
//         date-item / time-item / ipv4-item / set-clock-item / msg-item / break-item（改行）
// 属性はそのまま文字列で持ち、意味づけはテストモード画面（TestModeScene）と設定（GameSettings）がする。
namespace TestMenu {

// このゲームだけの設定のメニュー（TestMode.xml にはなく、TestMenu.cpp に書いてある）
constexpr const char* kGuminSettingsMenu = "GuminSettingsMenu";
constexpr const char* kSongSelectTimerItem = "GuminSongSelectTimerItem";   // 選曲画面のタイマー（0: ＯＦＦ 1: ＯＮ）
// 判定の厳しさ（0: ＶＥＲＹ ＥＡＳＹ 1: ＥＡＳＹ 2: ＮＯＲＭＡＬ（本家どおり）3: ＨＡＲＤ 4: ＶＥＲＹ ＨＡＲＤ）
constexpr const char* kJudgeStrictnessItem = "GuminJudgeStrictnessItem";

struct XmlNode {
    std::string name;
    std::map<std::string, std::string> attrs;
    std::vector<std::unique_ptr<XmlNode>> children;

    std::string Attr(const std::string& key, const std::string& fallback = "") const {
        auto found = attrs.find(key);
        return found != attrs.end() ? found->second : fallback;
    }
    bool Has(const std::string& key) const { return attrs.count(key) != 0; }
};

// 小さな XML 読み込み（要素・属性・コメント・自己終了タグだけ。本文の文字は読まない）
std::unique_ptr<XmlNode> ParseXml(const std::string& text);

struct Item {
    std::string type;                 // "text-item" など（"break-item" は改行）
    std::map<std::string, std::string> attrs;
    std::string Attr(const std::string& key, const std::string& fallback = "") const {
        auto found = attrs.find(key);
        return found != attrs.end() ? found->second : fallback;
    }
    bool Has(const std::string& key) const { return attrs.count(key) != 0; }
    int Int(const std::string& key, int fallback = 0) const;
};

struct Layout {
    std::string type;                 // Header / Center / Footer（なしもある）
    int paddingX = 0;
    std::vector<Item> items;
};

struct Menu {
    std::string id;
    std::map<std::string, std::string> attrs;
    std::vector<Layout> layouts;
    std::string Attr(const std::string& key, const std::string& fallback = "") const {
        auto found = attrs.find(key);
        return found != attrs.end() ? found->second : fallback;
    }
};

struct Definition {
    int width = 96;
    int height = 30;
    std::string topMenu;
    std::string testSwOffMenu;
    std::map<std::string, Menu> menus;
    std::map<std::string, std::string> textData;   // text-data の id → data
    bool loaded = false;

    const Menu* FindMenu(const std::string& id) const {
        auto found = menus.find(id);
        return found != menus.end() ? &found->second : nullptr;
    }
    // group="Setting" の select-item（設定として保存する値）を全メニューから集める
    std::vector<const Item*> SettingItems() const;
};

// 一度だけ読み込んで使い回す
const Definition& Get();

} // namespace TestMenu
