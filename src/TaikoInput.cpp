#include "TaikoInput.hpp"

#include <algorithm>
#include <cstdlib>
#include <filesystem>
#include <fstream>

// raylib の中の GLFW（libraylib.a に入っている）
struct GLFWwindow;
extern "C" {
typedef void (*GLFWkeyfun)(GLFWwindow*, int, int, int, int);
GLFWkeyfun glfwSetKeyCallback(GLFWwindow* window, GLFWkeyfun callback);
GLFWwindow* glfwGetCurrentContext(void);
}

namespace TaikoInput {

namespace {

constexpr int kGlfwKeyF12 = 301;
constexpr const char* kDir = "Backup";
constexpr const char* kPath = "Backup/keyconfig.ini";

struct ActionInfo {
    const char* id;     // 保存するときの名前
    const char* name;   // 表示名
    int keys[kKeySlots];
};
const ActionInfo kActions[kActionCount] = {
    {"P1KaLeft", "1P KA (LEFT)", {KEY_D, KEY_LEFT}},
    {"P1DonLeft", "1P DON (LEFT)", {KEY_F, KEY_NULL}},
    {"P1DonRight", "1P DON (RIGHT)", {KEY_J, KEY_ENTER}},
    {"P1KaRight", "1P KA (RIGHT)", {KEY_K, KEY_RIGHT}},
    {"P2KaLeft", "2P KA (LEFT)", {KEY_Z, KEY_KP_7}},
    {"P2DonLeft", "2P DON (LEFT)", {KEY_X, KEY_KP_4}},
    {"P2DonRight", "2P DON (RIGHT)", {KEY_C, KEY_KP_6}},
    {"P2KaRight", "2P KA (RIGHT)", {KEY_V, KEY_KP_9}},
    {"Test", "TEST SW", {KEY_F1, KEY_NULL}},
    {"Service", "SERVICE SW", {KEY_F10, KEY_NULL}},
    {"Coin", "COIN", {KEY_F5, KEY_NULL}},
    {"Card", "CARD TOUCH", {KEY_F3, KEY_NULL}},
    {"NewCard", "CARD TOUCH (NEW)", {KEY_F4, KEY_NULL}},
    {"FreePlay", "FREE PLAY TOGGLE", {KEY_F2, KEY_NULL}},
    {"Training", "TRAINING MODE", {KEY_F2, KEY_NULL}},
};

int g_profiles[kProfileCount][kActionCount][kKeySlots] = {};
int g_active = 0;
bool g_loaded = false;

// 使っている設定の割り当て
int (&Keys())[kActionCount][kKeySlots] { return g_profiles[g_active]; }

void FillDefault(int profile) {
    for (int a = 0; a < kActionCount; ++a) {
        for (int s = 0; s < kKeySlots; ++s) g_profiles[profile][a][s] = kActions[a].keys[s];
    }
}

GLFWkeyfun g_raylibKeyCallback = nullptr;

void KeyCallback(GLFWwindow* window, int key, int scancode, int action, int mods) {
    // F12 は raylib には渡さない（渡すと screenshot000.png などを保存してしまう）
    if (key == kGlfwKeyF12) return;
    if (g_raylibKeyCallback) g_raylibKeyCallback(window, key, scancode, action, mods);
}

bool IsPad(Action action) { return int(action) < int(Action::Test); }

// 同じキーでもよい組（使う画面が違う）
bool MayShare(Action a, Action b) {
    return (a == Action::FreePlay && b == Action::Training) || (a == Action::Training && b == Action::FreePlay);
}

void EnsureLoaded() {
    if (!g_loaded) LoadBindings();
}

} // namespace

void LoadBindings() {
    g_loaded = true;
    g_active = 0;
    for (int p = 0; p < kProfileCount; ++p) FillDefault(p);
    std::ifstream ifs(kPath);
    std::string line;
    int profile = 0;   // 「[2]」のような見出しのない古い形式は、1つめの設定として読む
    while (std::getline(ifs, line)) {
        while (!line.empty() && (line.back() == '\r' || line.back() == ' ')) line.pop_back();
        // 「[2]」: 2つめの設定の始まり
        if (line.size() >= 3 && line.front() == '[' && line.back() == ']') {
            profile = std::clamp(std::atoi(line.substr(1, line.size() - 2).c_str()) - 1, 0, kProfileCount - 1);
            continue;
        }
        // 「P1KaLeft=68,263」「active=2」
        const size_t eq = line.find('=');
        if (eq == std::string::npos) continue;
        const std::string id = line.substr(0, eq);
        const std::string value = line.substr(eq + 1);
        if (id == "active") {
            g_active = std::clamp(std::atoi(value.c_str()) - 1, 0, kProfileCount - 1);
            continue;
        }
        for (int a = 0; a < kActionCount; ++a) {
            if (id != kActions[a].id) continue;
            const size_t comma = value.find(',');
            g_profiles[profile][a][0] = std::atoi(value.substr(0, comma).c_str());
            g_profiles[profile][a][1] = comma == std::string::npos ? 0 : std::atoi(value.substr(comma + 1).c_str());
        }
    }
}

void SaveBindings() {
    std::error_code ec;
    std::filesystem::create_directories(kDir, ec);
    std::ofstream ofs(kPath, std::ios::trunc);
    if (!ofs) return;
    ofs << "active=" << g_active + 1 << '\n';
    for (int p = 0; p < kProfileCount; ++p) {
        ofs << '[' << p + 1 << "]\n";
        for (int a = 0; a < kActionCount; ++a) ofs << kActions[a].id << '=' << g_profiles[p][a][0] << ',' << g_profiles[p][a][1] << '\n';
    }
}

void ResetBindings() {
    EnsureLoaded();
    FillDefault(g_active);   // 使っている設定だけ初期値に戻す
    SaveBindings();
}

int ActiveProfile() {
    EnsureLoaded();
    return g_active;
}

void SetActiveProfile(int profile) {
    EnsureLoaded();
    g_active = ((profile % kProfileCount) + kProfileCount) % kProfileCount;
    SaveBindings();
}

int BoundKey(Action action, int slot) {
    EnsureLoaded();
    if (int(action) < 0 || int(action) >= kActionCount || slot < 0 || slot >= kKeySlots) return 0;
    return Keys()[int(action)][slot];
}

int DefaultKey(Action action, int slot) {
    if (int(action) < 0 || int(action) >= kActionCount || slot < 0 || slot >= kKeySlots) return 0;
    return kActions[int(action)].keys[slot];
}

int WindowsKey(int key) {
    if ((key >= 'A' && key <= 'Z') || (key >= '0' && key <= '9') || key == ' ') return key;   // 文字・数字・スペースは同じ番号
    switch (key) {
        case 39: return 0xDE;    // '
        case 44: return 0xBC;    // ,
        case 45: return 0xBD;    // -
        case 46: return 0xBE;    // .
        case 47: return 0xBF;    // /
        case 59: return 0xBA;    // ;
        case 61: return 0xBB;    // =
        case 91: return 0xDB;    // [
        case 92: return 0xDC;    // バックスラッシュ
        case 93: return 0xDD;    // ]
        case 96: return 0xC0;    // `
        case 257: return 0x0D;   // Enter
        case 258: return 0x09;   // Tab
        case 259: return 0x08;   // Backspace
        case 262: return 0x27;   // →
        case 263: return 0x25;   // ←
        case 264: return 0x28;   // ↓
        case 265: return 0x26;   // ↑
        default: break;
    }
    if (key >= 290 && key <= 301) return 0x70 + (key - 290);   // F1〜F12
    if (key >= 320 && key <= 329) return 0x60 + (key - 320);   // テンキー 0〜9
    return 0;
}

bool IsReservedKey(Action action, int key) {
    if (key == KEY_ESCAPE || key == KEY_F11 || key == KEY_F12) return true;
    // 筐体のボタンに SELECT / ENTER のキーを割り当てると、テストモードを操作できなくなる
    if (!IsPad(action) && (key == KEY_UP || key == KEY_DOWN || key == KEY_ENTER || key == KEY_SPACE)) return true;
    return false;
}

bool SetBoundKey(Action action, int slot, int key) {
    EnsureLoaded();
    if (slot < 0 || slot >= kKeySlots) return false;
    if (key != 0 && IsReservedKey(action, key)) return false;
    if (key != 0) {
        for (int a = 0; a < kActionCount; ++a) {
            if (MayShare(action, Action(a))) continue;
            for (int s = 0; s < kKeySlots; ++s) {
                if (Keys()[a][s] == key && !(a == int(action) && s == slot)) Keys()[a][s] = 0;
            }
        }
    }
    Keys()[int(action)][slot] = key;
    SaveBindings();
    return true;
}

std::string ActionName(Action action) {
    if (int(action) < 0 || int(action) >= kActionCount) return "";
    return kActions[int(action)].name;
}

std::string KeyName(int key) {
    if (key == 0) return "---";
    if (key >= KEY_A && key <= KEY_Z) return std::string(1, char(key));
    if (key >= KEY_ZERO && key <= KEY_NINE) return std::string(1, char(key));
    if (key >= KEY_F1 && key <= KEY_F12) return "F" + std::to_string(key - KEY_F1 + 1);
    if (key >= KEY_KP_0 && key <= KEY_KP_9) return "NUM " + std::to_string(key - KEY_KP_0);
    switch (key) {
    case KEY_SPACE: return "SPACE";
    case KEY_ENTER: return "ENTER";
    case KEY_TAB: return "TAB";
    case KEY_BACKSPACE: return "BACKSPACE";
    case KEY_INSERT: return "INSERT";
    case KEY_DELETE: return "DELETE";
    case KEY_RIGHT: return "RIGHT";
    case KEY_LEFT: return "LEFT";
    case KEY_DOWN: return "DOWN";
    case KEY_UP: return "UP";
    case KEY_PAGE_UP: return "PAGE UP";
    case KEY_PAGE_DOWN: return "PAGE DOWN";
    case KEY_HOME: return "HOME";
    case KEY_END: return "END";
    case KEY_CAPS_LOCK: return "CAPS LOCK";
    case KEY_SCROLL_LOCK: return "SCROLL LOCK";
    case KEY_NUM_LOCK: return "NUM LOCK";
    case KEY_PRINT_SCREEN: return "PRINT SCREEN";
    case KEY_PAUSE: return "PAUSE";
    case KEY_LEFT_SHIFT: return "L SHIFT";
    case KEY_LEFT_CONTROL: return "L CTRL";
    case KEY_LEFT_ALT: return "L ALT";
    case KEY_LEFT_SUPER: return "L WIN";
    case KEY_RIGHT_SHIFT: return "R SHIFT";
    case KEY_RIGHT_CONTROL: return "R CTRL";
    case KEY_RIGHT_ALT: return "R ALT";
    case KEY_RIGHT_SUPER: return "R WIN";
    case KEY_KB_MENU: return "MENU";
    case KEY_KP_DECIMAL: return "NUM .";
    case KEY_KP_DIVIDE: return "NUM /";
    case KEY_KP_MULTIPLY: return "NUM *";
    case KEY_KP_SUBTRACT: return "NUM -";
    case KEY_KP_ADD: return "NUM +";
    case KEY_KP_ENTER: return "NUM ENTER";
    case KEY_KP_EQUAL: return "NUM =";
    case KEY_APOSTROPHE: return "'";
    case KEY_COMMA: return ",";
    case KEY_MINUS: return "-";
    case KEY_PERIOD: return ".";
    case KEY_SLASH: return "/";
    case KEY_SEMICOLON: return ";";
    case KEY_EQUAL: return "=";
    case KEY_LEFT_BRACKET: return "[";
    case KEY_BACKSLASH: return "\\";
    case KEY_RIGHT_BRACKET: return "]";
    case KEY_GRAVE: return "`";
    default: return "KEY " + std::to_string(key);
    }
}

bool ActionPressed(Action action) {
    EnsureLoaded();
    for (int key : Keys()[int(action)]) {
        if (key != 0 && KeyPressed(key)) return true;
    }
    return false;
}

bool ActionDown(Action action) {
    EnsureLoaded();
    for (int key : Keys()[int(action)]) {
        if (key != 0 && IsKeyDown(key)) return true;
    }
    return false;
}

bool ActionRepeat(Action action) {
    EnsureLoaded();
    for (int key : Keys()[int(action)]) {
        if (key != 0 && IsKeyPressedRepeat(key)) return true;
    }
    return false;
}

void InstallTestSwitch() {
    if (g_raylibKeyCallback) return;
    // GetWindowHandle は Windows では HWND を返すので使えない。ゲームのウィンドウの OpenGL の文脈から GLFW のウィンドウを得る
    GLFWwindow* window = glfwGetCurrentContext();
    if (!window) return;
    g_raylibKeyCallback = glfwSetKeyCallback(window, KeyCallback);
}

} // namespace TaikoInput
