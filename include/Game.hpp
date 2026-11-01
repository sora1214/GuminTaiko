#pragma once
#include <string>
#include <vector>
#include <boost/serialization/serialization.hpp>
#include <boost/serialization/vector.hpp>
#include <boost/serialization/string.hpp>

namespace Game {

    // テロップデータ構造体
    struct Telop {
        std::string text;
        int displayTimeMs;

        template<class Archive>
        void serialize(Archive & ar, const unsigned int version) {
            ar & text;
            ar & displayTimeMs;
        }
    };

    // 曲紹介データ構造体
    struct SongIntroduction {
        std::string title;
        std::string subtitle;
        std::vector<Telop> telops;

        template<class Archive>
        void serialize(Archive & ar, const unsigned int version) {
            ar & title;
            ar & subtitle;
            ar & telops;
        }
    };

    // 段位お題データ構造体
    struct DanOdai {
        int targetType; // 例: 0=スコア, 1=良の数 など
        int borderValue; // 基準値

        template<class Archive>
        void serialize(Archive & ar, const unsigned int version) {
            ar & targetType;
            ar & borderValue;
        }
    };

}