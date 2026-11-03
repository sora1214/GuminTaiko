#include "TestModeScene.hpp"

#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstdio>
#include <ctime>
#include <memory>

#include "AttractScene.hpp"
#include "GameFont.hpp"
#include "GameSettings.hpp"
#include "LoadingScene.hpp"
#include "PlayData.hpp"
#include "SceneManager.hpp"
#include "SoundManager.hpp"
#include "TaikoInput.hpp"

using TestMenu::Item;

namespace {

constexpr float kFontSize = 24.0f;
constexpr float kBlinkPeriod = 0.5f;
constexpr float kCommandSeconds = 1.0f;   // cmd-item の「実行中」の表示時間
const Color kLime{0, 255, 0, 255};
const Color kGray{128, 128, 128, 255};
constexpr int kFastRepeat = 20;   // 値を変えるキーをこの回数繰り返したら（約1秒）10 ずつ変える
constexpr int kFastStep = 10;
constexpr int kFastRange = 100;   // 10 ずつ変えるのは、選べる幅がこれ以上の値だけ
constexpr const char* kKeyConfigMenu = "@KeyConfig";   // KEY CONFIG の項目の menu（TestMode.xml にはない）

// 半角の英数字・記号を全角に（テストモードの文字盤の文字にそろえる）
std::string Wide(const std::string& text) {
    std::string out;
    for (unsigned char c : text) {
        if (c == ' ') {
            out += "\xE3\x80\x80";   // 全角スペース
        } else if (c >= 0x21 && c <= 0x7E) {
            const int cp = 0xFF01 + (c - 0x21);
            out += char(0xE0 | (cp >> 12));
            out += char(0x80 | ((cp >> 6) & 0x3F));
            out += char(0x80 | (cp & 0x3F));
        } else {
            out += char(c);
        }
    }
    return out;
}

// UTF-8 を1文字ずつ
std::vector<int> Codepoints(const std::string& text) {
    std::vector<int> out;
    int count = 0;
    int* cps = LoadCodepoints(text.c_str(), &count);
    out.assign(cps, cps + count);
    UnloadCodepoints(cps);
    return out;
}

// 1文字が何マスか。テストモードの文字盤は全角も半角も1マス（TestMode.xml の param-offset-x がこれで重ならずにそろう）
int Cells(int codepoint) {
    (void)codepoint;
    return 1;
}

std::string Trim(const std::string& s) {
    size_t b = 0, e = s.size();
    while (b < e && (s[b] == ' ' || s[b] == '\t')) ++b;
    while (e > b && (s[e - 1] == ' ' || s[e - 1] == '\t')) --e;
    return s.substr(b, e - b);
}

// 印（@Color/Red; など）を除いたマス数
int TextCells(const std::string& text) {
    int cells = 0;
    size_t i = 0;
    std::string plain;
    while (i < text.size()) {
        if (text[i] == '@') {
            const size_t semi = text.find(';', i);
            if (semi != std::string::npos) {
                i = semi + 1;
                continue;
            }
        }
        plain += text[i++];
    }
    for (int cp : Codepoints(plain)) cells += Cells(cp);
    return cells;
}

Color NamedColor(const std::string& name, Color fallback) {
    if (name == "Color/Red") return RED;
    if (name == "Color/White") return WHITE;
    if (name == "Color/Lime") return kLime;
    if (name == "Color/Gray") return kGray;
    return fallback;
}

// replace-text（"0:ＯＦＦ, 1:ＯＮ"）
bool ReplaceText(const Item& item, int value, std::string& out) {
    const std::string text = item.Attr("replace-text");
    if (text.empty()) return false;
    size_t start = 0;
    while (start <= text.size()) {
        size_t end = text.find(',', start);
        // 値の中の「,」は印の中にしか出ないので、次の「数字:」までを1つとみなす
        while (end != std::string::npos) {
            const std::string rest = Trim(text.substr(end + 1));
            const size_t colon = rest.find(':');
            bool numeric = colon != std::string::npos && colon > 0;
            for (size_t k = 0; numeric && k < colon; ++k) numeric = std::isdigit(static_cast<unsigned char>(rest[k])) || rest[k] == '-';
            if (numeric) break;
            end = text.find(',', end + 1);
        }
        const std::string entry = Trim(text.substr(start, end == std::string::npos ? std::string::npos : end - start));
        const size_t colon = entry.find(':');
        if (colon != std::string::npos && std::atoi(entry.substr(0, colon).c_str()) == value) {
            out = entry.substr(colon + 1);
            return true;
        }
        if (end == std::string::npos) break;
        start = end + 1;
    }
    return false;
}

std::vector<std::string> SplitCommandText(const std::string& text) {
    std::vector<std::string> out;
    size_t start = 0;
    while (start <= text.size()) {
        const size_t end = text.find(',', start);
        out.push_back(text.substr(start, end == std::string::npos ? std::string::npos : end - start));
        if (end == std::string::npos) break;
        start = end + 1;
    }
    return out;
}

std::string FormatSeconds(double seconds) {
    const long long s = (long long)seconds;
    return TextFormat("%lldH %02lldM %02lldS", s / 3600, (s / 60) % 60, s % 60);
}

std::string NowText() {
    const std::time_t now = std::time(nullptr);
    std::tm tm{};
    localtime_s(&tm, &now);
    return TextFormat("%04d/%02d/%02d %02d:%02d:%02d", tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday, tm.tm_hour, tm.tm_min, tm.tm_sec);
}

bool IsInteractive(const std::string& type) {
    return type == "menu-item" || type == "select-item" || type == "cmd-item" || type == "toggle-item" || type == "digit-item" ||
           type == "msg-item" || type == "set-clock-item";
}

} // namespace

