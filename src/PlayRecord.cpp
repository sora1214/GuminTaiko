#include "PlayRecord.hpp"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <ctime>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <system_error>

#include "Json.hpp"
#include "PlayData.hpp"
#include "raylib.h"

using namespace GuminTaiko;

namespace {

constexpr const char* kDir = "Backup";
constexpr const char* kPath = "Backup/records.ini";
constexpr const char* kPlayersDir = "Backup/players";
constexpr const char* kCoinOwner = "coin";
constexpr int kSchemaVersion = 1;

// JSON に書く名前（lua の EnsoLevelType / CrownType / ScoreRank に合わせる）
const char* const kCourseNames[] = {"easy", "normal", "hard", "oni", "ura"};
const char* const kCrownNames[] = {"none", "clear", "fullcombo", "donderfullcombo"};
const char* const kRankNames[] = {"none", "iki_white", "iki_silver", "iki_gold", "miyabi_white", "miyabi_silver", "miyabi_gold", "kiwami"};
const char* const kRandomNames[] = {"none", "kimagure", "detarame"};
const double kSpeeds[PlayOptions::kSpeedCount] = {1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0, 2.5, 3.0, 3.5, 4.0};

std::string ChartKey(const std::string& songId, int course) { return songId + "/" + std::to_string(course); }

template <size_t N>
int IndexOf(const char* const (&names)[N], const std::string& name, int fallback) {
    for (size_t i = 0; i < N; ++i) {
        if (name == names[i]) return int(i);
    }
    return fallback;
}

std::string CardPath(const std::string& cardId) { return std::string(kPlayersDir) + "/" + cardId + ".json"; }

// いまの日時（ISO 8601、ローカル時刻。例: 2026-09-29T21:05:00+09:00）
std::string Now() {
    const std::time_t t = std::time(nullptr);
    std::tm local{};
    localtime_s(&local, &t);
    // 時差は UTC の日時をローカルとして解いた差から出す（MinGW の %z は時差ではなくタイムゾーン名になる）
    std::tm utc{};
    gmtime_s(&utc, &t);
    utc.tm_isdst = local.tm_isdst;
    const long offset = long(std::difftime(t, std::mktime(&utc)));
    char buf[48];
    std::strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%S", &local);
    char zone[16];
    std::snprintf(zone, sizeof(zone), "%c%02ld:%02ld", offset < 0 ? '-' : '+', std::labs(offset) / 3600, std::labs(offset) % 3600 / 60);
    return std::string(buf) + zone;
}

Json::Value OptionsToJson(const PlayOptions& o) {
    Json::Value j = Json::Value::MakeObject();
    j["speed"] = kSpeeds[std::clamp(o.speed, 0, PlayOptions::kSpeedCount - 1)];
    j["doron"] = o.doron;
    j["abekobe"] = o.abekobe;
    j["random"] = kRandomNames[std::clamp(o.random, 0, 2)];
    j["ensoSkip"] = o.ensoSkip;
    j["notePosition"] = o.notePosition;
    j["voice"] = o.voice;
    j["neiro"] = o.neiro;
    return j;
}

PlayOptions OptionsFromJson(const Json::Value& j) {
    PlayOptions o;
    // はやさは倍率で書いてあるので、いちばん近い選択肢にする
    const double speed = j["speed"].AsNumber(1.0);
    for (int i = 0; i < PlayOptions::kSpeedCount; ++i) {
        if (std::fabs(kSpeeds[i] - speed) < std::fabs(kSpeeds[o.speed] - speed)) o.speed = i;
    }
    o.doron = j["doron"].AsBool(false);
    o.abekobe = j["abekobe"].AsBool(false);
    o.random = IndexOf(kRandomNames, j["random"].AsString("none"), 0);
    o.ensoSkip = j["ensoSkip"].AsBool(false);
    o.notePosition = std::clamp(j["notePosition"].AsInt(0), -5, 5);
    o.voice = j["voice"].AsBool(true);
    o.neiro = std::clamp(j["neiro"].AsInt(0), 0, PlayOptions::kNeiroCount - 1);
    return o;
}

} // namespace

std::string PlayRecords::Owner(int player) {
    const PlayerData& data = PlayDataManager::Get().Player(player);
    return data.userType == UserType::Card && !data.cardId.empty() ? data.cardId : kCoinOwner;
}

