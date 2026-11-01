#include "GameSettings.hpp"

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <system_error>

#include "PlayData.hpp"
#include "SoundManager.hpp"
#include "TestMenu.hpp"

namespace {

constexpr const char* kDir = "Backup";
constexpr const char* kPath = "Backup/testmode.ini";
constexpr float kSaveInterval = 60.0f;   // 時間の集計を保存する間隔（秒）

} // namespace

void GameSettings::Load() {
    loaded_ = true;
    defaults_.clear();
    for (const TestMenu::Item* item : TestMenu::Get().SettingItems()) {
        defaults_[item->Attr("id")] = item->Int("default", item->Int("min", 0));
    }
    values_ = defaults_;
    // コイン投入口のない環境で遊べるよう、初めて起動したときはフリープレイにしておく
    values_["ItemFreePlay"] = 1;

    std::ifstream ifs(kPath);
    std::string line;
    while (std::getline(ifs, line)) {
        const size_t eq = line.find('=');
        if (eq == std::string::npos) continue;
        const std::string key = line.substr(0, eq);
        const std::string value = line.substr(eq + 1);
        if (key == "book.powerOn") books_.powerOnSeconds = std::atof(value.c_str());
        else if (key == "book.play") books_.playSeconds = std::atof(value.c_str());
        else if (key == "book.playCount") books_.playCount = std::atoi(value.c_str());
        else if (key == "book.coinCount") books_.coinCount = std::atoi(value.c_str());
        else if (key == "book.serviceCount") books_.serviceCount = std::atoi(value.c_str());
        else if (key == "book.freePlayCount") books_.freePlayCount = std::atoi(value.c_str());
        else if (key == "book.lastUseCredit") books_.lastUseCredit = std::atoi(value.c_str());
        else if (defaults_.count(key)) values_[key] = std::atoi(value.c_str());
    }
    Apply();
}

void GameSettings::Save() const {
    std::error_code ec;
    std::filesystem::create_directories(kDir, ec);
    std::ofstream ofs(kPath, std::ios::trunc);
    if (!ofs) return;
    for (const auto& entry : values_) ofs << entry.first << '=' << entry.second << '\n';
    ofs << "book.powerOn=" << books_.powerOnSeconds << '\n';
    ofs << "book.play=" << books_.playSeconds << '\n';
    ofs << "book.playCount=" << books_.playCount << '\n';
    ofs << "book.coinCount=" << books_.coinCount << '\n';
    ofs << "book.serviceCount=" << books_.serviceCount << '\n';
    ofs << "book.freePlayCount=" << books_.freePlayCount << '\n';
    ofs << "book.lastUseCredit=" << books_.lastUseCredit << '\n';
    dirty_ = false;
}

int GameSettings::Value(const std::string& id) const {
    auto found = values_.find(id);
    return found != values_.end() ? found->second : Default(id);
}

int GameSettings::Default(const std::string& id) const {
    auto found = defaults_.find(id);
    return found != defaults_.end() ? found->second : 0;
}

void GameSettings::SetValue(const std::string& id, int value) {
    values_[id] = value;
    Save();
    Apply();
}

void GameSettings::ResetSettings() {
    values_ = defaults_;
    Save();
    Apply();
}

void GameSettings::Apply() const {
    GuminTaiko::PlayDataManager& pd = GuminTaiko::PlayDataManager::Get();
    pd.SetFreePlay(Value("ItemFreePlay") == 1);
    pd.SetCoinOptions(Value("CoinValueItem"), Value("1PGameCostItem"));
    pd.SetStageCount(Value("NumberOfStageItem"));

    // 音量: 0〜15（初期値 10 が元の大きさ）× 出力レベル（初期値 80％ が元の大きさ）
    const float output = std::clamp(float(Value("OutputLevelSpeakerItem")) / 80.0f, 0.0f, 1.25f);
    const float bgm = float(Value(attract_ ? "VolumeAttractBGMItem" : "VolumeGameBGMItem")) / 10.0f;
    const float se = float(Value(attract_ ? "VolumeAttractSEItem" : "VolumeGameSEItem")) / 10.0f;
    SoundManager::Get().SetVolumes(bgm * output, se * output);
}

void GameSettings::SetAttract(bool attract) {
    if (attract == attract_) return;
    attract_ = attract;
    Apply();
}

void GameSettings::AddPlay(bool freePlay, int credits) {
    ++books_.playCount;
    if (freePlay) ++books_.freePlayCount;
    books_.lastUseCredit = credits;
    Save();
}

void GameSettings::Update(float deltaTime) {
    books_.powerOnSeconds += deltaTime;
    if (playing_) books_.playSeconds += deltaTime;
    saveTimer_ += deltaTime;
    if (saveTimer_ >= kSaveInterval || dirty_) {
        saveTimer_ = 0.0f;
        Save();
    }
}

void GameSettings::ResetBookkeeping() {
    books_ = Bookkeeping();
    Save();
}
