#include "DonCostume.hpp"

#include <algorithm>
#include <array>
#include <cstdio>
#include <cstdlib>

#include "DataTable.hpp"
#include "WordList.hpp"
#include "raylib.h"

namespace DonCatalog {

namespace {

constexpr const char* kRewardPath = "Data/x64/datatable/don_cos_reward.bin";
constexpr const char* kColorPath = "Data/x64/datatable/don_color.bin";
constexpr const char* kModelRoot = "Data/x64/model/";

std::string Id6(int id) {
    char buf[16];
    std::snprintf(buf, sizeof(buf), "%06d", id);
    return buf;
}

// モデルのファイルがあるか（ないものは着られないので一覧に出さない）
bool ModelExists(Kind kind, int dataId) {
    const std::string id = Id6(dataId);
    switch (kind) {
    case Kind::Kigurumi: return DirectoryExists((std::string(kModelRoot) + "cos/cos_" + id).c_str());
    case Kind::Head: return DirectoryExists((std::string(kModelRoot) + "head/head_" + id).c_str());
    case Kind::Body: return DirectoryExists((std::string(kModelRoot) + "body/body_" + id).c_str());
    case Kind::Face: return FileExists((std::string(kModelRoot) + "face/face_" + id + ".nutexb").c_str());
    default: return false;
    }
}

const std::array<std::vector<Entry>, size_t(Kind::Count)>& Load() {
    static std::array<std::vector<Entry>, size_t(Kind::Count)> lists;
    static bool loaded = false;
    if (loaded) return lists;
    loaded = true;
    lists[size_t(Kind::Kigurumi)].push_back(Entry{-1, "なし"});
    static const char* const kTypes[] = {"kigurumi", "head", "body", "face"};
    for (const DataTable::Item& item : DataTable::Load(kRewardPath)) {
        const std::string type = item.Text("cosType");
        for (int k = 0; k < int(Kind::Count); ++k) {
            if (type != kTypes[k]) continue;
            const int dataId = item.Int("dataId", -1);
            if (dataId < 0 || !ModelExists(Kind(k), dataId)) break;
            Entry entry;
            entry.dataId = dataId;
            entry.name = WordList::Get().Text("costume_" + type + "_" + std::to_string(item.Int("uniqueId")));
            lists[size_t(k)].push_back(entry);
            break;
        }
    }
    TraceLog(LOG_INFO, "DonCatalog: きぐるみ %zu / 頭 %zu / 体 %zu / 顔 %zu", lists[0].size() - 1, lists[1].size(), lists[2].size(),
             lists[3].size());
    return lists;
}

} // namespace

const std::vector<Entry>& Items(Kind kind) { return Load()[size_t(kind)]; }

namespace {
const std::vector<std::array<unsigned char, 3>>& Colors() {
    static std::vector<std::array<unsigned char, 3>> colors;
    static bool loaded = false;
    if (!loaded) {
        loaded = true;
        auto byte = [](const DataTable::Item& item, const char* key) {
            const float v = float(std::atof(item.Text(key).c_str()));
            return static_cast<unsigned char>(v <= 1.0f ? v * 255.0f + 0.5f : v);
        };
        for (const DataTable::Item& item : DataTable::Load(kColorPath)) {
            colors.push_back({byte(item, "red"), byte(item, "green"), byte(item, "blue")});
        }
    }
    return colors;
}
} // namespace

int ColorCount() { return int(Colors().size()); }

void ColorRgb(int index, unsigned char& r, unsigned char& g, unsigned char& b) {
    const auto& colors = Colors();
    if (index < 0 || index >= int(colors.size())) {
        r = g = b = 255;
        return;
    }
    r = colors[size_t(index)][0];
    g = colors[size_t(index)][1];
    b = colors[size_t(index)][2];
}

int IndexOf(Kind kind, int dataId) {
    const std::vector<Entry>& items = Items(kind);
    for (size_t i = 0; i < items.size(); ++i) {
        if (items[i].dataId == dataId) return int(i);
    }
    return 0;
}

const char* FieldName(Field field) {
    static const char* const kNames[] = {"きぐるみ", "あたま", "からだ", "かお", "かおのいろ", "からだのいろ", "ふちのいろ"};
    return kNames[std::clamp(int(field), 0, int(Field::Count) - 1)];
}

namespace {
Kind KindOf(Field field) {
    switch (field) {
    case Field::Kigurumi: return Kind::Kigurumi;
    case Field::Head: return Kind::Head;
    case Field::Body: return Kind::Body;
    default: return Kind::Face;
    }
}
int* ValuePtr(DonCostume& c, Field field) {
    switch (field) {
    case Field::Kigurumi: return &c.kigurumi;
    case Field::Head: return &c.head;
    case Field::Body: return &c.body;
    case Field::Face: return &c.face;
    case Field::FaceColor: return &c.faceColor;
    case Field::BodyColor: return &c.bodyColor;
    default: return &c.legsColor;
    }
}
bool IsColor(Field field) { return field == Field::FaceColor || field == Field::BodyColor || field == Field::LegsColor; }
} // namespace

std::string ValueText(const DonCostume& costume, Field field) {
    DonCostume c = costume;
    const int value = *ValuePtr(c, field);
    if (IsColor(field)) return value < 0 ? "いつもの色" : "いろ " + std::to_string(value + 1);
    const std::vector<Entry>& items = Items(KindOf(field));
    const int index = IndexOf(KindOf(field), value);
    return index < int(items.size()) ? items[size_t(index)].name : "";
}

void Step(DonCostume& costume, Field field, int direction) {
    int& value = *ValuePtr(costume, field);
    if (IsColor(field)) {
        // -1（いつもの色）, 0 〜 ColorCount-1 を回る
        const int count = ColorCount() + 1;
        value = ((value + 1 + direction) % count + count) % count - 1;
        return;
    }
    const std::vector<Entry>& items = Items(KindOf(field));
    if (items.empty()) return;
    const int count = int(items.size());
    const int index = ((IndexOf(KindOf(field), value) + direction) % count + count) % count;
    value = items[size_t(index)].dataId;
}

bool FieldUsed(const DonCostume& costume, Field field) {
    return costume.kigurumi < 0 || (field != Field::Head && field != Field::Body);
}

} // namespace DonCatalog
