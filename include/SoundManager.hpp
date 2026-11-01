#pragma once
#include <array>
#include <atomic>
#include <map>
#include <memory>
#include <string>
#include <vector>
#include "raylib.h"

// 効果音・BGM の再生（lua: TSound）
// Data/x64/sound/<bank>.nus3bank を初回利用時に vgmstream で WAV に変換し、
// Data/cache/sound/<bank>/<tone>.wav にキャッシュしてから再生する。
// ループ位置は WAV の smpl チャンクから読み、スロット再生でループさせる。
class SoundManager {
public:
    static constexpr int kSlotCount = 8;
    static constexpr int kVoiceCount = 6;   // 同じ効果音を重ねて鳴らせる数

    static SoundManager& Get() {
        static SoundManager instance;
        return instance;
    }

    void Init();
    void Shutdown();
    void Update(float deltaTime);

    // 音量（テストモードの VOLUME / OUTPUT LEVEL）。1 が元の大きさ。
    // BGM は bgm_ のバンクと曲（プレビュー・演奏）、SE はそれ以外
    void SetVolumes(float bgm, float se) { bgmGain_ = bgm; seGain_ = se; }

    // バンクに入っている音の名前（変換してから、キャッシュの WAV の名前を並べる）。lua の TSound:PlayBGM(bank) 用
    std::vector<std::string> Tones(const std::string& bank);

    // バンクを変換・読み込みしておく（初回再生時の待ちを防ぐ）
    void Preload(const std::string& bank);

    // 単発再生（同じ音を続けて鳴らしても前の音を切らない）
    // volume: この音だけの音量（1 が元の大きさ）
    void Play(const std::string& bank, const std::string& tone, float volume = 1.0f);
    // 単発再生の音を読み込んでおく（叩いた音など、最初の1回で遅れないように）
    void PreloadTone(const std::string& bank, const std::string& tone);
    // 低遅延の出力（HitAudio）に登録した音の番号（鳴らせないなら -1）と、効果音の音量。叩いた瞬間に鳴らす監視用
    int LowLatencyId(const std::string& bank, const std::string& tone);
    float SeGain() const { return seGain_; }

    // スロット再生（ループ位置があればループする）
    void PlaySlot(const std::string& bank, const std::string& tone, int slot);
    void StopSlot(int slot);
    void StopAll();
    // 音量をデシベルで指定する。fadeSeconds が 0 ならすぐに変える
    void SetVolumeSlot(int slot, float decibel, float fadeSeconds);
    bool IsSlotPlaying(int slot) const;

    // 曲のプレビュー（lua: TSound:PlayBGMSongSelect）。曲のバンクは大きいので別スレッドで変換し、
    // 変換が終わりしだいファイルからストリーム再生する（繰り返し）。前の曲はフェードアウトさせる
    void PlayPreview(const std::string& bank, float fadeInSeconds, bool loop = true);
    void StopPreview(float fadeOutSeconds);
    const std::string& PreviewBank() const { return preview_.bank; }
    bool IsPreviewStarted() const { return preview_.loaded; }                     // 変換が済んで鳴り始めた
    bool IsPreviewPlaying() const { return preview_.loaded || fading_.loaded; }   // フェードアウト中も含む

    // 本家のバンクではない曲（TJA の WAVE: ogg / wav / mp3）をバンク名で流せるようにする。
    // raylib はファイル名に日本語があると開けないので、変換の代わりに ASCII の名前でキャッシュへ写してから流す。
    // previewStart: 曲選択のプレビューを流し始める位置（秒。TJA の DEMOSTART）
    void RegisterSongFile(const std::string& bank, const std::string& path, float previewStart);

    // 演奏用: 曲の変換を始める（再生はしない）／変換が済んだか／曲を頭から1回だけ流す
    void PrepareSong(const std::string& bank);
    bool IsSongPrepared(const std::string& bank);
    void PlaySong(const std::string& bank) { PlayPreview(bank, 0.0f, false); }
    void PauseSong();
    void ResumeSong();
    // PlaySong した曲の読み込みが済んだか（止めていても）
    bool IsSongLoaded() const { return preview_.loaded; }
    // 流している曲の再生位置を変える（止めていれば止めたまま。最後まで流れた曲も戻せる）
    void SeekSong(float seconds);
    bool IsSongPaused() const;
    // 流している曲の速さ（特訓モードの曲テンポ。1 が元の速さ）。音の高さも一緒に変わる
    void SetSongSpeed(float speed);
    // 流している曲の再生位置（秒）。読み込み前は -1。最後まで流れたら IsSongFinished
    float SongTime() const;
    bool IsSongFinished() const;

private:
    struct Preview {
        std::string bank;
        Music music{};
        bool loaded = false;
        float volume = 0.0f;
        float targetVolume = 1.0f;
        float fadeSpeed = 0.0f;
        float fadeIn = 0.0f;
        bool loop = true;
        bool finished = false;
        bool paused = false;       // PauseSong で止めている
        float pitch = 1.0f;        // SetMusicPitch で今かけている速さ
    };
    enum class Job { Running, Done, Failed };

    void UpdatePreview(Preview& preview, float deltaTime);
    void UnloadPreview(Preview& preview);
    // 変換を別スレッドで始める（済んでいれば Done）
    Job ConvertAsync(const std::string& bank);

    struct Clip {
        Wave wave{};
        int loopStart = -1;   // フレーム単位
        int loopEnd = -1;     // フレーム単位（この位置は含まない）
    };

    struct Slot {
        AudioStream stream{};
        const Clip* clip = nullptr;
        unsigned int position = 0;
        bool active = false;
        bool ending = false;
        int drained = 0;
        float volume = 1.0f;
        float targetVolume = 1.0f;
        float fadeSpeed = 0.0f;
        bool bgm = false;
    };

    SoundManager() = default;
    float bgmGain_ = 1.0f;
    float seGain_ = 1.0f;

    const Clip* GetClip(const std::string& bank, const std::string& tone);
    bool EnsureConverted(const std::string& bank);
    void FeedSlot(Slot& slot);
    void ReleaseSlot(Slot& slot);

    bool ready_ = false;
    std::map<std::string, Clip> clips_;       // "bank/tone"
    std::map<std::string, bool> converted_;   // bank → 変換できたか
    // 単発再生用。重ねて鳴らせるように、同じ音データを共有する別名をいくつか持って順に使う
    // 低遅延の出力（HitAudio）が使えるときはそちらで鳴らし、使えないときだけ raylib の Sound を使う
    struct Voices {
        int lowLatencyId = -1;
        Sound source{};
        std::vector<Sound> aliases;
        size_t next = 0;
        bool Valid() const { return lowLatencyId >= 0 || !aliases.empty(); }
    };
    Voices* GetVoices(const std::string& bank, const std::string& tone);
    std::map<std::string, Voices> sounds_;
    std::array<Slot, kSlotCount> slots_{};

    struct SongFile {
        std::string source;   // UTF-8 のパス
        std::string cached;   // キャッシュに写したファイル（ASCII）
        float previewStart = 0.0f;
    };
    std::map<std::string, SongFile> songFiles_;   // bank → 本家のバンクではない曲

    Preview preview_;
    mutable float lastSongTime_ = -1.0f;   // 最後に SongTime が返した位置（raylib の回り込みを見分ける）
    Preview fading_;                                             // フェードアウト中の前の曲
    std::map<std::string, std::shared_ptr<std::atomic<int>>> jobs_;   // bank → Job
};
