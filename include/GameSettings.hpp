#pragma once
#include <map>
#include <string>

// 筐体の設定とブックキーピング（テストモードで変える値。Backup/testmode.ini に保存する）
//   設定の項目と初期値は TestMode.xml の group="Setting" の select-item（id / default）から作る。
//   ただしフリープレイは、この移植にはコイン投入口がないので、初めて起動したときは ON にしておく。
// 設定のうちゲームに効くもの:
//   ItemFreePlay / CoinValueItem / 1PGameCostItem → クレジット（PlayData）
//   NumberOfStageItem → 1クレジットで遊べる曲数
//   VolumeGameBGMItem / VolumeGameSEItem / VolumeAttractBGMItem / VolumeAttractSEItem / OutputLevelSpeakerItem → 音量
class GameSettings {
public:
    static GameSettings& Get() {
        static GameSettings instance;
        return instance;
    }

    void Load();
    void Save() const;

    int Value(const std::string& id) const;
    int Default(const std::string& id) const;
    void SetValue(const std::string& id, int value);   // 保存して反映する
    bool Has(const std::string& id) const { return values_.count(id) != 0; }

    // すべての設定を初期値に戻す（BACKUP MEMORY INITIALIZE）
    void ResetSettings();
    // ゲームに反映する（クレジット・曲数・音量）
    void Apply() const;

    // アトラクト中か（音量をアトラクト用にする）
    void SetAttract(bool attract);

    // ---- ブックキーピング ----
    struct Bookkeeping {
        double powerOnSeconds = 0.0;   // 電源が入っていた時間（前回までの合計 + 今回）
        double playSeconds = 0.0;      // 遊ばれていた時間（エントリーからゲームオーバーまで）
        int playCount = 0;             // クレジットを使って遊んだ回数（人数ぶん）
        int coinCount = 0;
        int serviceCount = 0;
        int freePlayCount = 0;
        int lastUseCredit = 0;         // 最後のゲームで使ったクレジット
    };
    const Bookkeeping& Books() const { return books_; }
    void AddCoin() { ++books_.coinCount; dirty_ = true; }
    void AddService() { ++books_.serviceCount; dirty_ = true; }
    void AddPlay(bool freePlay, int credits);
    void SetPlaying(bool playing) { playing_ = playing; }
    void Update(float deltaTime);            // 時間の集計（ときどき保存する）
    void ResetBookkeeping();                 // BOOKKEEPING INITIALIZE

private:
    GameSettings() = default;

    std::map<std::string, int> values_;
    std::map<std::string, int> defaults_;
    Bookkeeping books_;
    bool loaded_ = false;
    bool attract_ = false;
    bool playing_ = false;
    mutable bool dirty_ = false;
    float saveTimer_ = 0.0f;
};