// ===========================================================================
// コイン（Backup/records.ini）
//   [coin]
//   disp=難易度
//   option=はやさ,ドロン,あべこべ,ランダム,演奏スキップ,音符位置調整,ボイス,音色
//   曲ID/難易度=スコア,王冠,スコアランク
// ===========================================================================
void PlayRecords::Load() {
    loaded_ = true;
    std::ifstream ifs(kPath);
    std::string line;
    OwnerData* owner = nullptr;
    while (std::getline(ifs, line)) {
        if (!line.empty() && line.back() == '\r') line.pop_back();
        if (line.compare(0, 3, "\xEF\xBB\xBF") == 0) line.erase(0, 3);   // 手で書いた UTF-8 の BOM
        if (line.size() >= 2 && line.front() == '[' && line.back() == ']') {
            // カードの記録は JSON に持つので、ここではコインだけ読む
            owner = line.substr(1, line.size() - 2) == kCoinOwner ? &owners_[kCoinOwner] : nullptr;
            continue;
        }
        const size_t eq = line.find('=');
        if (!owner || eq == std::string::npos) continue;
        const std::string key = line.substr(0, eq);
        const std::string value = line.substr(eq + 1);
        if (key == "disp") {
            owner->dispCourse = std::clamp(std::atoi(value.c_str()), 0, 4);
            continue;
        }
        if (key == "favorites" || key == "recent") {
            std::vector<std::string>& list = key == "favorites" ? owner->favorites : owner->recent;
            list.clear();
            size_t start = 0;
            while (start <= value.size()) {
                const size_t comma = value.find(',', start);
                const std::string id = value.substr(start, comma == std::string::npos ? std::string::npos : comma - start);
                if (!id.empty()) list.push_back(id);
                if (comma == std::string::npos) break;
                start = comma + 1;
            }
            continue;
        }
        if (key == "option") {
            int v[8] = {0, 0, 0, 0, 0, 0, 1, 0};
            std::sscanf(value.c_str(), "%d,%d,%d,%d,%d,%d,%d,%d", &v[0], &v[1], &v[2], &v[3], &v[4], &v[5], &v[6], &v[7]);
            PlayOptions& o = owner->options;
            o.speed = std::clamp(v[0], 0, PlayOptions::kSpeedCount - 1);
            o.doron = v[1] != 0;
            o.abekobe = v[2] != 0;
            o.random = std::clamp(v[3], 0, 2);
            o.ensoSkip = v[4] != 0;
            o.notePosition = std::clamp(v[5], -5, 5);
            o.voice = v[6] != 0;
            o.neiro = std::clamp(v[7], 0, PlayOptions::kNeiroCount - 1);
            continue;
        }
        ChartRecord record;
        if (std::sscanf(value.c_str(), "%d,%d,%d", &record.score, &record.crown, &record.scoreRank) == 3) {
            owner->charts[key] = record;
        }
    }
}

void PlayRecords::SaveCoin() const {
    auto found = owners_.find(kCoinOwner);
    if (found == owners_.end()) return;
    const OwnerData& owner = found->second;
    std::error_code ec;
    std::filesystem::create_directories(kDir, ec);
    std::ofstream ofs(kPath, std::ios::trunc);
    if (!ofs) return;
    ofs << '[' << kCoinOwner << "]\n";
    ofs << "disp=" << owner.dispCourse << '\n';
    const PlayOptions& o = owner.options;
    ofs << "option=" << o.speed << ',' << int(o.doron) << ',' << int(o.abekobe) << ',' << o.random << ',' << int(o.ensoSkip)
        << ',' << o.notePosition << ',' << int(o.voice) << ',' << o.neiro << '\n';
    auto writeList = [&](const char* name, const std::vector<std::string>& list) {
        if (list.empty()) return;
        ofs << name << '=';
        for (size_t i = 0; i < list.size(); ++i) ofs << (i ? "," : "") << list[i];
        ofs << '\n';
    };
    writeList("favorites", owner.favorites);
    writeList("recent", owner.recent);
    for (const auto& [key, record] : owner.charts) {
        ofs << key << '=' << record.score << ',' << record.crown << ',' << record.scoreRank << '\n';
    }
}

