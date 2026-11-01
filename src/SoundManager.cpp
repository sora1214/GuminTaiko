#include "SoundManager.hpp"

#include "HitAudio.hpp"
#include "ProcessUtil.hpp"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <system_error>
#include <thread>
#include <vector>

namespace {

constexpr const char* kSoundDir = "Data/x64/sound";
constexpr const char* kCacheDir = "Data/cache/sound";
constexpr const char* kConverter = "third_party\\vgmstream\\vgmstream-cli.exe";
constexpr const char* kDoneMarker = "_converted";
constexpr int kStreamFrames = 4096;
constexpr int kMusicFrames = 2048;

std::string CachePath(const std::string& bank) {
    return std::string(kCacheDir) + "/" + bank;
}

std::string ToWindowsPath(std::string path) {
    std::replace(path.begin(), path.end(), '/', '\\');
    return path;
}

std::string SourcePath(const std::string& bank) {
    return std::string(kSoundDir) + "/" + bank + ".nus3bank";
}

// バンクの全トーンを <キャッシュ>/<トーン名>.wav に変換し、成功したら完了の印を置く
bool Convert(const std::string& bank) {
    const std::string dir = CachePath(bank);
    const std::string winDir = ToWindowsPath(dir);
    const std::string command = "mkdir \"" + winDir + "\" >NUL 2>&1 & \"" + kConverter + "\" -L -S 0 -o \"" + winDir +
                                "\\?n.wav\" \"" + ToWindowsPath(SourcePath(bank)) + "\" >NUL 2>&1";
    // 窓を出さずに cmd /c で実行する（RunHidden が全体を引用符で囲む）
    if (RunHidden(command) != 0) return false;
    SaveFileText((dir + "/" + kDoneMarker).c_str(), const_cast<char*>("ok"));
    return true;
}

bool IsConverted(const std::string& bank) {
    return FileExists((CachePath(bank) + "/" + kDoneMarker).c_str());
}

uint32_t ReadU32(const unsigned char* p) {
    return uint32_t(p[0]) | (uint32_t(p[1]) << 8) | (uint32_t(p[2]) << 16) | (uint32_t(p[3]) << 24);
}

// WAV の smpl チャンクからループ位置を読む（vgmstream -L の出力）
void ReadLoopPoints(const std::string& path, int& loopStart, int& loopEnd) {
    loopStart = loopEnd = -1;

    int size = 0;
    unsigned char* data = LoadFileData(path.c_str(), &size);
    if (!data) return;

    size_t offset = 12;   // "RIFF" <size> "WAVE" の後ろからチャンクが並ぶ
    while (offset + 8 <= size_t(size)) {
        const uint32_t chunkSize = ReadU32(data + offset + 4);
        if (std::memcmp(data + offset, "smpl", 4) == 0 && chunkSize >= 36 + 24) {
            const unsigned char* smpl = data + offset + 8;
            if (ReadU32(smpl + 28) > 0) {   // ループ数
                loopStart = int(ReadU32(smpl + 36 + 8));
                loopEnd = int(ReadU32(smpl + 36 + 12)) + 1;
            }
            break;
        }
        offset += 8 + chunkSize + (chunkSize & 1);
    }
    UnloadFileData(data);
}

} // namespace

void SoundManager::Init() {
    if (ready_) return;
    InitAudioDevice();
    ready_ = IsAudioDeviceReady();
    // 効果音は遅れの小さい出力で鳴らす（使えなければ raylib で鳴らす）
    if (ready_ && !HitAudio::Init()) TraceLog(LOG_WARNING, "SoundManager: 低遅延の効果音出力を使えません（raylib で鳴らします）");
    if (HitAudio::IsReady()) {
        TraceLog(LOG_INFO, "SoundManager: 効果音の出力 周期 %.1f ms、バッファ %.1f ms、先に書く量 %.1f ms", HitAudio::PeriodMs(),
                 HitAudio::BufferMs(), HitAudio::QueueMs());
    }
    SetAudioStreamBufferSizeDefault(kStreamFrames);
}