void TestModeScene::Initialize() {
    active_ = true;
    def_ = &TestMenu::Get();
    SoundManager::Get().StopAll();
    GameSettings::Get().SetAttract(false);
    cellW_ = 1920.0f / float(std::max(1, def_->width));
    cellH_ = 1080.0f / float(std::max(1, def_->height));
    OpenMenu(def_->topMenu);
}

void TestModeScene::Finalize() {
    active_ = false;
    GameSettings::Get().Save();
}

// ===========================================================================
// メニューの組み立て
// ===========================================================================
void TestModeScene::OpenMenu(const std::string& id, const std::string& focusId) {
    const TestMenu::Menu* menu = def_->FindMenu(id);
    if (!menu) return;
    const std::string previous = menu_ ? menu_->id : "";
    // 親のメニューへ戻るときだけ、出てきたメニューの項目にカーソルを置く（進むときは最初の項目）
    const bool back = !previous.empty() && parentOf_.count(previous) && parentOf_[previous] == id;
    if (!back && !previous.empty() && previous != id) parentOf_[id] = previous;
    menu_ = menu;
    placed_.clear();
    edit_ = Edit::None;

    // 行を数えて置く（Header は上から、Center はその下、Footer は下から）
    int headerRows = 0;
    for (const TestMenu::Layout& layout : menu_->layouts) {
        int rows = 0;
        bool content = false;
        for (const Item& item : layout.items) {
            if (item.type == "break-item") ++rows, content = false;
            else content = true;
        }
        if (content) ++rows;
        const bool footer = layout.type == "Footer";
        int row = layout.type == "Header" ? 0 : footer ? def_->height - rows - 1 : headerRows + 1;
        if (layout.type == "Header") headerRows = rows;
        const bool centered = layout.type == "Header" || footer;

        for (const Item& item : layout.items) {
            if (item.type == "break-item") {
                ++row;
                continue;
            }
            Placed p;
            p.item = &item;
            p.layout = layout.type;
            p.row = row;
            const std::string label = item.Attr("label");
            if (item.type == "data-item") {
                p.col = def_->width / 2 + item.Int("param-offset-x");
            } else if (centered) {
                p.col = std::max(0, (def_->width - TextCells(label)) / 2);
            } else {
                p.col = layout.paddingX;
            }
            p.paramCol = layout.paddingX + item.Int("param-offset-x");
            // 値がラベルに重なるときはラベルの後ろへ
            if (!label.empty() && item.Has("param-offset-x") && item.type != "data-item") {
                p.paramCol = std::max(p.paramCol, p.col + TextCells(label) + 1);
            } else if (label.empty() && item.type != "data-item") {
                p.paramCol = std::max(p.paramCol, p.col);
            }
            placed_.push_back(p);
        }
    }

    // トップメニュー: メニューの最後の項目（ＳＯＦＴＷＡＲＥ ＵＰＤＡＴＥ）の下に「ＫＥＹ ＣＯＮＦＩＧ」と
    // 「ＧＵＭＩＮ ＳＥＴＴＩＮＧＳ」を足し、その下の行をずらす
    if (id == def_->topMenu) {
        keyConfigItem_.type = "menu-item";
        keyConfigItem_.attrs["label"] = "ＫＥＹ ＣＯＮＦＩＧ";
        keyConfigItem_.attrs["menu"] = kKeyConfigMenu;
        guminItem_.type = "menu-item";
        guminItem_.attrs["label"] = "ＧＵＭＩＮ ＳＥＴＴＩＮＧＳ";
        guminItem_.attrs["menu"] = TestMenu::kGuminSettingsMenu;
        for (const Item* extra : {&keyConfigItem_, &guminItem_}) {
            int last = -1;
            for (size_t i = 0; i < placed_.size(); ++i) {
                if (placed_[i].layout == "Center" && placed_[i].item->type == "menu-item") last = int(i);
            }
            if (last < 0) break;
            Placed p = placed_[size_t(last)];
            p.item = extra;
            p.row += 1;
            for (Placed& other : placed_) {
                if (other.layout == "Center" && other.row >= p.row) ++other.row;
            }
            placed_.insert(placed_.begin() + last + 1, p);
        }
    }

    // フォーカス: 指定の項目、なければ戻ってきたメニューへの項目、なければ最初の項目
    cursor_ = -1;
    for (size_t i = 0; i < placed_.size(); ++i) {
        const Item& item = *placed_[i].item;
        if (!focusId.empty() && item.Attr("id") == focusId) cursor_ = int(i);
        if (back && focusId.empty() && cursor_ < 0 && item.type == "menu-item" && item.Attr("menu") == previous && IsSelectable(item, false)) {
            cursor_ = int(i);
        }
    }
    if (cursor_ < 0) cursor_ = FindNext(-1, 1, false);
    if (cursor_ >= 0) Focus(cursor_);
}

