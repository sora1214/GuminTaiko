#include "TestMenu.hpp"

#include <cctype>
#include <cstdlib>
#include <fstream>
#include <iterator>

namespace TestMenu {

namespace {

constexpr const char* kPath = "Data/x64/testmode/TestMode.xml";

class XmlReader {
public:
    explicit XmlReader(const std::string& text) : s_(text) {}

    std::unique_ptr<XmlNode> ParseDocument() {
        auto root = std::make_unique<XmlNode>();
        root->name = "#document";
        ParseChildren(*root, "");
        return root;
    }

private:
    void SkipSpace() {
        while (pos_ < s_.size() && std::isspace(static_cast<unsigned char>(s_[pos_]))) ++pos_;
    }
    bool StartsWith(const char* token) const { return s_.compare(pos_, std::char_traits<char>::length(token), token) == 0; }

    // 閉じタグ（</name>）まで子を読む
    void ParseChildren(XmlNode& parent, const std::string& closeName) {
        while (pos_ < s_.size()) {
            const size_t lt = s_.find('<', pos_);
            if (lt == std::string::npos) {
                pos_ = s_.size();
                return;
            }
            pos_ = lt;
            if (StartsWith("<!--")) {
                const size_t end = s_.find("-->", pos_);
                pos_ = end == std::string::npos ? s_.size() : end + 3;
            } else if (StartsWith("<?") || StartsWith("<!")) {
                const size_t end = s_.find('>', pos_);
                pos_ = end == std::string::npos ? s_.size() : end + 1;
            } else if (StartsWith("</")) {
                const size_t end = s_.find('>', pos_);
                pos_ = end == std::string::npos ? s_.size() : end + 1;
                (void)closeName;
                return;
            } else {
                parent.children.push_back(ParseElement());
            }
        }
    }

    std::unique_ptr<XmlNode> ParseElement() {
        auto node = std::make_unique<XmlNode>();
        ++pos_;   // '<'
        const size_t nameStart = pos_;
        while (pos_ < s_.size() && !std::isspace(static_cast<unsigned char>(s_[pos_])) && s_[pos_] != '>' && s_[pos_] != '/') ++pos_;
        node->name = s_.substr(nameStart, pos_ - nameStart);
        for (;;) {
            SkipSpace();
            if (pos_ >= s_.size()) return node;
            if (s_[pos_] == '/') {   // 自己終了
                const size_t end = s_.find('>', pos_);
                pos_ = end == std::string::npos ? s_.size() : end + 1;
                return node;
            }
            if (s_[pos_] == '>') {
                ++pos_;
                ParseChildren(*node, node->name);
                return node;
            }
            const size_t keyStart = pos_;
            while (pos_ < s_.size() && s_[pos_] != '=' && !std::isspace(static_cast<unsigned char>(s_[pos_])) && s_[pos_] != '>' &&
                   s_[pos_] != '/')
                ++pos_;
            const std::string key = s_.substr(keyStart, pos_ - keyStart);
            SkipSpace();
            std::string value;
            if (pos_ < s_.size() && s_[pos_] == '=') {
                ++pos_;
                SkipSpace();
                if (pos_ < s_.size() && (s_[pos_] == '"' || s_[pos_] == '\'')) {
                    const char quote = s_[pos_++];
                    const size_t end = s_.find(quote, pos_);
                    value = s_.substr(pos_, (end == std::string::npos ? s_.size() : end) - pos_);
                    pos_ = end == std::string::npos ? s_.size() : end + 1;
                }
            }
            if (!key.empty()) node->attrs[key] = Unescape(value);
        }
    }

    static std::string Unescape(const std::string& v) {
        std::string out;
        for (size_t i = 0; i < v.size(); ++i) {
            if (v[i] == '&') {
                static const std::pair<const char*, char> kEntities[] = {{"&amp;", '&'}, {"&lt;", '<'}, {"&gt;", '>'}, {"&quot;", '"'}, {"&apos;", '\''}};
                bool replaced = false;
                for (const auto& e : kEntities) {
                    const size_t len = std::char_traits<char>::length(e.first);
                    if (v.compare(i, len, e.first) == 0) {
                        out += e.second;
                        i += len - 1;
                        replaced = true;
                        break;
                    }
                }
                if (replaced) continue;
            }
            // 属性の中の改行と字下げ（replace-text が複数行に書かれている）はつなげる
            if (v[i] == '\r' || v[i] == '\n' || v[i] == '\t') continue;
            out += v[i];
        }
        return out;
    }

