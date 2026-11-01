#include <iostream>
#include <fstream>
#include <vector>
#include "TaikoData.hpp"

namespace GuminTaiko {

    static std::string ReadString(std::ifstream& ifs) {
        uint32_t length = 0;
        ifs.read(reinterpret_cast<char*>(&length), sizeof(length));
        if (length == 0 || !ifs) return "";

        std::string str(length, '\0');
        ifs.read(&str[0], length);
        return str;
    }

    bool LoadSongIntroduction(const std::string& filepath, SongIntroduction& outData) {
        std::ifstream ifs(filepath, std::ios::binary);
        if (!ifs) {
            std::cerr << "[Error] 楽曲データファイルが開けません: " << filepath << std::endl;
            return false;
        }

        try {
            outData.title = ReadString(ifs);
            outData.subtitle = ReadString(ifs);
            outData.detailNotice = ReadString(ifs);

            uint32_t telopCount = 0;
            ifs.read(reinterpret_cast<char*>(&telopCount), sizeof(telopCount));
            outData.telops.resize(telopCount);

            for (uint32_t i = 0; i < telopCount; ++i) {
                outData.telops[i].text = ReadString(ifs);
                ifs.read(reinterpret_cast<char*>(&outData.telops[i].startTimeSec), sizeof(float));
                ifs.read(reinterpret_cast<char*>(&outData.telops[i].durationSec), sizeof(float));
            }
        } catch (const std::exception& e) {
            std::cerr << "[Error] データ読み込み失敗: " << e.what() << std::endl;
            return false;
        }
        return true;
    }

    bool LoadDanOdai(const std::string& filepath, std::vector<DanOdai>& outOdaiList) {
        std::ifstream ifs(filepath, std::ios::binary);
        if (!ifs) return false;

        try {
            uint32_t count = 0;
            ifs.read(reinterpret_cast<char*>(&count), sizeof(count));
            outOdaiList.resize(count);

            for (uint32_t i = 0; i < count; ++i) {
                ifs.read(reinterpret_cast<char*>(&outOdaiList[i].type), sizeof(DanOdaiType));
                ifs.read(reinterpret_cast<char*>(&outOdaiList[i].borderRed), sizeof(uint32_t));
                ifs.read(reinterpret_cast<char*>(&outOdaiList[i].borderGold), sizeof(uint32_t));
            }
        } catch (const std::exception& e) {
            std::cerr << "[Error] 段位お題パース失敗: " << e.what() << std::endl;
            return false;
        }
        return true;
    }

} // namespace GuminTaiko