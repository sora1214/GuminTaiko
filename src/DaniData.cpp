#include "DaniData.hpp"

#include <algorithm>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <system_error>

#include "Json.hpp"
#include "SongDatabase.hpp"
#include "raylib.h"

namespace fs = std::filesystem;

namespace GuminTaiko {

namespace {

constexpr const char* kDaniDir = "Dani";
constexpr int kSchemaVersion = 1;

const char* const kNames[kDaniLevelCount + 1] = {"",     "五級", "四級", "三級", "二級", "一級", "初段", "二段", "三段", "四段",
                                                 "五段", "六段", "七段", "八段", "九段", "十段", "玄人", "名人", "超人", "達人", "外伝"};
const char* const kLabels[kDaniLevelCount + 1] = {"none", "5kyuu", "4kyuu", "3kyuu", "2kyuu", "1kyuu", "1dan",  "2dan",  "3dan",  "4dan",
                                                  "5dan", "6dan",  "7dan",  "8dan",  "9dan",  "10dan", "11dan", "12dan", "13dan", "14dan", "gaiden"};
const char* const kTypeNames[] = {"none", "good", "ok", "bad", "combo", "roll", "score", "hit"};
const char* const kTypeKeys[] = {"", "clear_theme_ryo", "clear_theme_ka", "clear_theme_fuka", "clear_theme_combo",
                                 "clear_theme_renda", "clear_theme_score", "clear_theme_total_hit"};
const char* const kCourseNames[] = {"easy", "normal", "hard", "oni", "ura"};

int CourseFromName(const std::string& name) {
    for (int c = 0; c < 5; ++c) {
        if (name == kCourseNames[c]) return c;
    }
    return 3;
}

} // namespace

const char* DaniName(int level) { return kNames[std::clamp(level, 0, kDaniLevelCount)]; }
const char* DaniLabel(int level) { return kLabels[std::clamp(level, 0, kDaniLevelCount)]; }
const char* DaniExamTypeName(DaniExamType type) { return kTypeNames[std::clamp(int(type), 0, 7)]; }
const char* DaniExamTextKey(DaniExamType type) { return kTypeKeys[std::clamp(int(type), 0, 7)]; }

DaniExamType DaniExamTypeFromName(const std::string& name) {
    for (int i = 0; i < 8; ++i) {
        if (name == kTypeNames[i]) return DaniExamType(i);
    }
    return DaniExamType::None;
}

int DaniExamValue(const DaniExam& exam, const DaniRun& run, int song) {
    if (!exam.total) return run.songs[size_t(std::clamp(song, 0, kDaniSongCount - 1))].Value(exam.type);
    int value = 0;
    for (const DaniSongResult& r : run.songs) {
        // コンボは曲をまたいで続くので、通しは最大値（1曲ごとの値に続きのコンボが入っている）
        value = exam.type == DaniExamType::Combo ? std::max(value, r.combo) : value + r.Value(exam.type);
    }
    return value;
}

int DaniExamGrade(const DaniExam& exam, int value, int song) {
    const size_t s = exam.total ? 0 : size_t(std::clamp(song, 0, kDaniSongCount - 1));
    if (exam.LessThan()) {
        if (value < exam.gold[s]) return 2;
        return value < exam.red[s] ? 1 : 0;
    }
    if (value >= exam.gold[s]) return 2;
    return value >= exam.red[s] ? 1 : 0;
}

bool DaniCourse::Playable() const {
    for (const DaniSong& song : songs) {
        if (song.uniqueId < 0) return false;
    }
    return level >= 1 && level <= kDaniLevelCount;
}

bool DaniDatabase::LoadFile(const std::string& path, DaniCourse& out, std::string* error) {
    std::ifstream ifs(fs::u8path(path), std::ios::binary);
    if (!ifs) {
        if (error) *error = "読めません";
        return false;
    }
    std::stringstream text;
    text << ifs.rdbuf();
    Json::Value root;
    if (!Json::Parse(text.str(), root, error) || !root.IsObject()) return false;

    DaniCourse course;
    course.file = path;
    course.level = root["level"].AsInt(0);
    const auto& songs = root["songs"].Items();
    for (size_t i = 0; i < songs.size() && i < size_t(kDaniSongCount); ++i) {
        DaniSong& song = course.songs[i];
        song.tja = songs[i]["tja"].AsString();
        song.course = CourseFromName(songs[i]["course"].AsString("oni"));
        song.hidden = songs[i]["hidden"].AsBool(false);
    }
    course.gaugeRed = std::clamp(root["gauge"]["red"].AsInt(100), 0, 100);
    course.gaugeGold = std::clamp(root["gauge"]["gold"].AsInt(100), 0, 100);
    const auto& exams = root["exams"].Items();
    for (size_t i = 0; i < exams.size() && i < size_t(kDaniExamCount); ++i) {
        DaniExam& exam = course.exams[i];
        exam.type = DaniExamTypeFromName(exams[i]["type"].AsString());
        exam.total = exams[i]["range"].AsString("total") != "song";
        const auto& red = exams[i]["red"].Items();
        const auto& gold = exams[i]["gold"].Items();
        for (size_t s = 0; s < size_t(kDaniSongCount); ++s) {
            // 通しのお題は1つ、1曲ごとは3つ（足りなければ最後の値を使う）
            if (!red.empty()) exam.red[s] = std::max(0, red[std::min(s, red.size() - 1)].AsInt(0));
            if (!gold.empty()) exam.gold[s] = std::max(0, gold[std::min(s, gold.size() - 1)].AsInt(0));
        }
    }
    if (course.level < 1 || course.level > kDaniLevelCount) {
        if (error) *error = "level は 1〜19 にしてください";
        return false;
    }
    out = course;
    return true;
}

bool DaniDatabase::SaveFile(const std::string& path, const DaniCourse& course) {
    Json::Value root = Json::Value::MakeObject();
    root["schemaVersion"] = kSchemaVersion;
    root["level"] = course.level;
    root["name"] = DaniName(course.level);   // 読むときは使わない（見てわかるように）
    Json::Value songs = Json::Value::MakeArray();
    for (const DaniSong& s : course.songs) {
        Json::Value song = Json::Value::MakeObject();
        song["tja"] = s.tja;
        song["course"] = kCourseNames[std::clamp(s.course, 0, 4)];
        song["hidden"] = s.hidden;
        songs.Push(std::move(song));
    }
    root["songs"] = std::move(songs);
    root["gauge"]["red"] = course.gaugeRed;
    root["gauge"]["gold"] = course.gaugeGold;
    Json::Value exams = Json::Value::MakeArray();
    for (const DaniExam& e : course.exams) {
        if (e.type == DaniExamType::None) continue;
        Json::Value exam = Json::Value::MakeObject();
        exam["type"] = DaniExamTypeName(e.type);
        exam["range"] = e.total ? "total" : "song";
        Json::Value red = Json::Value::MakeArray(), gold = Json::Value::MakeArray();
        for (int s = 0; s < (e.total ? 1 : kDaniSongCount); ++s) {
            red.Push(e.red[size_t(s)]);
            gold.Push(e.gold[size_t(s)]);
        }
        exam["red"] = std::move(red);
        exam["gold"] = std::move(gold);
        exams.Push(std::move(exam));
    }
    root["exams"] = std::move(exams);

    std::error_code ec;
    const fs::path file = fs::u8path(path);
    if (file.has_parent_path()) fs::create_directories(file.parent_path(), ec);
    std::ofstream ofs(file, std::ios::binary | std::ios::trunc);
    if (!ofs) return false;
    ofs << Json::Dump(root);
    return bool(ofs);
}

std::string DaniDatabase::DefaultPath(int level) {
    char name[16];
    std::snprintf(name, sizeof(name), "%02d_", level);
    return std::string(kDaniDir) + "/" + name + DaniName(level) + ".json";
}

void DaniDatabase::Load() {
    loaded_ = true;
    has_.fill(false);
    std::error_code ec;
    fs::create_directories(kDaniDir, ec);
    std::vector<fs::path> files;
    for (const auto& entry : fs::directory_iterator(kDaniDir, ec)) {
        if (entry.path().extension() == ".json") files.push_back(entry.path());
    }
    std::sort(files.begin(), files.end());
    for (const fs::path& file : files) {
        DaniCourse course;
        std::string error;
        if (!LoadFile(file.u8string(), course, &error)) {
            TraceLog(LOG_WARNING, "DaniDatabase: %s: %s", file.u8string().c_str(), error.c_str());
            continue;
        }
        for (DaniSong& song : course.songs) {
            const SongInfo* info = song.tja.empty() ? nullptr : SongDatabase::Get().FindSongByTja(song.tja);
            song.uniqueId = info ? info->uniqueId : -1;
            if (!info && !song.tja.empty()) TraceLog(LOG_WARNING, "DaniDatabase: %s の曲 %s がありません", file.u8string().c_str(), song.tja.c_str());
        }
        courses_[size_t(course.level)] = course;
        has_[size_t(course.level)] = true;
    }
}

const DaniCourse* DaniDatabase::Course(int level) {
    if (!loaded_) Load();
    if (level < 1 || level > kDaniLevelCount || !has_[size_t(level)]) return nullptr;
    return &courses_[size_t(level)];
}

void DaniDatabase::Reload() { loaded_ = false; }

} // namespace GuminTaiko