bool TestModeScene::IsSelectable(const Item& item, bool includeSkip) const {
    if (!IsInteractive(item.type)) return false;
    if (Flag(item, "invisible") || Flag(item, "disable")) return false;
    if (!includeSkip && Flag(item, "select-skip")) return false;
    return true;
}

int TestModeScene::FindNext(int from, int direction, bool includeSkip) const {
    const int n = int(placed_.size());
    if (n == 0) return -1;
    for (int step = 1; step <= n; ++step) {
        const int i = ((from + direction * step) % n + n) % n;
        if (IsSelectable(*placed_[size_t(i)].item, includeSkip)) return i;
    }
    return -1;
}

void TestModeScene::Focus(int index) {
    cursor_ = index;
    edit_ = Edit::None;
    if (index < 0) return;
    const Item& item = *placed_[size_t(index)].item;
    // auto-enter: 選んだらそのまま値を変え始める
    if (Flag(item, "auto-enter") && (item.type == "select-item" || item.type == "digit-item")) {
        edit_ = Edit::Value;
        editValue_ = CurrentValue(item.Attr("id"));
    }
}

// ===========================================================================
// 値
// ===========================================================================
bool TestModeScene::IsSetting(const Item& item) const { return item.Attr("group") == "Setting"; }

int TestModeScene::CurrentValue(const std::string& id) const {
    // 変更中の値を優先（ほかの項目の表示・非表示がすぐ変わるように）
    if (edit_ == Edit::Value && cursor_ >= 0 && placed_[size_t(cursor_)].item->Attr("id") == id) return editValue_;
    if (GameSettings::Get().Has(id)) return GameSettings::Get().Value(id);
    auto found = temp_.find(id);
    if (found != temp_.end()) return found->second;
    double value = 0.0;
    if (DynamicValue(id, value)) return int(value);
    // 定義にある初期値
    for (const Placed& p : placed_) {
        if (p.item->Attr("id") == id) return p.item->Int("default", 0);
    }
    return 0;
}

// 「True/条件」「False/条件」: 条件が成り立てば前の値、成り立たなければその逆
bool TestModeScene::Flag(const Item& item, const std::string& key) const {
    const std::string v = item.Attr(key);
    if (v.empty()) return false;
    const size_t slash = v.find('/');
    const bool head = v.substr(0, slash) == "True";
    if (slash == std::string::npos) return head;
    return EvalCondition(v.substr(slash + 1)) ? head : !head;
}

// 条件式: 「Id:値」「Id:!値」、and / or、かっこ
bool TestModeScene::EvalCondition(const std::string& expr) const {
    struct Parser {
        const TestModeScene* self;
        std::vector<std::string> tokens;
        size_t pos = 0;
        bool Or() {
            bool v = And();
            while (pos < tokens.size() && tokens[pos] == "or") {
                ++pos;
                v = And() || v;
            }
            return v;
        }
        bool And() {
            bool v = Term();
            while (pos < tokens.size() && tokens[pos] == "and") {
                ++pos;
                v = Term() && v;
            }
            return v;
        }
        bool Term() {
            if (pos >= tokens.size()) return false;
            const std::string t = tokens[pos++];
            if (t == "(") {
                const bool v = Or();
                if (pos < tokens.size() && tokens[pos] == ")") ++pos;
                return v;
            }
            const size_t colon = t.find(':');
            if (colon == std::string::npos) return false;
            const std::string id = t.substr(0, colon);
            std::string value = t.substr(colon + 1);
            const bool negate = !value.empty() && value[0] == '!';
            if (negate) value.erase(0, 1);
            if (id.rfind("Sw/", 0) == 0) return false;
            const bool eq = self->CurrentValue(id) == std::atoi(value.c_str());
            return negate ? !eq : eq;
        }
    } parser{this, {}};
    std::string token;
    for (char c : expr) {
        if (c == '(' || c == ')' || c == ' ') {
            if (!token.empty()) parser.tokens.push_back(token), token.clear();
            if (c != ' ') parser.tokens.push_back(std::string(1, c));
        } else {
            token += c;
        }
    }
    if (!token.empty()) parser.tokens.push_back(token);
    return parser.Or();
}

// 実機の状態を出す項目
bool TestModeScene::DynamicValue(const std::string& id, double& value) const {
    const GuminTaiko::PlayDataManager& pd = GuminTaiko::PlayDataManager::Get();
    const GameSettings::Bookkeeping& b = GameSettings::Get().Books();
    if (id == "LeftCreditItem") value = pd.Coins();
    else if (id == "UseCreditItem") value = b.lastUseCredit;
    else if (id == "PlayCountItem") value = b.playCount;
    else if (id == "CoinCountItem") value = b.coinCount;
    else if (id == "ServiceSwCountItem") value = b.serviceCount;
    else if (id == "FreePlayCountItem") value = b.freePlayCount;
    else if (id == "PlayOnRatioItem") value = b.powerOnSeconds > 0.0 ? b.playSeconds / b.powerOnSeconds * 100.0 : 0.0;
    else if (id == "ItemSwTestCoin") value = coinCount_;
    else if (id == "ItemSwTestService") value = TaikoInput::IsServiceDown() ? 1 : 0;
    else if (id == "ItemSwTestTest") value = TaikoInput::IsTestDown() ? 1 : 0;
    else if (id == "ItemSwTestSelectUp") value = TaikoInput::IsSelectUpDown() ? 1 : 0;
    else if (id == "ItemSwTestSelectDown") value = TaikoInput::IsSelectDownDown() ? 1 : 0;
    else if (id == "ItemSwTestEnter") value = TaikoInput::IsEnterDown() ? 1 : 0;
    else if (id == "MuchaAuthItem") value = 0;
    else if (id == "DLStatusItem") value = 0;
    else return false;
    return true;
}