void SoundManager::Shutdown() {
    if (!ready_) return;
    StopAll();
    if (HitAudio::IsReady()) TraceLog(LOG_INFO, "SoundManager: 効果音の出力 先に書く量 %.1f ms（終了時）", HitAudio::QueueMs());
    HitAudio::Shutdown();
    for (auto& entry : sounds_) {
        for (Sound& alias : entry.second.aliases) UnloadSoundAlias(alias);
        if (!entry.second.aliases.empty()) UnloadSound(entry.second.source);
    }
    sounds_.clear();
    for (auto& entry : clips_) UnloadWave(entry.second.wave);
    clips_.clear();
    CloseAudioDevice();
    ready_ = false;
}

void SoundManager::Update(float deltaTime) {
    if (!ready_) return;

    for (Slot& slot : slots_) {
        if (!slot.active) continue;

        if (slot.fadeSpeed > 0.0f) {
            const float step = slot.fadeSpeed * deltaTime;
            if (std::fabs(slot.targetVolume - slot.volume) <= step) {
                slot.volume = slot.targetVolume;
                slot.fadeSpeed = 0.0f;
            } else {
                slot.volume += slot.targetVolume > slot.volume ? step : -step;
            }
        }
        SetAudioStreamVolume(slot.stream, slot.volume * (slot.bgm ? bgmGain_ : seGain_));

        FeedSlot(slot);
        if (slot.ending && slot.drained >= 2) ReleaseSlot(slot);
    }

    UpdatePreview(preview_, deltaTime);
    UpdatePreview(fading_, deltaTime);
    if (fading_.loaded && fading_.volume <= 0.0f) UnloadPreview(fading_);
}

std::vector<std::string> SoundManager::Tones(const std::string& bank) {
    std::vector<std::string> out;
    if (!ready_ || !EnsureConverted(bank)) return out;
    std::error_code ec;
    for (const auto& entry : std::filesystem::directory_iterator(CachePath(bank), ec)) {
        if (entry.path().extension() == ".wav") out.push_back(entry.path().stem().string());
    }
    std::sort(out.begin(), out.end());
    return out;
}

void SoundManager::Preload(const std::string& bank) {
    if (ready_) EnsureConverted(bank);
}

SoundManager::Voices* SoundManager::GetVoices(const std::string& bank, const std::string& tone) {
    const std::string key = bank + "/" + tone;
    auto found = sounds_.find(key);
    if (found != sounds_.end()) return found->second.Valid() ? &found->second : nullptr;

    Voices& voices = sounds_[key];
    const Clip* clip = GetClip(bank, tone);
    if (!clip) return nullptr;
    if (HitAudio::IsReady()) {
        voices.lowLatencyId = HitAudio::Register(static_cast<const short*>(clip->wave.data), int(clip->wave.frameCount),
                                                 int(clip->wave.channels), int(clip->wave.sampleRate));
        if (voices.lowLatencyId >= 0) return &voices;
    }
    voices.source = LoadSoundFromWave(clip->wave);
    for (int i = 0; i < kVoiceCount; ++i) voices.aliases.push_back(LoadSoundAlias(voices.source));
    return &voices;
}

void SoundManager::Play(const std::string& bank, const std::string& tone, float volume) {
    if (!ready_) return;
    Voices* voices = GetVoices(bank, tone);
    if (!voices) return;
    if (voices->lowLatencyId >= 0) {
        HitAudio::Play(voices->lowLatencyId, seGain_ * volume);
        return;
    }
    SetSoundVolume(voices->aliases[voices->next], seGain_ * volume);
    PlaySound(voices->aliases[voices->next]);
    voices->next = (voices->next + 1) % voices->aliases.size();
}

