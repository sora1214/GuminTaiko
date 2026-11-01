#pragma once
#include <map>
#include <string>

#include "DaniData.hpp"
#include "DonCostume.hpp"
#include "GameSettings.hpp"

namespace GuminTaiko {

// エントリー種別（lua: UserType）
enum class UserType { None, Coin, Card };

// 遊ぶモード（lua: GameMode）
enum class GameMode { Enso, Dani, AI };

// 称号の地のデザイン（lua: NamePlate の titlebase_name。user_data.title_base_id の番号順）。
// ai_1〜4 は AI バトル演奏の段位の地
constexpr int kTitleDesignCount = 8;
inline const char* TitleDesignLabel(int id) {
    static const char* const kLabels[kTitleDesignCount] = {"wood", "rainbow", "gold", "purple", "ai_1", "ai_2", "ai_3", "ai_4"};
    return kLabels[id >= 0 && id < kTitleDesignCount ? id : 0];
}

// バナパスポートから読み込んだ情報
struct CardProfile {
    std::string cardId;
    bool isNew = false;  // はじめて使うカード（名前入力へ進む）
    std::string name;
    std::string title;   // 称号
    int costume = 0;     // きせかえ（0〜3: 組 4: おまかせ 5: dress を着る）
    int titleDesign = 0; // 称号の地のデザイン（TitleDesignLabel の番号）
    DonCostume dress;    // 着せかえアプリで決めた着せかえ（costume が 5 のとき）
};

// 演奏オプション（lua: user_setting_Original_data_ の speed / dron / reverse / randomlv / ensoSkip /
// noteDrawAdjust / voiceSkip / neiro。値は選択肢の番号で、0 が初期値）
struct PlayOptions {
    static constexpr int kSpeedCount = 15;   // 1.0〜1.9, 2.0, 2.5, 3.0, 3.5, 4.0
    static constexpr int kNeiroCount = 20;   // se_neiro_00〜19
    int speed = 0;
    bool doron = false;        // 音符が見えない
    bool abekobe = false;      // ドンとカッが入れ替わる
    int random = 0;            // 0: なし 1: きまぐれ 2: でたらめ
    bool ensoSkip = false;     // つかっていない太鼓のフチを左右交互に 10 回で演奏を終える（1人のときだけ）
    int notePosition = 0;      // 音符位置調整（-5: 左5 〜 5: 右5）
    bool voice = true;         // ボイス（なし: 自分の打音と曲以外の音を消す）
    int neiro = 0;             // 音色（se_neiro_XX）

    float SpeedValue() const {
        static const float kSpeeds[kSpeedCount] = {1.0f, 1.1f, 1.2f, 1.3f, 1.4f, 1.5f, 1.6f, 1.7f,
                                                   1.8f, 1.9f, 2.0f, 2.5f, 3.0f, 3.5f, 4.0f};
        return kSpeeds[speed >= 0 && speed < kSpeedCount ? speed : 0];
    }
};

// プレイヤー1人分のエントリー情報（lua: PlayDataManager.GetEntryPlayData）
struct PlayerData {
    UserType userType = UserType::None;
    bool isUseCredit = false;
    bool isNewData = false;
    std::string cardId;
    std::string name;
    std::string title;
    int titleDesign = 0;    // 称号の地のデザイン（TitleDesignLabel の番号）
    int costume = 0;        // きせかえ（0: いつもの 1: クール 2: キュート 3: ジョーク 4: おまかせ 5: じぶんで）
    int kigurumi = -1;      // おまかせで選ばれたきぐるみ（cos_* の番号）
    DonCostume dress;       // じぶんで選んだ着せかえ（costume が 5 のとき。すべてのパーツから選べる）
    PlayOptions options;    // 演奏オプション（選曲画面で記録から読み、変えたら記録に書く）
};

// シーンをまたいで保持するプレイデータ（lua: PlayDataManager）
class PlayDataManager {
public:
    static PlayDataManager& Get() {
        static PlayDataManager instance;
        return instance;
    }

    PlayerData& Player(int index) { return players_[index]; }
    const PlayerData& Player(int index) const { return players_[index]; }

    // クレジット（テストモードの COIN OPTIONS。1コインで CoinValue クレジット、1人 GameCost クレジット）
    int Coins() const { return coins_; }
    void InsertCoin() { coins_ += coinValue_; }
    void AddServiceCredit() { ++coins_; }
    int GameCost() const { return gameCost_; }
    void SetCoinOptions(int coinValue, int gameCost) {
        coinValue_ = coinValue < 1 ? 1 : coinValue;
        gameCost_ = gameCost < 1 ? 1 : gameCost;
    }
    bool IsFreePlay() const { return freePlay_; }
    void SetFreePlay(bool flag) { freePlay_ = flag; }
    bool CanPay() const { return freePlay_ || coins_ >= gameCost_; }

    GameMode DecidedMode() const { return decidedMode_; }
    void SetDecidedMode(GameMode mode) { decidedMode_ = mode; }

    // 段位道場で挑戦している段位（段位選択 → 演奏 → リザルト）
    DaniRun& Dani() { return dani_; }