// ===========================================================================
// カード（Backup/players/<カードID>.json。1人1ファイル）
// {
//   "schemaVersion": 1,
//   "cardId": "GMN-0001-0001",
//   "registeredAt": "2026-09-29T21:00:00+09:00",   登録した日時
//   "lastPlayedAt": "2026-09-29T21:05:00+09:00",   最後に遊んだ日時（まだなら ""）
//   "profile": {
//     "name": "GuminDon",                          名前
//     "title": "ぐみん道場の師範代",                称号
//     "titleDesign": "wood",                       称号の地のデザイン（wood / rainbow / gold / purple / ai_1〜ai_4）
//     "costume": 5,                                きせかえ（0: いつもの 1: クール 2: キュート 3: ジョーク 5: dress を着る）
//     "dress": {                                   costume が 5 のときに着る着せかえ（着せかえアプリ GuminDressUp で決める）。
//       "kigurumi": -1, "head": 0, "body": 0,      番号は Data/x64/model の番号（don_cos_reward の dataId）。kigurumi が 0 以上なら体と頭を置き換える
//       "face": 0, "faceColor": -1, "bodyColor": -1, "legsColor": -1 }   色は don_color の番号（-1 は初期の色）
//   },
//   "settings": {
//     "dispCrownCourse": "oni",                    王冠・総合成績を見せる難易度（easy / normal / hard / oni / ura）
//     "options": {                                 演奏オプション
//       "speed": 1.0,                              はやさ（1.0〜1.9, 2.0, 2.5, 3.0, 3.5, 4.0）
//       "doron": false, "abekobe": false,
//       "random": "none",                          none / kimagure / detarame
//       "ensoSkip": false,
//       "notePosition": 0,                         音符位置調整（-5: 左5 〜 5: 右5）
//       "voice": true,
//       "neiro": 0                                 音色（0〜19。se_neiro_00〜19）
//     }
//   },
//   "stats": { "playCount": 0 },                   遊んだ曲の数
//   "records": [                                   譜面ごとの自己ベスト
//     { "songId": "tja0001", "course": "ura", "score": 1000000,
//       "crown": "donderfullcombo",                none / clear / fullcombo / donderfullcombo
//       "scoreRank": "kiwami",                     none / iki_white〜iki_gold / miyabi_white〜miyabi_gold / kiwami
//       "playCount": 3 }
//   ]
// }
// ===========================================================================
bool PlayRecords::LoadCard(const std::string& cardId) {
    std::ifstream ifs(CardPath(cardId), std::ios::binary);
    if (!ifs) return false;
    std::stringstream text;
    text << ifs.rdbuf();
    Json::Value root;
    std::string error;
    if (!Json::Parse(text.str(), root, &error) || !root.IsObject()) {
        TraceLog(LOG_WARNING, "PlayRecords: %s を読めません: %s", CardPath(cardId).c_str(), error.c_str());
        return false;
    }

    OwnerData data;
    data.card = true;
    data.registeredAt = root["registeredAt"].AsString();
    data.lastPlayedAt = root["lastPlayedAt"].AsString();
    const Json::Value& profile = root["profile"];
    data.name = profile["name"].AsString();
    data.title = profile["title"].AsString();
    data.titleDesign = 0;
    for (int i = 0; i < kTitleDesignCount; ++i) {
        if (profile["titleDesign"].AsString("wood") == TitleDesignLabel(i)) data.titleDesign = i;
    }
    data.costume = std::clamp(profile["costume"].AsInt(0), 0, kDonCostumeCustom);
    const Json::Value& dress = profile["dress"];
    data.dress.kigurumi = dress["kigurumi"].AsInt(-1);
    data.dress.head = dress["head"].AsInt(0);
    data.dress.body = dress["body"].AsInt(0);
    data.dress.face = dress["face"].AsInt(0);
    data.dress.faceColor = dress["faceColor"].AsInt(-1);
    data.dress.bodyColor = dress["bodyColor"].AsInt(-1);
    data.dress.legsColor = dress["legsColor"].AsInt(-1);
    const Json::Value& settings = root["settings"];
    data.dispCourse = IndexOf(kCourseNames, settings["dispCrownCourse"].AsString("oni"), 3);
    data.options = OptionsFromJson(settings["options"]);
    data.playCount = root["stats"]["playCount"].AsInt(0);
    for (const Json::Value& item : root["songLists"]["favorites"].Items()) {
        if (!item.AsString().empty()) data.favorites.push_back(item.AsString());
    }
    for (const Json::Value& item : root["songLists"]["recent"].Items()) {
        if (!item.AsString().empty()) data.recent.push_back(item.AsString());
    }
    for (const Json::Value& item : root["records"].Items()) {
        const std::string songId = item["songId"].AsString();
        const int course = IndexOf(kCourseNames, item["course"].AsString(), -1);
        if (songId.empty() || course < 0) continue;
        ChartRecord record;
        record.score = std::max(0, item["score"].AsInt(0));
        record.crown = IndexOf(kCrownNames, item["crown"].AsString("none"), 0);
        record.scoreRank = IndexOf(kRankNames, item["scoreRank"].AsString("none"), 0);
        record.playCount = std::max(0, item["playCount"].AsInt(0));
        data.charts[ChartKey(songId, course)] = record;
    }
    for (const Json::Value& item : root["dani"]["records"].Items()) {
        const int level = item["level"].AsInt(0);
        if (level < 1 || level > 19) continue;
        DaniRecord record;
        record.rank = std::clamp(item["rank"].AsInt(0), 0, 7);
        record.gauge = std::clamp(item["gauge"].AsInt(0), 0, 100);
        record.arrival = std::clamp(item["arrival"].AsInt(0), 0, 3);
        const auto& songs = item["songs"].Items();
        for (size_t s = 0; s < songs.size() && s < 3; ++s) {
            DaniSongResult& r = record.songs[s];
            r.good = songs[s]["good"].AsInt(0);
            r.ok = songs[s]["ok"].AsInt(0);
            r.bad = songs[s]["bad"].AsInt(0);
            r.combo = songs[s]["combo"].AsInt(0);
            r.roll = songs[s]["roll"].AsInt(0);
            r.score = songs[s]["score"].AsInt(0);
            r.hit = songs[s]["hit"].AsInt(0);
        }
        data.dani[level] = record;
    }
    owners_[cardId] = std::move(data);
    return true;
}