int SoundManager::LowLatencyId(const std::string& bank, const std::string& tone) {
    if (!ready_) return -1;
    Voices* voices = GetVoices(bank, tone);
    return voices ? voices->lowLatencyId : -1;
}

void SoundManager::PreloadTone(const std::string& bank, const std::string& tone) {
    if (ready_) GetVoices(bank, tone);
}

void SoundManager::PlaySlot(const std::string& bank, const std::string& tone, int slotIndex) {
    if (!ready_ || slotIndex < 0 || slotIndex >= kSlotCount) return;

    Slot& slot = slots_[size_t(slotIndex)];
    ReleaseSlot(slot);

    const Clip* clip = GetClip(bank, tone);
    if (!clip) return;

    slot.stream = LoadAudioStream(clip->wave.sampleRate, clip->wave.sampleSize, clip->wave.channels);
    slot.clip = clip;
    slot.position = 0;
    slot.active = true;
    slot.ending = false;
    slot.volume = slot.targetVolume = 1.0f;
    slot.fadeSpeed = 0.0f;
    slot.bgm = bank.rfind("bgm_", 0) == 0;

    // 再生前にバッファを埋めておく
    SetAudioStreamVolume(slot.stream, slot.volume * (slot.bgm ? bgmGain_ : seGain_));
    FeedSlot(slot);
    PlayAudioStream(slot.stream);
}

void SoundManager::StopSlot(int slotIndex) {
    if (slotIndex < 0 || slotIndex >= kSlotCount) return;
    ReleaseSlot(slots_[size_t(slotIndex)]);
}

void SoundManager::StopAll() {
    for (Slot& slot : slots_) ReleaseSlot(slot);
    UnloadPreview(preview_);
    UnloadPreview(fading_);
    HitAudio::StopAll();
    for (auto& entry : sounds_) {
        for (Sound& alias : entry.second.aliases) StopSound(alias);
    }
}

void SoundManager::SetVolumeSlot(int slotIndex, float decibel, float fadeSeconds) {
    if (slotIndex < 0 || slotIndex >= kSlotCount) return;
    Slot& slot = slots_[size_t(slotIndex)];

    const float target = decibel <= -90.0f ? 0.0f : std::pow(10.0f, decibel / 20.0f);
    slot.targetVolume = target;
    if (fadeSeconds <= 0.0f) {
        slot.volume = target;
        slot.fadeSpeed = 0.0f;
    } else {
        slot.fadeSpeed = std::fabs(target - slot.volume) / fadeSeconds;
    }
}

const SoundManager::Clip* SoundManager::GetClip(const std::string& bank, const std::string& tone) {
    const std::string key = bank + "/" + tone;
    auto found = clips_.find(key);
    if (found != clips_.end()) return found->second.wave.data ? &found->second : nullptr;

    Clip& clip = clips_[key];
    if (!EnsureConverted(bank)) return nullptr;

    const std::string path = CachePath(bank) + "/" + tone + ".wav";
    if (!FileExists(path.c_str())) {
        TraceLog(LOG_WARNING, "SoundManager: %s に %s がありません", bank.c_str(), tone.c_str());
        return nullptr;
    }

    clip.wave = LoadWave(path.c_str());
    if (!clip.wave.data) return nullptr;
    if (clip.wave.sampleSize != 16) WaveFormat(&clip.wave, clip.wave.sampleRate, 16, clip.wave.channels);
    ReadLoopPoints(path, clip.loopStart, clip.loopEnd);
    return &clip;
}

bool SoundManager::EnsureConverted(const std::string& bank) {
    auto found = converted_.find(bank);
    if (found != converted_.end()) return found->second;

    bool ok = IsConverted(bank);
    if (!ok) {
        const std::string source = SourcePath(bank);
        if (!FileExists(source.c_str())) {
            TraceLog(LOG_WARNING, "SoundManager: %s がありません", source.c_str());
        } else if (!FileExists(kConverter)) {
            TraceLog(LOG_WARNING, "SoundManager: %s がありません（音声を変換できません）", kConverter);
        } else {
            TraceLog(LOG_INFO, "SoundManager: %s を変換しています", bank.c_str());
            ok = Convert(bank);
            if (!ok) TraceLog(LOG_WARNING, "SoundManager: %s の変換に失敗しました", bank.c_str());
        }
    }

    converted_[bank] = ok;
    return ok;
}

