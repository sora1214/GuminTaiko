#include "Fumen.hpp"

#include <cstdint>
#include <cstring>
#include <fstream>

namespace GuminTaiko {

namespace {

constexpr size_t kHeaderSize = 0x208;
constexpr size_t kMeasureHeaderSize = 40;
constexpr size_t kNoteSize = 24;
constexpr size_t kRollExtra = 8;

class Reader {
public:
    explicit Reader(std::vector<char> data) : data_(std::move(data)) {}
    bool Has(size_t pos, size_t size) const { return pos + size <= data_.size(); }
    template <typename T>
    T Read(size_t pos) const {
        T value{};
        if (Has(pos, sizeof(T))) std::memcpy(&value, &data_[pos], sizeof(T));
        return value;
    }
    size_t Size() const { return data_.size(); }

private:
    std::vector<char> data_;
};

NoteType ToNoteType(uint32_t type) {
    switch (type) {
    case 0x1: return NoteType::Don;
    case 0x2: return NoteType::Do;
    case 0x3: return NoteType::Ko;
    case 0x4: return NoteType::Katsu;
    case 0x5: return NoteType::Ka;
    case 0x6: case 0x62: return NoteType::Roll;
    case 0x7: return NoteType::BigDon;
    case 0x8: return NoteType::BigKatsu;
    case 0x9: return NoteType::BigRoll;
    case 0xA: return NoteType::Balloon;
    case 0xB: return NoteType::HandDon;
    case 0xC: return NoteType::Kusudama;
    case 0xD: return NoteType::HandKatsu;
    default: return NoteType::None;
    }
}

bool Fail(std::string* error, const std::string& message) {
    if (error) *error = message;
    return false;
}

} // namespace

void SetJudgeWindows(int course, Fumen& fumen) {
    static const float kWindows[2][3] = {{41.708f, 75.075f, 125.125f},    // かんたん・ふつう
                                         {25.025f, 58.392f, 108.442f}};   // むずかしい・おに・おに（裏）
    const int group = course <= 1 ? 0 : 1;
    for (int i = 0; i < 3; ++i) fumen.windows[size_t(i)] = kWindows[group][i];
}

std::string FumenPath(const std::string& songId, int course) {
    static const char* const kSuffix[] = {"e", "n", "h", "m", "x"};
    const int index = course < 0 || course > 4 ? 0 : course;
    return "Data/x64/fumen/" + songId + "/" + songId + "_" + kSuffix[index] + ".bin";
}

bool LoadFumen(const std::string& path, Fumen& out, std::string* error) {
    out = Fumen();
    std::ifstream ifs(path, std::ios::binary);
    if (!ifs) return Fail(error, "譜面を開けません: " + path);
    Reader r(std::vector<char>((std::istreambuf_iterator<char>(ifs)), std::istreambuf_iterator<char>()));
    if (r.Size() < kHeaderSize) return Fail(error, "譜面が短すぎます: " + path);

    for (int i = 0; i < 3; ++i) out.windows[size_t(i)] = r.Read<float>(size_t(i) * 4);
    out.hasBranches = r.Read<int32_t>(0x1B0) != 0;
    out.hpMax = r.Read<int32_t>(0x1B4);
    out.hpClear = r.Read<int32_t>(0x1B8);
    out.hpGood = r.Read<int32_t>(0x1BC);
    out.hpOk = r.Read<int32_t>(0x1C0);
    out.hpBad = r.Read<int32_t>(0x1C4);
    const uint32_t count = r.Read<uint32_t>(0x200);

    size_t pos = kHeaderSize;
    for (uint32_t m = 0; m < count; ++m) {
        if (!r.Has(pos, kMeasureHeaderSize)) return Fail(error, "譜面の小節が途中で切れています: " + path);
        FumenMeasure measure;
        measure.bpm = r.Read<float>(pos);
        if (!(measure.bpm > 0.0)) measure.bpm = 120.0;
        const double measureLength = 240000.0 / measure.bpm;
        measure.time = r.Read<float>(pos + 4) + measureLength;
        measure.gogo = r.Read<uint8_t>(pos + 8) != 0;
        measure.barline = r.Read<uint8_t>(pos + 9) != 0;
        for (int i = 0; i < 6; ++i) measure.branchInfo[size_t(i)] = r.Read<int32_t>(pos + 12 + size_t(i) * 4);
        pos += kMeasureHeaderSize;

        for (int b = 0; b < 3; ++b) {
            if (!r.Has(pos, 8)) return Fail(error, "譜面の分岐が途中で切れています: " + path);
            const uint16_t notes = r.Read<uint16_t>(pos);
            measure.scroll[size_t(b)] = r.Read<float>(pos + 4);
            pos += 8;
            for (uint16_t n = 0; n < notes; ++n) {
                if (!r.Has(pos, kNoteSize)) return Fail(error, "譜面の音符が途中で切れています: " + path);
                const uint32_t rawType = r.Read<uint32_t>(pos);
                FumenNote note;
                note.type = ToNoteType(rawType);
                note.time = measure.time + r.Read<float>(pos + 4);
                note.hits = r.Read<uint16_t>(pos + 16);
                note.duration = r.Read<float>(pos + 20);
                note.bpm = measure.bpm;
                note.scroll = measure.scroll[size_t(b)];
                note.gogo = measure.gogo;
                pos += kNoteSize;
                if (rawType == 0x6 || rawType == 0x9 || rawType == 0x62) pos += kRollExtra;
                if (note.type != NoteType::None) measure.notes[size_t(b)].push_back(note);
            }
        }
        out.measures.push_back(std::move(measure));
    }
    return true;
}

} // namespace GuminTaiko