void PlayRecords::SaveCard(const std::string& cardId) const {
    auto found = owners_.find(cardId);
    if (found == owners_.end()) return;
    const OwnerData& data = found->second;

    Json::Value root = Json::Value::MakeObject();
    root["schemaVersion"] = kSchemaVersion;
    root["cardId"] = cardId;
    root["registeredAt"] = data.registeredAt;
    root["lastPlayedAt"] = data.lastPlayedAt;
    Json::Value& profile = root["profile"];
    profile["name"] = data.name;
    profile["title"] = data.title;
    profile["titleDesign"] = TitleDesignLabel(data.titleDesign);
    profile["costume"] = data.costume;
    Json::Value& dress = profile["dress"];
    dress["kigurumi"] = data.dress.kigurumi;
    dress["head"] = data.dress.head;
    dress["body"] = data.dress.body;
    dress["face"] = data.dress.face;
    dress["faceColor"] = data.dress.faceColor;
    dress["bodyColor"] = data.dress.bodyColor;
    dress["legsColor"] = data.dress.legsColor;
    Json::Value& settings = root["settings"];
    settings["dispCrownCourse"] = kCourseNames[std::clamp(data.dispCourse, 0, 4)];
    settings["options"] = OptionsToJson(data.options);
    root["stats"]["playCount"] = data.playCount;
    {
        Json::Value favorites = Json::Value::MakeArray();
        for (const std::string& id : data.favorites) favorites.Push(Json::Value(id));
        Json::Value recent = Json::Value::MakeArray();
        for (const std::string& id : data.recent) recent.Push(Json::Value(id));
        root["songLists"]["favorites"] = std::move(favorites);
        root["songLists"]["recent"] = std::move(recent);
    }
    Json::Value records = Json::Value::MakeArray();
    for (const auto& [key, record] : data.charts) {
        const size_t slash = key.rfind('/');
        if (slash == std::string::npos) continue;
        Json::Value item = Json::Value::MakeObject();
        item["songId"] = key.substr(0, slash);
        item["course"] = kCourseNames[std::clamp(std::atoi(key.c_str() + slash + 1), 0, 4)];
        item["score"] = record.score;
        item["crown"] = kCrownNames[std::clamp(record.crown, 0, 3)];
        item["scoreRank"] = kRankNames[std::clamp(record.scoreRank, 0, 7)];
        item["playCount"] = record.playCount;
        records.Push(std::move(item));
    }
    root["records"] = std::move(records);
    // 段位道場
    Json::Value dani = Json::Value::MakeArray();
    for (const auto& [level, record] : data.dani) {
        Json::Value item = Json::Value::MakeObject();
        item["level"] = level;
        item["rank"] = record.rank;
        item["gauge"] = record.gauge;
        item["arrival"] = record.arrival;
        Json::Value songs = Json::Value::MakeArray();
        for (const DaniSongResult& r : record.songs) {
            Json::Value s = Json::Value::MakeObject();
            s["good"] = r.good;
            s["ok"] = r.ok;
            s["bad"] = r.bad;
            s["combo"] = r.combo;
            s["roll"] = r.roll;
            s["score"] = r.score;
            s["hit"] = r.hit;
            songs.Push(std::move(s));
        }
        item["songs"] = std::move(songs);
        dani.Push(std::move(item));
    }
    int now = 0;
    for (const auto& [level, record] : data.dani) {
        if (record.rank >= 2) now = std::max(now, level);
    }
    root["dani"]["now"] = now;
    root["dani"]["records"] = std::move(dani);

    std::error_code ec;
    std::filesystem::create_directories(kPlayersDir, ec);
    // 書いている途中で止まっても元のファイルが壊れないよう、別の名前に書いてから置き換える
    const std::string path = CardPath(cardId);
    const std::string temp = path + ".tmp";
    {
        std::ofstream ofs(temp, std::ios::binary | std::ios::trunc);
        if (!ofs) return;
        ofs << Json::Dump(root);
    }
    std::filesystem::rename(temp, path, ec);
    if (ec) TraceLog(LOG_WARNING, "PlayRecords: %s に書けません", path.c_str());
}