void SoundManager::RegisterSongFile(const std::string& bank, const std::string& path, float previewStart) {
    namespace fs = std::filesystem;
    std::string extension = fs::u8path(path).extension().u8string();
    std::transform(extension.begin(), extension.end(), extension.begin(), [](char c) { return char(std::tolower(c)); });
    songFiles_[bank] = SongFile{path, CachePath(bank) + "/" + bank + extension, previewStart};
}

SoundManager::Job SoundManager::ConvertAsync(const std::string& bank) {
    auto found = jobs_.find(bank);
    if (found == jobs_.end()) {
        auto state = std::make_shared<std::atomic<int>>(int(Job::Running));
        jobs_[bank] = state;
        if (auto file = songFiles_.find(bank); file != songFiles_.end()) {
            // 本家のバンクではない曲: キャッシュへ写す（大きさが同じなら写し済み）
            namespace fs = std::filesystem;
            const fs::path source = fs::u8path(file->second.source);
            const std::string cached = file->second.cached;
            std::error_code ec;
            if (!fs::exists(source, ec)) {
                TraceLog(LOG_WARNING, "SoundManager: %s がありません", file->second.source.c_str());
                *state = int(Job::Failed);
            } else if (fs::exists(cached, ec) && fs::file_size(cached, ec) == fs::file_size(source, ec)) {
                *state = int(Job::Done);
            } else {
                std::thread([source, cached, state]() {
                    std::error_code error;
                    fs::create_directories(fs::path(cached).parent_path(), error);
                    const bool ok = fs::copy_file(source, cached, fs::copy_options::overwrite_existing, error);
                    *state = int(ok ? Job::Done : Job::Failed);
                }).detach();
            }
        } else if (IsConverted(bank)) {
            *state = int(Job::Done);
        } else if (!FileExists(SourcePath(bank).c_str()) || !FileExists(kConverter)) {
            TraceLog(LOG_WARNING, "SoundManager: %s を変換できません", bank.c_str());
            *state = int(Job::Failed);
        } else {
            TraceLog(LOG_INFO, "SoundManager: %s を変換しています（別スレッド）", bank.c_str());
            std::thread([bank, state]() { *state = int(Convert(bank) ? Job::Done : Job::Failed); }).detach();
        }
        return Job(state->load());
    }
    return Job(found->second->load());
}

// ---------------------------------------------------------------------------
// 曲のプレビュー
// ---------------------------------------------------------------------------
void SoundManager::PlayPreview(const std::string& bank, float fadeInSeconds, bool loop) {
    if (!ready_ || (bank == preview_.bank && loop == preview_.loop)) return;
    StopPreview(loop ? 0.33f : 0.0f);
    preview_ = Preview();
    preview_.bank = bank;
    preview_.fadeIn = fadeInSeconds;
    preview_.loop = loop;
    ConvertAsync(bank);
}

void SoundManager::PrepareSong(const std::string& bank) {
    if (ready_) ConvertAsync(bank);
}

bool SoundManager::IsSongPrepared(const std::string& bank) {
    return ready_ && ConvertAsync(bank) != Job::Running;
}