std::string TestModeScene::ValueText(const Item& item) const {
    const std::string id = item.Attr("id");
    // 数値を持たない表示（時間・日時・機器）
    const GameSettings::Bookkeeping& b = GameSettings::Get().Books();
    if (item.type == "time-item") {
        if (id == "PowerOnTimeItem") return FormatSeconds(b.powerOnSeconds);
        if (id == "TotalPlayTimeItem") return FormatSeconds(b.playSeconds);
        if (id == "AvePlayTimeItem") return FormatSeconds(b.playCount > 0 ? b.playSeconds / b.playCount : 0.0);
        return FormatSeconds(0.0);
    }
    if (item.type == "date-item" || item.type == "set-clock-item") return NowText();
    if (item.type == "ipv4-item") return "０．０．０．０";
    if (item.type == "text-item") {
        if (id == "ItemCardRWHWTest" || id == "ItemCodeReaderTest") return "@Color/Gray;ＮＯ ＤＥＶＩＣＥ@Color/Default;";
        if (id == "SNItem" || id == "AllNetPcbIdItem" || id == "AllNetGameVerItem" || id == "AllNetLicenseItem" ||
            id == "GameServerItem" || id == "UpdateServerItem") {
            return "－－－－";
        }
        return "";
    }
    if (item.type == "cmd-item") {
        const std::vector<std::string> states = SplitCommandText(item.Attr("cmd-text"));
        auto found = commandState_.find(id);
        const int state = found != commandState_.end() ? found->second : 0;
        if (edit_ == Edit::Confirm && cursor_ >= 0 && placed_[size_t(cursor_)].item == &item) {
            return confirmYes_ ? "@Color/Red;ＹＥＳ@Color/Default;　ＮＯ" : "ＹＥＳ　@Color/Red;ＮＯ@Color/Default;";
        }
        return state < int(states.size()) ? states[size_t(state)] : "";
    }
    if (item.type == "toggle-item" || item.type == "select-item" || item.type == "digit-item") {
        if (id == "UsioConnect") return "@Color/Gray;ＮＯＴ ＣＯＮＮＥＣＴＥＤ@Color/Default;";
        if (id == "StartingVerItem" || id == "ApplyingVerItem" || id == "DownLoadingVerItem" || id == "DLProgressItem") return "－－－";
        double dynamic = 0.0;
        const bool hasDynamic = DynamicValue(id, dynamic) && !IsSetting(item);
        const int value = hasDynamic ? int(dynamic) : CurrentValue(id);
        std::string body;
        if (!ReplaceText(item, value, body)) {
            const std::string format = item.Attr("format");
            if (!format.empty()) {
                char buffer[64];
                if (format.find('f') != std::string::npos) std::snprintf(buffer, sizeof(buffer), format.c_str(), hasDynamic ? dynamic : double(value));
                else std::snprintf(buffer, sizeof(buffer), format.c_str(), value);
                body = buffer;
            } else if (hasDynamic || IsSetting(item) || item.Has("default") || item.Has("max")) {
                body = std::to_string(value);
            }
        }
        if (id == "LeftCreditItem" && GuminTaiko::PlayDataManager::Get().IsFreePlay()) body = "ＦＲＥＥ ＰＬＡＹ";
        return item.Attr("prefix") + body + item.Attr("suffix");
    }
    return "";
}

