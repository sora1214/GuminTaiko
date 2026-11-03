#include "Tja.hpp"

#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <vector>

#include "SongDatabase.hpp"

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>

namespace GuminTaiko {

namespace {

namespace fs = std::filesystem;

bool Fail(std::string* error, const std::string& message) {
    if (error) *error = message;
    return false;
}

std::string Trim(const std::string& s) {
    size_t begin = 0, end = s.size();
    while (begin < end && std::isspace(static_cast<unsigned char>(s[begin]))) ++begin;
    while (end > begin && std::isspace(static_cast<unsigned char>(s[end - 1]))) --end;
    return s.substr(begin, end - begin);
}

std::string Upper(std::string s) {
    for (char& c : s) c = char(std::toupper(static_cast<unsigned char>(c)));
    return s;
}

bool IsValidUtf8(const std::string& s) {
    size_t i = 0;
    while (i < s.size()) {
        const unsigned char c = static_cast<unsigned char>(s[i]);
        int extra = c < 0x80 ? 0 : (c >> 5) == 0x6 ? 1 : (c >> 4) == 0xE ? 2 : (c >> 3) == 0x1E ? 3 : -1;
        if (extra < 0 || i + size_t(extra) >= s.size() + (extra == 0 ? 1 : 0)) return false;
        for (int k = 1; k <= extra; ++k) {
            if ((static_cast<unsigned char>(s[i + size_t(k)]) >> 6) != 0x2) return false;
        }
        i += size_t(extra) + 1;
    }
    return true;
}

std::string SjisToUtf8(const std::string& s) {
    if (s.empty()) return s;
    const int wideLength = MultiByteToWideChar(932, 0, s.data(), int(s.size()), nullptr, 0);
    std::wstring wide(size_t(wideLength), L'\0');
    MultiByteToWideChar(932, 0, s.data(), int(s.size()), wide.data(), wideLength);
    const int length = WideCharToMultiByte(CP_UTF8, 0, wide.data(), wideLength, nullptr, 0, nullptr, nullptr);
    std::string out(size_t(length), '\0');
    WideCharToMultiByte(CP_UTF8, 0, wide.data(), wideLength, out.data(), length, nullptr, nullptr);
    return out;
}

// 1行ずつに分け、コメント（//）と前後の空白を取る。文字コードは UTF-8 にそろえる
bool ReadLines(const std::string& path, std::vector<std::string>& lines, std::string* error) {
    std::ifstream ifs(fs::u8path(path), std::ios::binary);
    if (!ifs) return Fail(error, "TJA を開けません: " + path);
    std::string data((std::istreambuf_iterator<char>(ifs)), std::istreambuf_iterator<char>());
    if (data.size() >= 3 && static_cast<unsigned char>(data[0]) == 0xEF && static_cast<unsigned char>(data[1]) == 0xBB &&
        static_cast<unsigned char>(data[2]) == 0xBF) {
        data.erase(0, 3);
    } else if (!IsValidUtf8(data)) {
        data = SjisToUtf8(data);
    }

    lines.clear();
    size_t start = 0;
    while (start <= data.size()) {
        size_t end = data.find('\n', start);
        if (end == std::string::npos) end = data.size();
        std::string line = data.substr(start, end - start);
        const size_t comment = line.find("//");
        if (comment != std::string::npos) line.erase(comment);
        lines.push_back(Trim(line));
        start = end + 1;
    }
    return true;
}

// "KEY:VALUE" のヘッダー行なら key（大文字）と value を返す
bool SplitHeader(const std::string& line, std::string& key, std::string& value) {
    if (line.empty() || line[0] == '#') return false;
    const size_t colon = line.find(':');
    if (colon == std::string::npos || colon == 0) return false;
    key = Upper(Trim(line.substr(0, colon)));
    value = Trim(line.substr(colon + 1));
    for (char c : key) {
        if (!std::isalnum(static_cast<unsigned char>(c)) && c != '_') return false;
    }
    return true;
}

int CourseIndex(const std::string& value) {
    const std::string v = Upper(value);
    if (v == "EASY" || v == "0") return kCourseEasy;
    if (v == "NORMAL" || v == "1") return kCourseNormal;
    if (v == "HARD" || v == "2") return kCourseHard;
    if (v == "ONI" || v == "3") return kCourseOni;
    if (v == "EDIT" || v == "URA" || v == "4") return kCourseUra;
    return -1;
}

// 「--」「++」で始まるサブタイトルは、その記号を取る
std::string CleanSubtitle(const std::string& value) {
    if (value.rfind("--", 0) == 0 || value.rfind("++", 0) == 0) return Trim(value.substr(2));
    return value;
}

// "#START P2" などの命令を名前（大文字）と引数に分ける
void SplitCommand(const std::string& line, std::string& name, std::string& arg) {
    size_t end = 1;
    while (end < line.size() && !std::isspace(static_cast<unsigned char>(line[end]))) ++end;
    name = Upper(line.substr(1, end - 1));
    arg = Trim(line.substr(end));
}

// ---- 譜面の中身 ----
struct Chart {
    std::vector<std::string> lines;   // #START と #END のあいだ
    double bpm = 120.0;
    double offset = 0.0;              // 秒
    std::vector<int> balloons;
};

class ChartParser {
public:
    ChartParser(const Chart& chart, int branch) : chart_(chart), branch_(branch) {
        s_.bpm = chart.bpm > 0.0 ? chart.bpm : 120.0;
        s_.time = -chart.offset * 1000.0;
    }