float SoundManager::SongTime() const {
    if (!preview_.loaded) return -1.0f;
    float played = GetMusicTimePlayed(preview_.music);
    // raylib 5.0 の GetMusicTimePlayed は「送った数 − バッファに残っている数」を曲の長さで割った余りなので、
    // 曲の頭へ位置を変えた直後は負になって曲の長さぶん回り込み、「曲の終わり」を返す（特訓モードで最後まで
    // 流したあと頭から流し直すと、時刻が一瞬終わりへ飛んで音符がすべて見逃し扱いになっていた）。
    // 直前まで前半にいたのに終わり近くを返したときは、回り込みとみなして曲の頭にする
    const float length = GetMusicTimeLength(preview_.music);
    if (length > 2.0f && played > length - 1.0f && lastSongTime_ >= 0.0f && lastSongTime_ < length * 0.5f) played = 0.0f;
    lastSongTime_ = played;
    return played;
}

void SoundManager::PauseSong() {
    if (preview_.loaded && IsMusicStreamPlaying(preview_.music)) {
        PauseMusicStream(preview_.music);
    }
    // 読み込み中でも止めた扱いにする（読み込みが済んだら止めたまま置いておく）
    preview_.paused = !preview_.bank.empty();
}

void SoundManager::ResumeSong() {
    if (preview_.loaded && !IsMusicStreamPlaying(preview_.music)) {
        ResumeMusicStream(preview_.music);
    }
    preview_.paused = false;
}

void SoundManager::SeekSong(float seconds) {
    if (!preview_.loaded) return;
    if (preview_.finished) {
        // 最後まで流れて止まった曲は、もう一度流し始めてから位置を変える
        PlayMusicStream(preview_.music);
        if (preview_.paused) PauseMusicStream(preview_.music);
        preview_.finished = false;
    }
    SeekMusicStream(preview_.music, std::max(0.0f, seconds));
    lastSongTime_ = std::max(0.0f, seconds);   // 回り込みの見分けに使う（SongTime）
}

void SoundManager::SetSongSpeed(float speed) {
    if (!preview_.loaded || speed <= 0.0f || std::fabs(speed - preview_.pitch) < 0.001f) return;
    // raylib 5.0 の SetMusicPitch は元の速さに対する倍率（前にかけた速さには掛け合わせない。
    // 0.9 倍 → 1.2 倍と変えたとき、比の 1.33 を渡すと 1.33 倍で流れてしまう）ので、速さをそのまま渡す
    SetMusicPitch(preview_.music, speed);
    preview_.pitch = speed;
}

bool SoundManager::IsSongPaused() const {
    return preview_.loaded && preview_.paused;
}

bool SoundManager::IsSongFinished() const {
    return preview_.finished;
}

void SoundManager::StopPreview(float fadeOutSeconds) {
    if (preview_.bank.empty()) return;
    if (preview_.loaded && fadeOutSeconds > 0.0f) {
        UnloadPreview(fading_);
        fading_ = preview_;
        fading_.targetVolume = 0.0f;
        fading_.fadeSpeed = std::max(fading_.volume, 0.01f) / fadeOutSeconds;
    } else {
        UnloadPreview(preview_);
    }
    preview_ = Preview();
}

void SoundManager::UnloadPreview(Preview& preview) {
    if (preview.loaded) {
        StopMusicStream(preview.music);
        UnloadMusicStream(preview.music);
    }
    preview = Preview();
}