bool PlayRecords::RegisterCard(const std::string& cardId, const std::string& name) {
    if (cardId.empty() || cardId == kCoinOwner) return false;
    // 登録する前に遊んだ記録・演奏オプション（まだ保存していないもの）はそのまま引き継ぐ
    OwnerData& data = *Data(cardId, true);
    if (!data.card) {
        data.card = true;
        data.registeredAt = Now();
    }
    data.name = name;
    SaveCard(cardId);
    std::error_code ec;
    return std::filesystem::exists(CardPath(cardId), ec);
}

PlayRecords::OwnerData* PlayRecords::Data(const std::string& owner, bool create) {
    if (!loaded_) Load();
    if (auto found = owners_.find(owner); found != owners_.end()) return &found->second;
    if (owner != kCoinOwner) {
        if (owners_.count(owner) || LoadCard(owner)) return &owners_[owner];
        // 登録されていないカード（F4 の新しいカードなど）はまだ保存しない（サーバーの登録を作るまで）
        if (!create) return nullptr;
        OwnerData& data = owners_[owner];
        data.card = false;
        return &data;
    }
    return create ? &owners_[owner] : nullptr;
}

void PlayRecords::Save(const std::string& owner) const {
    auto found = owners_.find(owner);
    if (found == owners_.end()) return;
    if (found->second.card) SaveCard(owner);
    else if (owner == kCoinOwner) SaveCoin();
}

// ===========================================================================
// 読み書き
// ===========================================================================
bool PlayRecords::Card(const std::string& cardId, CardProfile& out) {
    const OwnerData* data = Data(cardId, false);
    if (!data || !data->card) return false;
    out = CardProfile{cardId, false, data->name, data->title, data->costume, data->titleDesign, data->dress};
    return true;
}

std::vector<std::string> PlayRecords::CardIds() {
    if (!loaded_) Load();
    std::vector<std::string> ids;
    std::error_code ec;
    for (const auto& entry : std::filesystem::directory_iterator(kPlayersDir, ec)) {
        if (entry.path().extension() == ".json") ids.push_back(entry.path().stem().string());
    }
    std::sort(ids.begin(), ids.end());
    return ids;
}

bool PlayRecords::SetCard(const CardProfile& profile) {
    OwnerData* data = Data(profile.cardId, false);
    if (!data || !data->card) return false;
    data->name = profile.name;
    data->title = profile.title;
    data->titleDesign = profile.titleDesign;
    data->costume = profile.costume;
    data->dress = profile.dress;
    SaveCard(profile.cardId);
    return true;
}

const ChartRecord* PlayRecords::Find(const std::string& owner, const std::string& songId, int course) {
    const OwnerData* data = Data(owner, false);
    if (!data) return nullptr;
    auto chart = data->charts.find(ChartKey(songId, course));
    return chart != data->charts.end() ? &chart->second : nullptr;
}