    std::vector<FumenMeasure> Parse() {
        for (const std::string& line : chart_.lines) {
            if (line.empty()) continue;
            if (line[0] == '#') {
                Command(line);
                continue;
            }
            if (Skipping()) {
                // ほかの分岐の風船も、打数の並び（BALLOON:）は順に使う
                for (char c : line) {
                    if (c == '7' || c == '9') ++balloonIndex_;
                }
                continue;
            }
            for (char c : line) {
                if (c == '#') break;   // 音符の行に続けて書かれた命令は読まない（命令は行の頭に書く決まり）
                if (c == ',') {
                    Flush();
                } else if (std::isalnum(static_cast<unsigned char>(c))) {
                    notes_ += char(std::toupper(static_cast<unsigned char>(c)));
                }
            }
        }
        if (!notes_.empty() || !commands_.empty()) Flush();
        // 終わりのない連打は最後の小節の終わりまで
        if (roll_.active) EndRoll();
        return std::move(out_);
    }

    bool HasBranches() const { return hasBranches_; }
    // 分岐の条件と #SECTION は、普通譜面（branch = 0）の読み込みだけが集める。#LEVELHOLD は道ごとに集める
    std::vector<FumenBranch> TakeBranches() { return std::move(branches_); }
    std::vector<double> TakeSections() { return std::move(sections_); }
    std::vector<FumenLevelHold> TakeLevelHolds() { return std::move(levelHolds_); }

private:
    struct State {
        double time = 0.0;
        double bpm = 120.0;
        double scroll = 1.0;
        double ratio = 1.0;
        bool gogo = false;
        bool barline = true;
    };

    bool Skipping() const { return section_ >= 0 && section_ != branch_; }

    // #BRANCHSTART 種類,玄人,達人（種類: p 精度 r 連打数 s 得点）
    void OpenBranch(const std::string& arg) {
        FumenBranch branch;
        branch.start = s_.time;
        branch.end = 1.0e18;
        const size_t comma = arg.find(',');
        const std::string kind = arg.substr(0, comma);
        const size_t letter = kind.find_first_not_of(" \t");
        const char c = letter == std::string::npos ? 'p' : char(std::tolower(static_cast<unsigned char>(kind[letter])));
        branch.kind = c == 'r' ? FumenBranch::Kind::Roll : c == 's' ? FumenBranch::Kind::Score : FumenBranch::Kind::Accuracy;
        if (comma != std::string::npos) {
            const size_t second = arg.find(',', comma + 1);
            branch.expert = std::atof(arg.c_str() + comma + 1);
            if (second != std::string::npos) branch.master = std::atof(arg.c_str() + second + 1);
        }
        branches_.push_back(branch);
        branchOpen_ = true;
    }