void SoundManager::UpdatePreview(Preview& preview, float deltaTime) {
    if (preview.bank.empty()) return;

    if (!preview.loaded) {
        const Job job = ConvertAsync(preview.bank);
        if (job == Job::Failed) {
            preview = Preview();
            return;
        }
        if (job != Job::Done) return;
        // 曲のバンクにはトーンが1つだけ（名前はバンクと同じ）
        const auto file = songFiles_.find(preview.bank);
        const std::string path = file != songFiles_.end() ? file->second.cached : CachePath(preview.bank) + "/" + preview.bank + ".wav";
        // 曲はバッファを小さくして、再生位置の細かさと遅れを抑える（効果音のスロットは大きいまま）
        SetAudioStreamBufferSizeDefault(kMusicFrames);
        preview.music = LoadMusicStream(path.c_str());
        SetAudioStreamBufferSizeDefault(kStreamFrames);
        if (!IsMusicReady(preview.music)) {
            TraceLog(LOG_WARNING, "SoundManager: %s を再生できません", path.c_str());
            preview = Preview();
            return;
        }
        preview.loaded = true;
        preview.music.looping = preview.loop;
        preview.volume = preview.fadeIn > 0.0f ? 0.0f : 1.0f;
        preview.targetVolume = 1.0f;
        preview.fadeSpeed = preview.fadeIn > 0.0f ? 1.0f / preview.fadeIn : 0.0f;
        SetMusicVolume(preview.music, preview.volume * bgmGain_);
        PlayMusicStream(preview.music);
        if (preview.paused) PauseMusicStream(preview.music);   // 先に読み込んでおいた曲（PauseSong 済み）
        // TJA の曲のプレビューは DEMOSTART から
        if (preview.loop && file != songFiles_.end() && file->second.previewStart > 0.0f) {
            SeekMusicStream(preview.music, file->second.previewStart);
        }
    }

    if (preview.fadeSpeed > 0.0f) {
        const float step = preview.fadeSpeed * deltaTime;
        if (std::fabs(preview.targetVolume - preview.volume) <= step) {
            preview.volume = preview.targetVolume;
            preview.fadeSpeed = 0.0f;
        } else {
            preview.volume += preview.targetVolume > preview.volume ? step : -step;
        } 
        SetMusicVolume(preview.music, preview.volume * bgmGain_);
    }
    UpdateMusicStream(preview.music);
    // 止めているあいだは「最後まで流れた」にしない
    if (!preview.loop && !preview.paused && !IsMusicStreamPlaying(preview.music)) preview.finished = true;
}

bool SoundManager::IsSlotPlaying(int slotIndex) const {
    return slotIndex >= 0 && slotIndex < kSlotCount && slots_[size_t(slotIndex)].active && !slots_[size_t(slotIndex)].ending;
}

void SoundManager::FeedSlot(Slot& slot) {
    if (!slot.clip) return;

    const Wave& wave = slot.clip->wave;
    const unsigned int channels = wave.channels;
    const unsigned int frameCount = wave.frameCount;
    const bool looping = slot.clip->loopStart >= 0 && slot.clip->loopEnd > slot.clip->loopStart;
    const unsigned int loopEnd = looping ? std::min(unsigned(slot.clip->loopEnd), frameCount) : frameCount;

    std::vector<short> buffer(size_t(kStreamFrames) * channels);
    while (IsAudioStreamProcessed(slot.stream)) {
        // 末尾を送り終えたら無音を流しつつ、2つのバッファが再生し終わるのを待つ
        if (slot.ending) {
            std::fill(buffer.begin(), buffer.end(), short(0));
            UpdateAudioStream(slot.stream, buffer.data(), kStreamFrames);
            ++slot.drained;
            continue;
        }

        const short* samples = static_cast<const short*>(wave.data);
        unsigned int written = 0;
        while (written < unsigned(kStreamFrames)) {
            if (slot.position >= loopEnd) {
                if (!looping) break;
                slot.position = unsigned(slot.clip->loopStart);
            }
            const unsigned int count = std::min(unsigned(kStreamFrames) - written, loopEnd - slot.position);
            std::memcpy(buffer.data() + size_t(written) * channels, samples + size_t(slot.position) * channels,
                        size_t(count) * channels * sizeof(short));
            written += count;
            slot.position += count;
        }

        if (written < unsigned(kStreamFrames)) {
            std::fill(buffer.begin() + size_t(written) * channels, buffer.end(), short(0));
            slot.ending = true;
        }
        UpdateAudioStream(slot.stream, buffer.data(), kStreamFrames);
    }
}

void SoundManager::ReleaseSlot(Slot& slot) {
    if (slot.active) {
        StopAudioStream(slot.stream);
        UnloadAudioStream(slot.stream);
    }
    slot = Slot();
}