void PlayRecords::Add(const std::string& owner, const std::string& songId, int course, const ChartRecord& result) {
    OwnerData& data = *Data(owner, true);
    data.dispCourse = std::clamp(course, 0, 4);
    ChartRecord& record = data.charts[ChartKey(songId, course)];
    record.score = std::max(record.score, result.score);
    record.crown = std::max(record.crown, result.crown);
    record.scoreRank = std::max(record.scoreRank, result.scoreRank);
    ++record.playCount;
    ++data.playCount;
    data.lastPlayedAt = Now();
    Save(owner);
}

RecordTotals PlayRecords::Totals(const std::string& owner, int course) {
    RecordTotals totals;
    const OwnerData* data = Data(owner, false);
    if (!data) return totals;
    const std::string suffix = "/" + std::to_string(course);
    for (const auto& [key, record] : data->charts) {
        if (key.size() <= suffix.size() || key.compare(key.size() - suffix.size(), suffix.size(), suffix) != 0) continue;
        for (int crown = 1; crown <= std::min(record.crown, 3); ++crown) ++totals.crown[size_t(crown)];
        if (record.scoreRank >= 1 && record.scoreRank <= 7) ++totals.scoreRank[size_t(record.scoreRank)];
    }
    return totals;
}

int PlayRecords::DispCourse(const std::string& owner) {
    const OwnerData* data = Data(owner, false);
    return data ? data->dispCourse : 3;
}

DaniRecord PlayRecords::Dani(const std::string& owner, int level) {
    const OwnerData* data = Data(owner, false);
    if (!data) return DaniRecord();
    auto found = data->dani.find(level);
    return found != data->dani.end() ? found->second : DaniRecord();
}

int PlayRecords::NowDani(const std::string& owner) {
    const OwnerData* data = Data(owner, false);
    int now = 0;
    if (data) {
        for (const auto& [level, record] : data->dani) {
            if (record.rank >= 2 && level <= kDaniMaxRank) now = std::max(now, level);   // 外伝は段位に数えない
        }
    }
    return now;
}

bool PlayRecords::AddDani(const std::string& owner, int level, const DaniRecord& result) {
    OwnerData* data = Data(owner, false);
    if (!data || !data->card) return false;   // 段位はカードだけ
    const int before = NowDani(owner);
    DaniRecord& record = data->dani[level];
    if (result.rank > record.rank || (result.rank == record.rank && result.gauge > record.gauge)) {
        const int arrival = std::max(record.arrival, result.arrival);
        record = result;
        record.arrival = arrival;
    } else {
        record.arrival = std::max(record.arrival, result.arrival);
        record.rank = std::max(record.rank, std::min(result.rank, 1));
    }
    data->lastPlayedAt = Now();
    Save(owner);
    return NowDani(owner) > before;
}

PlayOptions PlayRecords::Options(const std::string& owner) {
    const OwnerData* data = Data(owner, false);
    return data ? data->options : PlayOptions();
}

std::vector<std::string> PlayRecords::Favorites(const std::string& owner) {
    const OwnerData* data = Data(owner, false);
    return data ? data->favorites : std::vector<std::string>();
}

std::vector<std::string> PlayRecords::Recent(const std::string& owner) {
    const OwnerData* data = Data(owner, false);
    return data ? data->recent : std::vector<std::string>();
}

bool PlayRecords::IsFavorite(const std::string& owner, const std::string& songId) {
    const OwnerData* data = Data(owner, false);
    return data && std::find(data->favorites.begin(), data->favorites.end(), songId) != data->favorites.end();
}

bool PlayRecords::ToggleFavorite(const std::string& owner, const std::string& songId) {
    OwnerData* data = Data(owner, true);
    auto found = std::find(data->favorites.begin(), data->favorites.end(), songId);
    const bool added = found == data->favorites.end();
    if (added) data->favorites.push_back(songId);
    else data->favorites.erase(found);
    Save(owner);
    return added;
}

void PlayRecords::AddRecent(const std::string& owner, const std::string& songId) {
    OwnerData* data = Data(owner, true);
    data->recent.erase(std::remove(data->recent.begin(), data->recent.end(), songId), data->recent.end());
    data->recent.insert(data->recent.begin(), songId);
    if (data->recent.size() > kRecentMax) data->recent.resize(kRecentMax);
    Save(owner);
}

void PlayRecords::SetOptions(const std::string& owner, const PlayOptions& options) {
    Data(owner, true)->options = options;
    Save(owner);
}