    // 開いている分岐を、いまの時刻で閉じる（次の #BRANCHSTART か #BRANCHEND）
    void CloseBranch() {
        if (branch_ != 0 || !branchOpen_) return;
        branches_.back().end = s_.time;
        branchOpen_ = false;
    }

    void Command(const std::string& line) {
        std::string name, arg;
        SplitCommand(line, name, arg);
        if (name == "BRANCHSTART") {
            hasBranches_ = true;
            CloseBranch();
            saved_ = s_;
            section_ = -1;
            if (branch_ == 0) OpenBranch(arg);
            return;
        }
        if (name == "N" || name == "E" || name == "M") {
            section_ = name == "N" ? 0 : name == "E" ? 1 : 2;
            if (section_ == branch_) s_ = saved_;
            return;
        }
        if (name == "BRANCHEND") {
            CloseBranch();
            section_ = -1;
            return;
        }
        if (name == "SECTION") {
            // 分岐の判定に使う成績を数え直す位置。次の #BRANCHSTART の直前に、#M の区間の終わりとして書かれることが多く
            // （#BRANCHEND がないので、普通譜面の読み込みは読み飛ばしている区間）、どの道を通っても効くので、読み飛ばさずに集める
            if (branch_ == 0 && (sections_.empty() || sections_.back() != s_.time)) sections_.push_back(s_.time);
            return;
        }
        if (name == "LEVELHOLD") {
            // 分岐を動かさなくする位置。#M の中だけに書かれることもあり、その道を通っている人だけに効く
            if (!Skipping()) levelHolds_.push_back({s_.time, branch_});
            return;
        }
        if (Skipping()) return;
        // 小節の頭ならすぐに、途中なら次の音符の位置で効かせる
        if (notes_.empty()) Apply(name, arg);
        else commands_.push_back({notes_.size(), name, arg});
    }

    void Apply(const std::string& name, const std::string& arg) {
        if (name == "MEASURE") {
            const size_t slash = arg.find('/');
            const double a = std::atof(arg.c_str());
            const double b = slash == std::string::npos ? 4.0 : std::atof(arg.c_str() + slash + 1);
            if (a > 0.0 && b > 0.0) s_.ratio = a / b;
        } else if (name == "BPMCHANGE") {
            const double bpm = std::atof(arg.c_str());
            if (bpm > 0.0) s_.bpm = bpm;
        } else if (name == "SCROLL") {
            s_.scroll = std::atof(arg.c_str());
        } else if (name == "GOGOSTART" || name == "GOGOEND") {
            s_.gogo = name == "GOGOSTART";
            // ゴーゴーの切り替わりは小節線のない小節として置く（演奏画面は小節ごとにゴーゴーを見る）
            FumenMeasure m = MakeMeasure();
            m.barline = false;
            out_.push_back(m);
        } else if (name == "DELAY") {
            s_.time += std::atof(arg.c_str()) * 1000.0;
        } else if (name == "BARLINEOFF") {
            s_.barline = false;
        } else if (name == "BARLINEON") {
            s_.barline = true;
        }
    }

    FumenMeasure MakeMeasure() const {
        FumenMeasure m;
        m.time = s_.time;
        m.bpm = s_.bpm;
        m.scroll = {s_.scroll, s_.scroll, s_.scroll};
        m.gogo = s_.gogo;
        m.barline = s_.barline;
        return m;
    }