    const std::string& s_;
    size_t pos_ = 0;
};

// このゲームだけの設定（TestMode.xml にはない）。トップメニューの「ＧＵＭＩＮ ＳＥＴＴＩＮＧＳ」から開く
const char* const kGuminMenuXml = R"(<root>
    <menu id="GuminSettingsMenu">
        <layout type="Header">
            <break-item/>
            <text-item label="   　　ＧＵＭＩＮ ＳＥＴＴＩＮＧＳ"/> <break-item/>
            <break-item/>
            <data-item data="HeaderTextData" param-offset-x="-15"/> <break-item/>
        </layout>
        <layout type="Center" padding-x="23">
            <select-item label="ＳＯＮＧ ＳＥＬＥＣＴ ＴＩＭＥＲ" param-offset-x="28" replace-text="0:ＯＦＦ, 1:ＯＮ" group="Setting" id="GuminSongSelectTimerItem" max="1" min="0" default="1"/> <break-item/>
            <select-item label="ＪＵＤＧＥ ＳＴＲＩＣＴＮＥＳＳ" param-offset-x="28" replace-text="0:ＶＥＲＹ ＥＡＳＹ, 1:ＥＡＳＹ, 2:ＮＯＲＭＡＬ, 3:ＨＡＲＤ, 4:ＶＥＲＹ ＨＡＲＤ" group="Setting" id="GuminJudgeStrictnessItem" max="4" min="0" default="2"/> <break-item/>
            <break-item/>
            <menu-item label="ＥＸＩＴ" menu="TopMenu"/> <break-item/>
        </layout>
        <layout type="Footer">
            <data-item data="FooterTextData" param-offset-x="-20"/>
        </layout>
    </menu>
</root>)";

constexpr int kMaxStages = 999;   // 1クレジットで遊べる曲数の上限（本家は 4）

const XmlNode* FindRoot(const XmlNode& doc) {
    for (const auto& child : doc.children) {
        if (child->name == "root") return child.get();
    }
    return nullptr;
}

void AddMenus(const XmlNode& root, Definition& def) {
    for (const auto& node : root.children) {
        if (node->name == "text-data") {
            def.textData[node->Attr("id")] = node->Attr("data");
        } else if (node->name == "menu") {
            Menu menu;
            menu.id = node->Attr("id");
            menu.attrs = node->attrs;
            for (const auto& layoutNode : node->children) {
                if (layoutNode->name != "layout") continue;
                Layout layout;
                layout.type = layoutNode->Attr("type");
                layout.paddingX = std::atoi(layoutNode->Attr("padding-x", "0").c_str());
                for (const auto& itemNode : layoutNode->children) {
                    Item item;
                    item.type = itemNode->name;
                    item.attrs = itemNode->attrs;
                    layout.items.push_back(std::move(item));
                }
                menu.layouts.push_back(std::move(layout));
            }
            def.menus[menu.id] = std::move(menu);
        }
    }
}

Definition Load() {
    Definition def;
    std::ifstream ifs(kPath, std::ios::binary);
    if (!ifs) return def;
    std::string text((std::istreambuf_iterator<char>(ifs)), std::istreambuf_iterator<char>());
    auto doc = ParseXml(text);
    const XmlNode* root = FindRoot(*doc);
    if (!root) return def;

    def.width = std::atoi(root->Attr("width", "96").c_str());
    def.height = std::atoi(root->Attr("height", "30").c_str());
    def.topMenu = root->Attr("top-menu", "TopMenu");
    def.testSwOffMenu = root->Attr("test-sw-off-menu");
    AddMenus(*root, def);
    auto gumin = ParseXml(kGuminMenuXml);
    if (const XmlNode* guminRoot = FindRoot(*gumin)) AddMenus(*guminRoot, def);
    // このゲームだけの変更: 1クレジットで遊べる曲数（NUMBER OF STAGE(S)）を 4 曲から 999 曲まで選べるようにする
    for (auto& entry : def.menus) {
        for (Layout& layout : entry.second.layouts) {
            for (Item& item : layout.items) {
                if (item.Attr("id") != "NumberOfStageItem") continue;
                item.attrs["max"] = std::to_string(kMaxStages);
                item.attrs["format"] = "%3d";
            }
        }
    }
    def.loaded = true;
    return def;
}

} // namespace

std::unique_ptr<XmlNode> ParseXml(const std::string& text) {
    std::string body = text;
    if (body.size() >= 3 && static_cast<unsigned char>(body[0]) == 0xEF && static_cast<unsigned char>(body[1]) == 0xBB &&
        static_cast<unsigned char>(body[2]) == 0xBF) {
        body.erase(0, 3);
    }
    return XmlReader(body).ParseDocument();
}

int Item::Int(const std::string& key, int fallback) const {
    auto found = attrs.find(key);
    return found != attrs.end() && !found->second.empty() ? std::atoi(found->second.c_str()) : fallback;
}

std::vector<const Item*> Definition::SettingItems() const {
    std::vector<const Item*> out;
    for (const auto& entry : menus) {
        for (const Layout& layout : entry.second.layouts) {
            for (const Item& item : layout.items) {
                if (item.Attr("group") == "Setting" && item.Has("id")) out.push_back(&item);
            }
        }
    }
    return out;
}

const Definition& Get() {
    static const Definition def = Load();
    return def;
}

} // namespace TestMenu
