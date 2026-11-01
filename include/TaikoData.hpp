#pragma once
#include <string>
#include <vector>
#include <cstdint>

namespace GuminTaiko {

    // テロップ構造体
    struct Telop {
        std::string text;
        float startTimeSec;
        float durationSec;
    };

    // 曲紹介構造体
    struct SongIntroduction {
        std::string title;
        std::string subtitle;
        std::string detailNotice;
        std::vector<Telop> telops;
    };

    // 段位お題Enum
    enum class DanOdaiType : uint32_t {
        Score = 0,
        GoodCount = 1,
        OkCount = 2,
        BadCount = 3,
        MaxCombo = 4,
        TotalHits = 5
    };

    // 段位お題構造体
    struct DanOdai {
        DanOdaiType type;
        uint32_t borderRed;
        uint32_t borderGold;
    };

} // namespace GuminTaiko