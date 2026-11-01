#pragma once
#include <array>
#include <map>
#include <string>
#include <vector>

#include "DaniData.hpp"
#include "PlayData.hpp"

namespace GuminTaiko {

// 譜面ごとの自己ベスト（lua: PlayDataManager.GetEnsoRecordInfo の hiScore / crown / scoreRank）
struct ChartRecord {
    int score = 0;
    int crown = 0;       // 0: なし 1: 銀（クリア） 2: 金（フルコンボ） 3: 虹（ドンダフルコンボ）
    int scoreRank = 0;   // 0: なし 1〜3: 粋（白・銅・銀） 4〜6: 雅（金・桃・紫） 7: 極
    int playCount = 0;   // 遊んだ回数（カードのデータだけ数える）
};

// 総合成績（lua: user_data.totalRecordInfo の crown_num / scorerank_num）
struct RecordTotals {
    std::array<int, 4> crown{};       // その王冠以上を取った譜面の数（[1]: クリア [2]: フルコンボ [3]: ドンダフルコンボ）
    std::array<int, 8> scoreRank{};   // そのスコアランクの譜面の数
};

// 段位道場の記録（lua: daniRecordInfo の normal_rank / normal_score）
//   rank: 0 未挑戦 1 不合格 2 赤合格 3 赤合格フルコンボ 4 赤合格ドンダフル 5 金合格 6 金合格フルコンボ 7 金合格ドンダフル
struct DaniRecord {
    int rank = 0;
    int gauge = 0;                                  // 魂ゲージ（%）
    int arrival = 0;                                // 到達した曲数（1〜3）
    std::array<DaniSongResult, 3> songs{};          // いちばん良かった挑戦の、曲ごとの成績
};

// 遊んだ記録。本家ではカードのデータとしてサーバーにあるもの。
//   カード（バナパスポート）: Backup/players/<カードID>.json に1人1ファイル（あとでサーバーに置き換える前提の形）
//   コイン: Backup/records.ini に全員で1つ
// JSON の形は PlayRecord.cpp の LoadCard / SaveCard のとおり
class PlayRecords {
public:
    static PlayRecords& Get() {
        static PlayRecords instance;
        return instance;
    }

    // 開発者のカード（テスト用のバナパスポート。F3 でタッチ）。プレイヤーデータがなければエントリーで登録する
    static constexpr const char* kDeveloperCardId = "GMN-0001-0001";

    // エントリーしているプレイヤーの記録の持ち主（カードならカードID、コインなら "coin"）
    static std::string Owner(int player);

    // 登録してあるカードの情報を読む。登録されていなければ false
    bool Card(const std::string& cardId, CardProfile& out);
    // 登録してあるカードの ID（Backup/players にある JSON）
    std::vector<std::string> CardIds();
    // カードの名前・称号・着せかえを書き換えて保存する（着せかえアプリ用）
    bool SetCard(const CardProfile& profile);
    // はじめてのカードのプレイヤーデータを作る（エントリーの名前入力のあと）。もう登録してあれば名前だけ変える
    bool RegisterCard(const std::string& cardId, const std::string& name);

    const ChartRecord* Find(const std::string& owner, const std::string& songId, int course);
    // 演奏の結果を記録する（スコア・王冠・スコアランクはそれぞれ良いほうを残す）
    void Add(const std::string& owner, const std::string& songId, int course, const ChartRecord& result);
    RecordTotals Totals(const std::string& owner, int course);

    // 王冠と総合成績を見せる難易度（lua: totalRecordInfo.disp_crown_level）。最後に遊んだ難易度、はじめはおに
    int DispCourse(const std::string& owner);

    // 段位道場（カードだけ）。NowDani は赤合格した中でいちばん上の段位（なければ 0）
    DaniRecord Dani(const std::string& owner, int level);
    int NowDani(const std::string& owner);
    // 挑戦の結果を残す（合格の段階が上がったか、同じで魂ゲージが上のときに成績を入れ替える）。昇段したら true
    bool AddDani(const std::string& owner, int level, const DaniRecord& result);

    // 演奏オプション（本家のカードユーザーと同じく、次に遊ぶときも前に決めた設定から始める）
    PlayOptions Options(const std::string& owner);
    void SetOptions(const std::string& owner, const PlayOptions& options);

private:
    struct OwnerData {
        bool card = false;
        // ---- カードだけ ----
        std::string name;
        std::string title;
        int titleDesign = 0;        // 称号の地のデザイン（TitleDesignLabel の番号）
        int costume = 0;
        DonCostume dress;           // 着せかえアプリで決めた着せかえ（costume が 5 のとき）
        std::string registeredAt;   // 登録した日時（ISO 8601）
        std::string lastPlayedAt;   // 最後に遊んだ日時
        int playCount = 0;          // 遊んだ曲の数
        // ---- 共通 ----
        int dispCourse = 3;
        PlayOptions options;
        std::map<std::string, ChartRecord> charts;   // "曲ID/難易度"
        std::map<int, DaniRecord> dani;               // 段位（1〜19）
    };

    PlayRecords() = default;
    void Load();                    // records.ini（コイン）
    void SaveCoin() const;
    // owner の記録（カードならそのファイルを読む）。create: なければ作る
    OwnerData* Data(const std::string& owner, bool create);
    bool LoadCard(const std::string& cardId);
    void SaveCard(const std::string& cardId) const;
    void Save(const std::string& owner) const;

    bool loaded_ = false;
    std::map<std::string, OwnerData> owners_;
};

} // namespace GuminTaiko