// ===========================================================================
// 進行
// ===========================================================================
void TestModeScene::Update(float deltaTime) {
    time_ += deltaTime;

    // テストスイッチを戻したら再起動（アトラクトの最初から）
    const bool first = firstFrame_;
    firstFrame_ = false;
    // KEY CONFIG でキーを待っているあいだは、テストスイッチのキーも割り当てるキーとして受け取る
    if (!first && !kcWaiting_ && TaikoInput::IsTestPressed()) {
        GameSettings::Get().Save();
        // 暗転してからアトラクトの最初へ
        SoundManager::Get().StopAll();
        SceneManager::GetInstance().ChangeScene(
            std::make_unique<LoadingScene>([] { return std::unique_ptr<Scene>(std::make_unique<AttractScene>(false)); }), true);
        return;
    }
    if (!kcWaiting_ && TaikoInput::IsCoinInserted()) ++coinCount_;
    if (first) return;
    if (keyConfig_) {
        UpdateKeyConfig();
        return;
    }
    // ESC: 変更中なら取り消し、それ以外は1つ前のメニューへ（トップメニューならテストモードを抜ける）
    if (TaikoInput::IsBackPressed() && menu_) {
        if (edit_ != Edit::None) {
            edit_ = Edit::None;
        } else if (menu_->id != def_->topMenu) {
            auto parent = parentOf_.find(menu_->id);
            OpenMenu(parent != parentOf_.end() ? parent->second : def_->topMenu);
        } else {
            GameSettings::Get().Save();
            SoundManager::Get().StopAll();
            SceneManager::GetInstance().ChangeScene(
                std::make_unique<LoadingScene>([] { return std::unique_ptr<Scene>(std::make_unique<AttractScene>(false)); }), true);
        }
        return;
    }

    for (auto& entry : commandTimer_) {
        if (entry.second <= 0.0f) continue;
        entry.second -= deltaTime;
        if (entry.second <= 0.0f) {
            // 実行中 → 完了
            commandState_[entry.first] = std::min(commandState_[entry.first] + 1, 2);
        }
    }

    if (!menu_) return;
    const std::string msg = menu_->Attr("msg");

    // サウンドテスト: 面とふちを叩くと、叩いたときの音が鳴る
    if (msg == "MsgSoundTest") {
        for (int p = 0; p < 2; ++p) {
            if (TaikoInput::IsHit(p, TaikoInput::Pad::LeftDon) || TaikoInput::IsHit(p, TaikoInput::Pad::RightDon)) {
                SoundManager::Get().Play("se_common_v12a", "don_c");
            }
            if (TaikoInput::IsHit(p, TaikoInput::Pad::LeftKa) || TaikoInput::IsHit(p, TaikoInput::Pad::RightKa)) {
                SoundManager::Get().Play("se_common_v12a", "katsu_c");
            }
        }
    }

    // スイッチテストは SELECT(UP) + ENTER で戻る（menu-cmd）
    const std::string menuCmd = menu_->Attr("menu-cmd");
    if (!menuCmd.empty() && TaikoInput::IsSelectUpDown() && TaikoInput::IsEnter()) {
        OpenMenu(menuCmd.substr(menuCmd.rfind(':') + 1));
        return;
    }
    if (!menuCmd.empty()) return;   // スイッチテストは表示だけ

    if (cursor_ < 0) return;
    const bool enter = TaikoInput::IsEnter();
    if (edit_ == Edit::Value) {
        // 押し続けると繰り返す。幅の広い値（曲数 1〜999 など）は、しばらく押し続けると 10 ずつ変える
        if (!TaikoInput::IsSelectDownDown() && !TaikoInput::IsSelectUpDown()) valueRepeat_ = 0;
        if (TaikoInput::IsSelectDown()) MoveValue(++valueRepeat_ > kFastRepeat ? kFastStep : 1);
        else if (TaikoInput::IsSelectUp()) MoveValue(++valueRepeat_ > kFastRepeat ? -kFastStep : -1);
        if (enter) ConfirmValue();
        return;
    }
    if (edit_ == Edit::Confirm) {
        if (TaikoInput::IsSelectDown() || TaikoInput::IsSelectUp()) confirmYes_ = !confirmYes_;
        if (enter) {
            edit_ = Edit::None;
            if (confirmYes_) RunCommand(*placed_[size_t(cursor_)].item);
        }
        return;
    }
    if (TaikoInput::IsSelectDown()) {
        const Item& item = *placed_[size_t(cursor_)].item;
        int next = -1;
        if (item.Has("next")) {
            for (size_t i = 0; i < placed_.size(); ++i) {
                if (placed_[i].item->Attr("id") == item.Attr("next") && IsSelectable(*placed_[i].item, true)) next = int(i);
            }
        }
        Focus(next >= 0 ? next : FindNext(cursor_, 1, false));
    } else if (TaikoInput::IsSelectUp()) {
        Focus(FindNext(cursor_, -1, false));
    } else if (enter) {
        Enter();
    }
}

void TestModeScene::Enter() {
    const Item& item = *placed_[size_t(cursor_)].item;
    if (item.type == "menu-item" && item.Attr("menu") == kKeyConfigMenu) {
        OpenKeyConfig();
    } else if (item.type == "menu-item") {
        OpenMenu(item.Attr("menu"));
    } else if (item.type == "select-item" || item.type == "digit-item") {
        if (item.Int("max", 0) == item.Int("min", 0) && !IsSetting(item)) return;
        edit_ = Edit::Value;
        editValue_ = CurrentValue(item.Attr("id"));
    } else if (item.type == "toggle-item") {
        temp_[item.Attr("id")] = CurrentValue(item.Attr("id")) == 0 ? 1 : 0;
    } else if (item.type == "cmd-item") {
        if (item.Attr("confirm") == "True") {
            edit_ = Edit::Confirm;
            confirmYes_ = false;
        } else {
            RunCommand(item);
        }
    }
}