    // 選曲画面で決めた曲と難易度（lua: songId / selectedCourse1P / selectedCourse2P）
    int SelectedSong() const { return selectedSong_; }
    int SelectedCourse(int index) const { return selectedCourse_[index]; }
    const std::string& SelectedGenre() const { return selectedGenre_; }
    void SetSelectedSong(int uniqueId, const std::string& genre) {
        selectedSong_ = uniqueId;
        selectedGenre_ = genre;
    }
    void SetSelectedCourse(int index, int course) { selectedCourse_[index] = course; }

    // ---- 1クレジットで遊ぶ曲数（lua: playSongCount / g_isLastSong） ----
    // 演奏ゲームの結果に関係なく、設定された曲数を遊べる（tips007。テストモードの NUMBER OF STAGE(S)）
    int StageCount() const { return stageCount_; }
    void SetStageCount(int count) { stageCount_ = count < 1 ? 1 : count; }
    int PlaySongCount() const { return playSongCount_; }   // いま何曲目か（1〜）
    bool IsLastSong() const { return playSongCount_ >= stageCount_; }
    void NextSong() { ++playSongCount_; }

    // 演奏ゲームの結果（lua の Result.lua が C++ から受け取る g_totalScore などと同じ中身）
    struct EnsoResult {
        bool valid = false;
        int score = 0;
        int good = 0, ok = 0, bad = 0;
        int drumroll = 0;           // 連打数
        int maxCombo = 0;
        int gauge = 0;              // 魂ゲージ（0〜50）
        int crown = 0;              // 0: なし 1: 銀（クリア） 2: 金（フルコンボ） 3: 虹（全良）
        int scoreRank = 0;          // 0: なし 1〜6: 粋白〜雅紫 7: 極
        int course = 0;             // 0: かんたん 〜 4: おに(裏)
        int resultType = 0;         // 0: クリア失敗 1: クリア 2: フルコンボ 3: ドンダフルコンボ
        int hiscore = 0;            // 遊ぶ前のハイスコア（0 なら記録なし）
    };
    EnsoResult& Result(int index) { return results_[index]; }
    const EnsoResult& Result(int index) const { return results_[index]; }

    void ResetEntries() {
        players_[0] = PlayerData();
        players_[1] = PlayerData();
        decidedMode_ = GameMode::Enso;
        selectedSong_ = -1;
        selectedGenre_.clear();
        selectedCourse_[0] = selectedCourse_[1] = 0;
        playSongCount_ = 1;
        results_[0] = results_[1] = EnsoResult();
        dani_ = DaniRun();
    }

    // コインでのエントリー。クレジットが払えないときは参加できない
    bool EntryCoin(int index) {
        PlayerData& player = players_[index];
        if (player.isUseCredit || !CanPay()) return false;

        Pay();
        player.isUseCredit = true;
        if (player.userType == UserType::None) {
            player.userType = UserType::Coin;
            player.name = DefaultName(index);
            player.title.clear();
            player.titleDesign = 0;
            player.costume = 0;
            player.kigurumi = -1;
            player.dress = DonCostume();
        }
        return true;
    }

    // カードでのエントリー。クレジットが足りなければクレジット待ちの状態で参加する
    bool EntryCard(int index, const CardProfile& card) {
        PlayerData& player = players_[index];
        player.userType = UserType::Card;
        player.cardId = card.cardId;
        player.isNewData = card.isNew;
        player.name = card.name;
        player.title = card.title;
        player.titleDesign = card.titleDesign;
        player.costume = card.costume;
        player.kigurumi = -1;
        player.dress = card.dress;
        if (!player.isUseCredit && CanPay()) {
            Pay();
            player.isUseCredit = true;
        }
        return true;
    }

    bool IsCardEntered(const std::string& cardId) const {
        for (const PlayerData& player : players_) {
            if (player.userType == UserType::Card && player.cardId == cardId) return true;
        }
        return false;
    }

    int EntryUserCount() const {
        int count = 0;
        for (const PlayerData& player : players_) {
            if (player.userType != UserType::None) ++count;
        }
        return count;
    }

    int CardEntryUserCount() const {
        int count = 0;
        for (const PlayerData& player : players_) {
            if (player.userType == UserType::Card) ++count;
        }
        return count;
    }

    // エントリー締め切り：クレジットを使っていないプレイヤーを外す
    void ClearNoCreditEntry() {
        for (PlayerData& player : players_) {
            if (!player.isUseCredit) player = PlayerData();
        }
    }

    static const char* DefaultName(int index) { return index == 0 ? "どんちゃん" : "かっちゃん"; }

private:
    PlayDataManager() = default;

    void Pay() {
        if (!freePlay_) coins_ -= gameCost_;
        GameSettings::Get().AddPlay(freePlay_, freePlay_ ? 0 : gameCost_);   // ブックキーピング
    }

    PlayerData players_[2];
    int coins_ = 0;
    int coinValue_ = 1;
    int gameCost_ = 1;
    int stageCount_ = 3;
    bool freePlay_ = true;
    GameMode decidedMode_ = GameMode::Enso;
    int selectedSong_ = -1;
    std::string selectedGenre_;
    int selectedCourse_[2] = {0, 0};
    int playSongCount_ = 1;
    EnsoResult results_[2];
    DaniRun dani_;
};

} // namespace GuminTaiko