    void Flush() {
        const double ratio = s_.ratio;
        const size_t count = notes_.size();
        out_.push_back(MakeMeasure());
        const size_t measure = out_.size() - 1;

        size_t next = 0;
        if (count == 0) {
            s_.time += 240000.0 / s_.bpm * ratio;
        } else {
            for (size_t i = 0; i < count; ++i) {
                while (next < commands_.size() && commands_[next].position <= i) {
                    Apply(commands_[next].name, commands_[next].arg);
                    ++next;
                }
                Place(notes_[i], measure);
                s_.time += 240000.0 / s_.bpm * ratio / double(count);
            }
        }
        for (; next < commands_.size(); ++next) Apply(commands_[next].name, commands_[next].arg);
        notes_.clear();
        commands_.clear();
    }

    void Place(char c, size_t measure) {
        NoteType type = NoteType::None;
        switch (c) {
        case '1': type = NoteType::Don; break;
        case '2': type = NoteType::Katsu; break;
        case '3': type = NoteType::BigDon; break;
        case '4': type = NoteType::BigKatsu; break;
        case 'A': type = NoteType::HandDon; break;
        case 'B': type = NoteType::HandKatsu; break;
        case '5': type = NoteType::Roll; break;
        case '6': type = NoteType::BigRoll; break;
        case '7': type = NoteType::Balloon; break;
        case '9': type = NoteType::Kusudama; break;
        case '8':
            if (roll_.active) EndRoll();
            return;
        default:
            return;
        }
        const bool roll = type == NoteType::Roll || type == NoteType::BigRoll || type == NoteType::Balloon ||
                          type == NoteType::Kusudama;
        if (roll && roll_.active) {
            // 連打の途中の 7・9 は数えるだけ（風船の打数の並びをずらさない）
            if (type == NoteType::Balloon || type == NoteType::Kusudama) ++balloonIndex_;
            return;
        }
        FumenNote note;
        note.type = type;
        note.time = s_.time;
        note.bpm = s_.bpm;
        note.scroll = s_.scroll;
        note.gogo = s_.gogo;
        if (type == NoteType::Balloon || type == NoteType::Kusudama) {
            note.hits = balloonIndex_ < chart_.balloons.size() ? chart_.balloons[balloonIndex_] : 5;
            if (note.hits <= 0) note.hits = 5;
            ++balloonIndex_;
        }
        std::vector<FumenNote>& notes = out_[measure].notes[0];
        notes.push_back(note);
        if (roll) roll_ = {true, measure, notes.size() - 1};
    }

    void EndRoll() {
        FumenNote& note = out_[roll_.measure].notes[0][roll_.note];
        note.duration = std::max(0.0, s_.time - note.time);
        roll_.active = false;
    }

    struct Pending {
        size_t position;
        std::string name, arg;
    };
    struct Roll {
        bool active = false;
        size_t measure = 0, note = 0;
    };