void TestModeScene::MoveValue(int direction) {
    const Item& item = *placed_[size_t(cursor_)].item;
    const int minValue = item.Int("min", 0);
    const int maxValue = item.Int("max", 0);
    const int delta = std::max(1, item.Int("delta", 1));
    const bool loop = item.Attr("loop", "True") != "False";
    // 10 ずつ変えるのは幅の広い値だけ（ほかは 1 ずつ）
    if (std::abs(direction) > 1 && maxValue - minValue < kFastRange) direction = direction > 0 ? 1 : -1;
    // 10 ずつ変えているときは端で回らずに止める（行き過ぎて反対の端へ飛ばないように）
    const bool fast = std::abs(direction) > 1;
    int v = editValue_ + direction * delta;
    if (fast) {
        editValue_ = std::clamp(v, minValue, maxValue);
        return;
    }
    if (v > maxValue) v = loop ? minValue : maxValue;
    if (v < minValue) v = loop ? maxValue : minValue;
    editValue_ = v;
}

void TestModeScene::ConfirmValue() {
    const Item& item = *placed_[size_t(cursor_)].item;
    const std::string id = item.Attr("id");
    if (IsSetting(item)) GameSettings::Get().SetValue(id, editValue_);
    else temp_[id] = editValue_;
    edit_ = Edit::None;

    // auto-next: 次の項目へ（next の指定があればそこへ）
    if (Flag(item, "auto-next")) {
        int next = -1;
        if (item.Has("next")) {
            for (size_t i = 0; i < placed_.size(); ++i) {
                if (placed_[i].item->Attr("id") == item.Attr("next")) next = int(i);
            }
        }
        if (next < 0) next = FindNext(cursor_, 1, true);
        if (next >= 0) Focus(next);
    }
}

void TestModeScene::RunCommand(const Item& item) {
    const std::string id = item.Attr("id");
    const std::vector<std::string> states = SplitCommandText(item.Attr("cmd-text"));
    if (id == "CmdBookkeepingInitialize") GameSettings::Get().ResetBookkeeping();
    else if (id == "CmdBackupInitialize") {
        GameSettings::Get().ResetSettings();
        GameSettings::Get().ResetBookkeeping();
    } else if (id == "CmdSoundLRCheck") {
        // ＬＥＦＴ → ＲＩＧＨＴ → ＬＥＦＴ＋ＲＩＧＨＴ → ＷＯＯＦＥＲ → なし の順に鳴らす
        const int message = (CurrentValue("SoundTestMessageItem") + 1) % 5;
        temp_["SoundTestMessageItem"] = message;
        if (message != 0) SoundManager::Get().Play("se_common_v12a", "don_c");
        return;
    } else if (id == "CmdStartLNC") {
        temp_["ItemLNCCable"] = 2;
        temp_["ItemLNCTenpoRouter"] = 2;
    }

    if (states.size() >= 3) {
        // 空 → 実行中 → 完了
        commandState_[id] = 1;
        commandTimer_[id] = kCommandSeconds;
        if (id == "CmdStartLNC") {
            temp_["ItemLNCCable"] = 1;
            temp_["ItemLNCTenpoRouter"] = -1;   // 店舗のルーターにはつながらない
        }
    } else if (!states.empty()) {
        commandState_[id] = (commandState_[id] + 1) % int(states.size());
    }
}

// ===========================================================================
// 描画
// ===========================================================================
void TestModeScene::DrawMarkup(const std::string& text, int col, int row, Color defaultColor) const {
    Color color = defaultColor;
    bool blink = false;
    const bool blinkOn = std::fmod(time_, kBlinkPeriod * 2.0f) < kBlinkPeriod;
    float x = float(col) * cellW_;
    const float y = float(row) * cellH_ + (cellH_ - kFontSize) * 0.5f;
    size_t i = 0;
    while (i < text.size()) {
        if (text[i] == '@') {
            const size_t semi = text.find(';', i);
            if (semi != std::string::npos) {
                const std::string tag = text.substr(i + 1, semi - i - 1);
                if (tag == "Anim/Blink") blink = true;
                else if (tag == "Color/Default") color = defaultColor, blink = false;
                else color = NamedColor(tag, color);
                i = semi + 1;
                continue;
            }
        }
        // 1文字ぶん
        int length = 1;
        const unsigned char c = static_cast<unsigned char>(text[i]);
        if (c >= 0xF0) length = 4;
        else if (c >= 0xE0) length = 3;
        else if (c >= 0xC0) length = 2;
        const std::string ch = text.substr(i, size_t(length));
        i += size_t(length);
        const int cp = GetCodepoint(ch.c_str(), &length);
        const int cells = Cells(cp);
        if (!(blink && !blinkOn) && cp != ' ' && cp != 0x3000) {
            GameFont::Get().Draw(ch.c_str(), x + float(cells) * cellW_ * 0.5f, y, kFontSize, color, TextAlign::Center);
        }
        x += float(cells) * cellW_;
    }
}

void TestModeScene::DrawPattern(const std::string& msg) const {
    if (msg == "MsgFullWhitePattern") {
        ClearBackground(WHITE);
    } else if (msg == "MsgCrosshatchPattern") {
        for (int x = 0; x <= 1920; x += 120) DrawRectangle(x == 1920 ? 1918 : x, 0, 2, 1080, WHITE);
        for (int y = 0; y <= 1080; y += 120) DrawRectangle(0, y == 1080 ? 1078 : y, 1920, 2, WHITE);
    } else if (msg == "MsgGradationPattern") {
        // 赤・緑・青・白の32段階
        const Color colors[4] = {RED, GREEN, BLUE, WHITE};
        for (int band = 0; band < 4; ++band) {
            for (int step = 0; step < 32; ++step) {
                const float t = float(step) / 31.0f;
                const Color c{(unsigned char)(colors[band].r * t), (unsigned char)(colors[band].g * t), (unsigned char)(colors[band].b * t), 255};
                DrawRectangle(step * 60, band * 270, 60, 270, c);
            }
        }
    } else if (msg == "MsgScrollPattern") {
        const int offset = int(time_ * 240.0f) % 240;
        for (int x = -240; x < 1920 + 240; x += 240) DrawRectangle(x + offset, 0, 120, 1080, WHITE);
    }
}