    const Chart& chart_;
    int branch_;
    State s_, saved_;
    int section_ = -1;   // -1: 分岐の外（どの分岐にも入れる） 0〜2: 普通・玄人・達人
    bool hasBranches_ = false;
    std::vector<FumenBranch> branches_;
    std::vector<double> sections_;
    std::vector<FumenLevelHold> levelHolds_;
    bool branchOpen_ = false;
    std::string notes_;
    std::vector<Pending> commands_;
    size_t balloonIndex_ = 0;
    Roll roll_;
    std::vector<FumenMeasure> out_;
};

std::vector<int> ParseBalloons(const std::string& value) {
    std::vector<int> out;
    size_t start = 0;
    while (start < value.size()) {
        size_t end = value.find(',', start);
        if (end == std::string::npos) end = value.size();
        const std::string item = Trim(value.substr(start, end - start));
        if (!item.empty()) out.push_back(std::atoi(item.c_str()));
        start = end + 1;
    }
    return out;
}

// 判定の幅・魂ゲージ・真打の配点。本家の譜面（.bin）の値に合わせた式:
//   判定の幅: SetJudgeWindows（Fumen.cpp）で難易度から決める
//   クリアのライン: 6000 / 7000 / 7000 / 8000（最大 10000）
//   良で増える量 × 音符の数 ≈ 10000 × 1.3〜1.5。可は良の 3/4（おには 1/2）、不可は良の −0.5 〜 −2 倍
//   真打の配点: 100万点 ÷ 音符の数を 10 点単位で切り上げ
void MakeGauge(int course, Fumen& fumen) {
    static const int kClear[5] = {6000, 7000, 7000, 8000, 8000};
    static const double kGood[5] = {1.45, 1.33, 1.45, 1.34, 1.34};
    static const double kOk[5] = {0.75, 0.75, 0.75, 0.5, 0.5};
    static const double kBad[5] = {0.5, 1.0, 1.2, 1.8, 1.8};
    const int c = std::clamp(course, 0, 4);

    int notes = 0;
    for (const FumenMeasure& m : fumen.measures) {
        for (const FumenNote& n : m.notes[0]) {
            if (n.IsHit()) ++notes;
        }
    }
    SetJudgeWindows(c, fumen);
    fumen.hpMax = 10000;
    fumen.hpClear = kClear[c];
    const double good = std::max(1.0, std::round(10000.0 * kGood[c] / std::max(1, notes)));
    fumen.hpGood = int(good);
    fumen.hpOk = std::max(1, int(std::round(good * kOk[c])));
    fumen.hpBad = -std::max(1, int(std::round(good * kBad[c])));
    fumen.shinuti = notes > 0 ? int(std::ceil(1000000.0 / notes / 10.0)) * 10 : 1000;
}

} // namespace

bool ReadTjaInfo(const std::string& path, TjaInfo& out, std::string* error) {
    out = TjaInfo();
    std::vector<std::string> lines;
    if (!ReadLines(path, lines, error)) return false;

    std::string titleJa, subtitleJa;
    int course = kCourseOni;   // COURSE: がなければおに
    int level = 0;
    bool inChart = false;
    for (const std::string& line : lines) {
        if (line.empty()) continue;
        if (line[0] == '#') {
            std::string name, arg;
            SplitCommand(line, name, arg);
            if (name == "START") {
                inChart = true;
                if (Upper(arg) != "P2") out.levels[size_t(course)] = std::clamp(level, 1, 10);
            } else if (name == "END") {
                inChart = false;
            } else if (name == "BRANCHSTART" && inChart) {
                out.branch[size_t(course)] = true;
            }
            continue;
        }
        std::string key, value;
        if (inChart || !SplitHeader(line, key, value)) continue;
        if (key == "TITLE") out.title = value;
        else if (key == "TITLEJA") titleJa = value;
        else if (key == "SUBTITLE") out.subtitle = CleanSubtitle(value);
        else if (key == "SUBTITLEJA") subtitleJa = CleanSubtitle(value);
        else if (key == "WAVE") out.wave = value;
        else if (key == "DEMOSTART") out.demoStart = std::atof(value.c_str());
        else if (key == "GENRE") out.genre = value;
        else if (key == "COURSE") {
            const int c = CourseIndex(value);
            if (c >= 0) course = c;
            level = 0;
        } else if (key == "LEVEL") level = std::atoi(value.c_str());
    }
    if (!titleJa.empty()) out.title = titleJa;
    if (!subtitleJa.empty()) out.subtitle = subtitleJa;
    // GENRE: がなければ、上のフォルダの box.def（#GENRE:）・genre.ini（GenreName=）、それもなければフォルダ名
    if (out.genre.empty()) {
        fs::path dir = fs::u8path(path).parent_path();
        for (int depth = 0; depth < 4 && out.genre.empty() && !dir.empty(); ++depth, dir = dir.parent_path()) {
            std::vector<std::string> defLines;
            std::error_code ec;
            if (fs::exists(dir / "box.def", ec) && ReadLines((dir / "box.def").u8string(), defLines, nullptr)) {
                for (const std::string& l : defLines) {
                    if (Upper(l).rfind("#GENRE:", 0) == 0) out.genre = Trim(l.substr(7));
                }
            }
            if (out.genre.empty() && fs::exists(dir / "genre.ini", ec) && ReadLines((dir / "genre.ini").u8string(), defLines, nullptr)) {
                for (const std::string& l : defLines) {
                    if (Upper(l).rfind("GENRENAME=", 0) == 0) out.genre = Trim(l.substr(10));
                }
            }
        }
        if (out.genre.empty()) out.genre = fs::u8path(path).parent_path().u8string();
    }
    if (out.title.empty()) out.title = fs::u8path(path).stem().u8string();
    if (!out.wave.empty()) out.wave = (fs::u8path(path).parent_path() / fs::u8path(out.wave)).u8string();

    bool any = false;
    for (int l : out.levels) any = any || l > 0;
    if (!any) return Fail(error, "TJA に譜面がありません: " + path);
    return true;
}

bool LoadTja(const std::string& path, int course, Fumen& out, std::string* error) {
    out = Fumen();
    std::vector<std::string> lines;
    if (!ReadLines(path, lines, error)) return false;

    // 目当ての難易度の #START 〜 #END を探す（2人用の譜面は P1 を使う）
    Chart chart;
    int current = kCourseOni;
    std::vector<int> balloons;
    bool inChart = false, found = false, take = false;
    for (const std::string& line : lines) {
        if (line.empty()) continue;
        if (line[0] == '#') {
            std::string name, arg;
            SplitCommand(line, name, arg);
            if (name == "START") {
                inChart = true;
                take = !found && current == course && Upper(arg) != "P2";
                if (take) chart.balloons = balloons;
                continue;
            }
            if (name == "END") {
                inChart = false;
                if (take) found = true;
                take = false;
                continue;
            }
        }
        if (inChart) {
            if (take) chart.lines.push_back(line);
            continue;
        }
        std::string key, value;
        if (!SplitHeader(line, key, value)) continue;
        if (key == "BPM") chart.bpm = std::atof(value.c_str());
        else if (key == "OFFSET") chart.offset = std::atof(value.c_str());
        else if (key == "COURSE") {
            const int c = CourseIndex(value);
            if (c >= 0) current = c;
            balloons.clear();
        } else if (key == "BALLOON" || key == "BALLOONNOR") balloons = ParseBalloons(value);
    }
    if (!found) return Fail(error, "TJA にこの難易度の譜面がありません: " + path);

    // 分岐ごとに読む。普通譜面が measures で、分岐のある譜面は玄人・達人を branchMeasures に丸ごと持つ
    // （分岐のあいだは BPM・スクロール・ゴーゴーも分岐ごとに違ってよいので、小節ごと別に持つ）
    const auto byTime = [](const FumenMeasure& a, const FumenMeasure& b) { return a.time < b.time; };
    ChartParser normal(chart, 0);
    out.measures = normal.Parse();
    out.hasBranches = normal.HasBranches();
    std::stable_sort(out.measures.begin(), out.measures.end(), byTime);
    if (out.hasBranches) {
        out.branches = normal.TakeBranches();
        out.sections = normal.TakeSections();
        out.levelHolds = normal.TakeLevelHolds();
        for (int b = 1; b < 3; ++b) {
            ChartParser other(chart, b);
            out.branchMeasures[size_t(b - 1)] = other.Parse();
            std::stable_sort(out.branchMeasures[size_t(b - 1)].begin(), out.branchMeasures[size_t(b - 1)].end(), byTime);
            for (const FumenLevelHold& hold : other.TakeLevelHolds()) out.levelHolds.push_back(hold);
        }
    }

    MakeGauge(course, out);
    return true;
}

} // namespace GuminTaiko