void TestModeScene::Draw() {
    ClearBackground(BLACK);
    if (!def_ || !def_->loaded) {
        GameFont::Get().Draw("TestMode.xml を読み込めません", 960.0f, 500.0f, 40.0f, WHITE, TextAlign::Center);
        return;
    }
    if (keyConfig_) {
        DrawKeyConfig();
        return;
    }
    if (!menu_) return;
    const std::string msg = menu_->Attr("msg");
    if (msg == "MsgFullWhitePattern" || msg == "MsgCrosshatchPattern" || msg == "MsgGradationPattern" || msg == "MsgScrollPattern") {
        DrawPattern(msg);
        return;
    }

    const Color paramDefault = NamedColor(menu_->Attr("param-default-color"), kLime);
    const Color paramOther = NamedColor(menu_->Attr("param-color"), WHITE);
    const bool blinkOn = std::fmod(time_, kBlinkPeriod * 2.0f) < kBlinkPeriod;
    std::map<int, int> rowEnd;   // 行ごとの、すでに置いた文字の右端（ラベルも位置もない項目はその続きに置く）
    for (size_t i = 0; i < placed_.size(); ++i) {
        const Placed& p = placed_[i];
        const Item& item = *p.item;
        if (Flag(item, "invisible")) continue;
        int paramCol = p.paramCol;
        if (item.Attr("label").empty() && !item.Has("param-offset-x") && rowEnd.count(p.row)) paramCol = rowEnd[p.row];
        const bool selected = int(i) == cursor_ && menu_->Attr("menu-cmd").empty();
        const bool disabled = Flag(item, "disable");
        const Color labelColor = disabled ? kGray : selected ? RED : WHITE;

        if (item.type == "data-item") {
            auto found = def_->textData.find(item.Attr("data"));
            if (found != def_->textData.end()) DrawMarkup(found->second, p.col, p.row, WHITE);
            continue;
        }
        const std::string label = item.Attr("label");
        if (!label.empty()) {
            DrawMarkup(label, p.col, p.row, labelColor);
            rowEnd[p.row] = std::max(rowEnd[p.row], p.col + TextCells(label));
        }

        const std::string value = ValueText(item);
        if (value.empty()) continue;
        rowEnd[p.row] = std::max(rowEnd[p.row], paramCol + TextCells(value));
        const std::string id = item.Attr("id");
        Color color = paramOther;
        if (disabled) color = kGray;
        else if (IsSetting(item) && CurrentValue(id) == GameSettings::Get().Default(id)) color = paramDefault;
        else if (!IsSetting(item) && (item.type == "select-item" || item.type == "toggle-item") && item.Has("default") &&
                 CurrentValue(id) == item.Int("default")) color = paramDefault;
        if (selected && edit_ == Edit::Value) {
            if (!blinkOn) continue;   // 変更中は点滅
            color = RED;
        }
        DrawMarkup(value, paramCol, p.row, color);
    }
}

// ===========================================================================
// KEY CONFIG
// ===========================================================================
namespace {

constexpr int kKcBindings = TaikoInput::kActionCount * TaikoInput::kKeySlots;   // 割り当ての数
constexpr int kKcDefault = kKcBindings;                                         // DEFAULT
constexpr int kKcExit = kKcBindings + 1;                                        // EXIT
constexpr int kKcProfile = kKcBindings + 2;                                     // PROFILE（画面では一番上。選択の順では EXIT の次）
constexpr int kKcItems = kKcBindings + 3;
constexpr int kKcLabelCol = 14;
constexpr int kKcSlotCols[TaikoInput::kKeySlots] = {44, 64};

// 操作の行（太鼓の8つのあとに1行あけて筐体のボタン）
int KcRow(int action) { return 5 + action + (action >= int(TaikoInput::Action::Test) ? 1 : 0); }

} // namespace

void TestModeScene::OpenKeyConfig() {
    keyConfig_ = true;
    kcCursor_ = 0;
    kcWaiting_ = false;
    kcMessage_.clear();
}

void TestModeScene::CloseKeyConfig() {
    keyConfig_ = false;
    kcWaiting_ = false;
    OpenMenu(def_->topMenu);
    for (size_t i = 0; i < placed_.size(); ++i) {
        if (placed_[i].item == &keyConfigItem_) Focus(int(i));
    }
}

void TestModeScene::UpdateKeyConfig() {
    using TaikoInput::Action;
    if (kcWaiting_) {
        // 次に押したキーを割り当てる（ESC で取り消し、DELETE / BACKSPACE で外す）
        const int key = TaikoInput::FirstPressedKey();
        if (key == 0) return;
        const Action action = Action(kcCursor_ / TaikoInput::kKeySlots);
        const int slot = kcCursor_ % TaikoInput::kKeySlots;
        if (key == KEY_ESCAPE) {
            kcWaiting_ = false;
            kcMessage_.clear();
            return;
        }
        if (key == KEY_DELETE || key == KEY_BACKSPACE) {
            TaikoInput::SetBoundKey(action, slot, 0);
            kcWaiting_ = false;
            kcMessage_.clear();
            return;
        }
        if (!TaikoInput::SetBoundKey(action, slot, key)) {
            kcMessage_ = "@Color/Red;" + Wide(TaikoInput::KeyName(key) + " CANNOT BE ASSIGNED") + "@Color/Default;";
            return;   // 待ったまま
        }
        kcWaiting_ = false;
        kcMessage_.clear();
        return;
    }
    if (TaikoInput::IsBackPressed()) {
        CloseKeyConfig();
        return;
    }
    if (TaikoInput::IsSelectDown()) {
        kcCursor_ = (kcCursor_ + 1) % kKcItems;
    } else if (TaikoInput::IsSelectUp()) {
        kcCursor_ = (kcCursor_ + kKcItems - 1) % kKcItems;
    } else if (TaikoInput::IsEnter()) {
        if (kcCursor_ < kKcBindings) {
            kcWaiting_ = true;
            kcMessage_.clear();
        } else if (kcCursor_ == kKcProfile) {
            // 次のキー設定へ切り替える（キーの割り当ては設定ごとに保存される）
            TaikoInput::SetActiveProfile(TaikoInput::ActiveProfile() + 1);
            kcMessage_ = Wide("SWITCHED TO PROFILE " + std::to_string(TaikoInput::ActiveProfile() + 1));
        } else if (kcCursor_ == kKcDefault) {
            TaikoInput::ResetBindings();
            kcMessage_ = Wide("KEYS OF THIS PROFILE WERE RESET TO DEFAULT");
        } else {
            CloseKeyConfig();
        }
    }
}

void TestModeScene::DrawKeyConfig() const {
    using TaikoInput::Action;
    const bool blinkOn = std::fmod(time_, kBlinkPeriod * 2.0f) < kBlinkPeriod;
    auto center = [&](const std::string& text, int row, Color color) {
        DrawMarkup(text, std::max(0, (def_->width - TextCells(text)) / 2), row, color);
    };
    center("ＫＥＹ ＣＯＮＦＩＧ", 1, WHITE);
    DrawMarkup(Wide("PROFILE " + std::to_string(TaikoInput::ActiveProfile() + 1) + "/" + std::to_string(TaikoInput::kProfileCount)),
               kKcLabelCol, 3, kcCursor_ == kKcProfile ? RED : WHITE);
    DrawMarkup("ＫＥＹ１", kKcSlotCols[0], 3, WHITE);
    DrawMarkup("ＫＥＹ２", kKcSlotCols[1], 3, WHITE);

    for (int a = 0; a < TaikoInput::kActionCount; ++a) {
        const int row = KcRow(a);
        const bool rowSelected = kcCursor_ / TaikoInput::kKeySlots == a && kcCursor_ < kKcBindings;
        DrawMarkup(Wide(TaikoInput::ActionName(Action(a))), kKcLabelCol, row, rowSelected ? RED : WHITE);
        for (int s = 0; s < TaikoInput::kKeySlots; ++s) {
            const int key = TaikoInput::BoundKey(Action(a), s);
            const bool selected = kcCursor_ == a * TaikoInput::kKeySlots + s;
            if (selected && kcWaiting_) {
                if (blinkOn) DrawMarkup("＿＿＿", kKcSlotCols[s], row, RED);
                continue;
            }
            const Color color = selected ? RED : key == TaikoInput::DefaultKey(Action(a), s) ? kLime : WHITE;
            DrawMarkup(Wide(TaikoInput::KeyName(key)), kKcSlotCols[s], row, color);
        }
    }
    const int defaultRow = KcRow(TaikoInput::kActionCount - 1) + 2;
    DrawMarkup("ＤＥＦＡＵＬＴ", kKcLabelCol, defaultRow, kcCursor_ == kKcDefault ? RED : WHITE);
    DrawMarkup("ＥＸＩＴ", kKcLabelCol, defaultRow + 1, kcCursor_ == kKcExit ? RED : WHITE);
    if (!kcMessage_.empty()) DrawMarkup(kcMessage_, kKcLabelCol, defaultRow + 3, WHITE);

    const int footer = def_->height - 2;
    if (kcWaiting_) {
        center("ＰＲＥＳＳ Ａ ＫＥＹ　　ＥＳＣ：ＣＡＮＣＥＬ　　ＤＥＬＥＴＥ：ＣＬＥＡＲ", footer, WHITE);
    } else {
        center("ＳＥＬＥＣＴ ＳＷ：ＣＨＯＯＳＥ　　ＥＮＴＥＲ ＳＷ：ＥＮＴＥＲ", footer, WHITE);
        center("ＤＥＦＡＵＬＴ ＩＮ ＧＲＥＥＮ", footer - 1, kLime);
    }
}
