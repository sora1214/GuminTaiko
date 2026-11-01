// Windows のヘッダーは raylib.h と名前がぶつかるので、このファイルでは raylib を読み込まない
#define INITGUID
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <mmreg.h>
#include <mmdeviceapi.h>
#include <audioclient.h>

#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstring>
#include <mutex>
#include <thread>
#include <vector>

#include "HitAudio.hpp"

#ifndef CREATE_WAITABLE_TIMER_HIGH_RESOLUTION
#define CREATE_WAITABLE_TIMER_HIGH_RESOLUTION 0x00000002
#endif

namespace HitAudio {

namespace {

constexpr int kMaxVoices = 48;
// 同じ音を続けて叩いたとき（連打）に、前の音の余韻が重なって響かないようにする。
// 前に鳴らした同じ音は、新しい音が始まると kChokeSeconds で消えていく（頭のアタックは鳴らしきったあと）。
// 同じ音の重なりは kMaxSameVoices まで（いちばん古いものからやめる）
constexpr float kChokeSeconds = 0.035f;
constexpr int kMaxSameVoices = 2;

struct SoundData {
    std::vector<float> samples;   // 出力のチャンネル数で並べた float
    int frames = 0;
};

struct Voice {
    int id = -1;
    int pos = 0;
    float volume = 1.0f;
    float gain = 1.0f;        // 消えていくときの音量（1 → 0）
    float fadeStep = 0.0f;    // 1 フレームで減らす量（0 なら消えていない）
};

std::vector<SoundData> g_sounds;
std::vector<Voice> g_voices;
std::mutex g_mutex;
std::thread g_thread;
std::atomic<bool> g_running{false};
std::atomic<bool> g_ready{false};
HANDLE g_started = nullptr;

std::atomic<int> g_periodFrames{0};   // 出力の周期（この間隔でイベントが来る）
std::atomic<int> g_bufferFrames{0};
std::atomic<int> g_queueFrames{0};    // 先に書いておく量。これより多く書くと、新しく鳴らした音がその分遅れる

int g_channels = 2;
int g_rate = 48000;
bool g_float = true;
int g_bits = 32;

template <typename T>
void Release(T*& p) {
    if (p) p->Release();
    p = nullptr;
}

// 音が重なって大きくなりすぎたとき、頭を切らずにやわらかく抑える（0.8 までは何も変えない）
inline float SoftClip(float x) {
    constexpr float kKnee = 0.8f;
    const float a = std::fabs(x);
    if (a <= kKnee) return x;
    const float y = kKnee + (1.0f - kKnee) * std::tanh((a - kKnee) / (1.0f - kKnee));
    return x < 0.0f ? -y : y;
}

// 混ぜた float をバッファの形式に書き出す
void Write(BYTE* data, std::vector<float>& mix) {
    for (float& v : mix) v = SoftClip(v);
    const size_t count = mix.size();
    if (g_float && g_bits == 32) {
        float* out = reinterpret_cast<float*>(data);
        for (size_t i = 0; i < count; ++i) out[i] = std::clamp(mix[i], -1.0f, 1.0f);
    } else if (g_bits == 16) {
        int16_t* out = reinterpret_cast<int16_t*>(data);
        for (size_t i = 0; i < count; ++i) out[i] = int16_t(std::clamp(mix[i], -1.0f, 1.0f) * 32767.0f);
    } else if (g_bits == 32) {
        int32_t* out = reinterpret_cast<int32_t*>(data);
        for (size_t i = 0; i < count; ++i) out[i] = int32_t(double(std::clamp(mix[i], -1.0f, 1.0f)) * 2147483647.0);
    } else if (g_bits == 24) {
        for (size_t i = 0; i < count; ++i) {
            const int32_t v = int32_t(std::clamp(mix[i], -1.0f, 1.0f) * 8388607.0f);
            data[i * 3] = BYTE(v & 0xFF);
            data[i * 3 + 1] = BYTE((v >> 8) & 0xFF);
            data[i * 3 + 2] = BYTE((v >> 16) & 0xFF);
        }
    }
}

void Run() {
    CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    IMMDeviceEnumerator* enumerator = nullptr;
    IMMDevice* device = nullptr;
    IAudioClient* client = nullptr;
    IAudioClient3* client3 = nullptr;
    IAudioRenderClient* render = nullptr;
    WAVEFORMATEX* format = nullptr;
    HANDLE event = nullptr;
    UINT32 bufferFrames = 0;

    bool ok = SUCCEEDED(CoCreateInstance(CLSID_MMDeviceEnumerator, nullptr, CLSCTX_ALL, IID_IMMDeviceEnumerator,
                                         reinterpret_cast<void**>(&enumerator))) &&
              SUCCEEDED(enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &device));
    if (ok) {
        // Windows 10 以降は IAudioClient3 で最小の周期を使う
        if (SUCCEEDED(device->Activate(IID_IAudioClient3, CLSCTX_ALL, nullptr, reinterpret_cast<void**>(&client3)))) {
            client = client3;
            client->AddRef();
        } else {
            ok = SUCCEEDED(device->Activate(IID_IAudioClient, CLSCTX_ALL, nullptr, reinterpret_cast<void**>(&client)));
        }
    }
    if (ok) ok = SUCCEEDED(client->GetMixFormat(&format));
    if (ok) {
        g_channels = format->nChannels;
        g_rate = int(format->nSamplesPerSec);
        g_bits = format->wBitsPerSample;
        g_float = format->wFormatTag == WAVE_FORMAT_IEEE_FLOAT;
        if (format->wFormatTag == WAVE_FORMAT_EXTENSIBLE) {
            const WAVEFORMATEXTENSIBLE* ext = reinterpret_cast<const WAVEFORMATEXTENSIBLE*>(format);
            g_float = ext->SubFormat.Data1 == WAVE_FORMAT_IEEE_FLOAT;
        }

        HRESULT hr = E_FAIL;
        if (client3) {
            UINT32 defaultPeriod = 0, fundamental = 0, minPeriod = 0, maxPeriod = 0;
            if (SUCCEEDED(client3->GetSharedModeEnginePeriod(format, &defaultPeriod, &fundamental, &minPeriod, &maxPeriod))) {
                hr = client3->InitializeSharedAudioStream(AUDCLNT_STREAMFLAGS_EVENTCALLBACK, minPeriod, format, nullptr);
                if (SUCCEEDED(hr)) g_periodFrames = int(minPeriod);
            }
        }
        if (FAILED(hr)) {
            hr = client->Initialize(AUDCLNT_SHAREMODE_SHARED, AUDCLNT_STREAMFLAGS_EVENTCALLBACK, 0, 0, format, nullptr);
            REFERENCE_TIME defaultPeriod = 0, minPeriod = 0;   // 100ns 単位
            if (SUCCEEDED(hr) && SUCCEEDED(client->GetDevicePeriod(&defaultPeriod, &minPeriod))) {
                g_periodFrames = int(double(defaultPeriod) * double(g_rate) / 1e7);
            }
        }
        ok = SUCCEEDED(hr);
    }
    if (ok) {
        event = CreateEventW(nullptr, FALSE, FALSE, nullptr);
        ok = event && SUCCEEDED(client->SetEventHandle(event)) && SUCCEEDED(client->GetBufferSize(&bufferFrames)) &&
             SUCCEEDED(client->GetService(IID_IAudioRenderClient, reinterpret_cast<void**>(&render)));
    }
    if (ok) {
        // バッファを満タンまで書くと、新しく鳴らした音はバッファに溜まった分だけ遅れて聞こえる。
        // 周期の 1.5 倍だけ先に書いておき、イベント（周期ごと）のたびに足す。書くのが間に合わず空になったら少しずつ増やす
        g_bufferFrames = int(bufferFrames);
        if (g_periodFrames <= 0) g_periodFrames = int(bufferFrames) / 2;
        g_queueFrames = std::clamp(g_periodFrames * 3 / 2, 1, int(bufferFrames));
    }
    if (ok) {
        // 最初は無音（先に書いておく量だけ）で始める
        BYTE* data = nullptr;
        const UINT32 first = UINT32(g_queueFrames.load());
        if (SUCCEEDED(render->GetBuffer(first, &data))) render->ReleaseBuffer(first, AUDCLNT_BUFFERFLAGS_SILENT);
        ok = SUCCEEDED(client->Start());
    }

    g_ready = ok;
    SetEvent(g_started);

    if (ok) {
        SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_TIME_CRITICAL);
        std::vector<float> mix;
        while (g_running) {
            WaitForSingleObject(event, 100);
            UINT32 padding = 0;
            if (FAILED(client->GetCurrentPadding(&padding))) continue;
            if (padding == 0 && g_queueFrames < int(bufferFrames)) {
                // 空になった（音が途切れた）: 先に書く量を周期の 1/4 ずつ増やす
                g_queueFrames = std::min(int(bufferFrames), g_queueFrames + std::max(1, g_periodFrames / 4));
            }
            const UINT32 queue = UINT32(g_queueFrames.load());
            if (padding >= queue) continue;
            const UINT32 frames = std::min(queue - padding, bufferFrames - padding);
            if (frames == 0) continue;
            BYTE* data = nullptr;
            if (FAILED(render->GetBuffer(frames, &data))) continue;

            mix.assign(size_t(frames) * size_t(g_channels), 0.0f);
            {
                std::lock_guard<std::mutex> lock(g_mutex);
                for (Voice& voice : g_voices) {
                    const SoundData& sound = g_sounds[size_t(voice.id)];
                    int count = std::min(int(frames), sound.frames - voice.pos);
                    const float* src = sound.samples.data() + size_t(voice.pos) * size_t(g_channels);
                    if (voice.fadeStep <= 0.0f) {
                        for (int i = 0; i < count * g_channels; ++i) mix[size_t(i)] += src[i] * voice.volume;
                    } else {
                        // 消えていく音（同じ音が続けて鳴ったとき）。音量が 0 になったらそこで終わり
                        for (int f = 0; f < count; ++f) {
                            if (voice.gain <= 0.0f) {
                                count = f;
                                voice.pos = sound.frames - count;   // 終わりにする（下で count を足して sound.frames になる）
                                break;
                            }
                            for (int c = 0; c < g_channels; ++c) mix[size_t(f * g_channels + c)] += src[f * g_channels + c] * voice.volume * voice.gain;
                            voice.gain -= voice.fadeStep;
                        }
                    }
                    voice.pos += count;
                }
                g_voices.erase(std::remove_if(g_voices.begin(), g_voices.end(),
                                              [](const Voice& v) { return v.pos >= g_sounds[size_t(v.id)].frames; }),
                               g_voices.end());
            }
            Write(data, mix);
            render->ReleaseBuffer(frames, 0);
        }
        client->Stop();
    }

    Release(render);
    if (format) CoTaskMemFree(format);
    Release(client3);
    Release(client);
    Release(device);
    Release(enumerator);
    if (event) CloseHandle(event);
    CoUninitialize();
}

} // namespace

bool Init() {
    if (g_running) return g_ready;
    g_started = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    g_running = true;
    g_thread = std::thread(Run);
    WaitForSingleObject(g_started, 3000);
    CloseHandle(g_started);
    g_started = nullptr;
    if (!g_ready) Shutdown();
    return g_ready;
}

void StopKeyMonitor();

void Shutdown() {
    StopKeyMonitor();
    g_running = false;
    if (g_thread.joinable()) g_thread.join();
    g_ready = false;
    std::lock_guard<std::mutex> lock(g_mutex);
    g_voices.clear();
    g_sounds.clear();
}

bool IsReady() {
    return g_ready;
}

float PeriodMs() { return float(g_periodFrames.load()) * 1000.0f / float(g_rate); }
float BufferMs() { return float(g_bufferFrames.load()) * 1000.0f / float(g_rate); }
float QueueMs() { return float(g_queueFrames.load()) * 1000.0f / float(g_rate); }

int Register(const short* samples, int frames, int channels, int sampleRate) {
    if (!g_ready || !samples || frames <= 0 || channels <= 0 || sampleRate <= 0) return -1;
    // 出力の周波数に合わせて直線補間し、チャンネルを並べ替える（モノラルは左右に、3ch 目以降は無音）
    SoundData sound;
    const double step = double(sampleRate) / double(g_rate);
    sound.frames = std::max(1, int(double(frames) / step));
    sound.samples.assign(size_t(sound.frames) * size_t(g_channels), 0.0f);
    for (int f = 0; f < sound.frames; ++f) {
        const double src = f * step;
        const int i0 = std::min(frames - 1, int(src));
        const int i1 = std::min(frames - 1, i0 + 1);
        const float t = float(src - i0);
        for (int c = 0; c < g_channels && c < 2; ++c) {
            const int sc = std::min(c, channels - 1);
            const float a = samples[size_t(i0) * size_t(channels) + size_t(sc)] / 32768.0f;
            const float b = samples[size_t(i1) * size_t(channels) + size_t(sc)] / 32768.0f;
            sound.samples[size_t(f) * size_t(g_channels) + size_t(c)] = a + (b - a) * t;
        }
    }
    std::lock_guard<std::mutex> lock(g_mutex);
    g_sounds.push_back(std::move(sound));
    return int(g_sounds.size()) - 1;
}

void Play(int id, float volume) {
    if (!g_ready || id < 0) return;
    std::lock_guard<std::mutex> lock(g_mutex);
    if (size_t(id) >= g_sounds.size()) return;
    if (g_voices.size() >= size_t(kMaxVoices)) g_voices.erase(g_voices.begin());   // いちばん古い音をやめる
    // 同じ音がまだ鳴っていたら、消えていくようにする。重なりが多すぎれば、いちばん古いものからやめる
    const float fadeStep = 1.0f / std::max(1.0f, kChokeSeconds * float(g_rate));
    int same = 0;
    for (Voice& old : g_voices) {
        if (old.id != id) continue;
        ++same;
        if (old.fadeStep <= 0.0f) old.fadeStep = fadeStep;
    }
    for (auto it = g_voices.begin(); same >= kMaxSameVoices && it != g_voices.end();) {
        if (it->id == id) {
            it = g_voices.erase(it);
            --same;
        } else {
            ++it;
        }
    }
    Voice voice;
    voice.id = id;
    voice.volume = volume;
    g_voices.push_back(voice);
}

void StopAll() {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_voices.clear();
}

// ---------------------------------------------------------------------------
// 叩いた瞬間の音（キーの監視）
// ---------------------------------------------------------------------------
namespace {

constexpr int kPads = 8;                      // 2 人 × 4 つ
constexpr ULONGLONG kEarlyHitLifeMs = 150;    // 画面側が拾わなかった叩きは、これだけたつと捨てる

struct PadSound {
    std::atomic<int> id{-1};
    std::atomic<float> volume{1.0f};
    std::atomic<int> keys[4];
    std::atomic<int> keyCount{0};
};
PadSound g_pads[kPads];
std::atomic<bool> g_monitorActive{false};
std::thread g_monitorThread;
std::atomic<bool> g_monitorRunning{false};

struct EarlyHit {
    int pad;
    ULONGLONG tick;
};
std::mutex g_earlyMutex;
std::vector<EarlyHit> g_early;

bool GameIsForeground() {
    DWORD pid = 0;
    GetWindowThreadProcessId(GetForegroundWindow(), &pid);
    return pid == GetCurrentProcessId();
}

void MonitorRun() {
    SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_HIGHEST);
    // 1ms の待ち（古い Windows では Sleep(1)）
    HANDLE timer = CreateWaitableTimerExW(nullptr, nullptr, CREATE_WAITABLE_TIMER_HIGH_RESOLUTION, TIMER_ALL_ACCESS);
    bool previous[kPads] = {};
    while (g_monitorRunning) {
        if (timer) {
            LARGE_INTEGER due;
            due.QuadPart = -10000;   // 1ms（100ns 単位。負は相対）
            SetWaitableTimer(timer, &due, 0, nullptr, nullptr, FALSE);
            WaitForSingleObject(timer, 5);
        } else {
            Sleep(1);
        }
        const bool active = g_monitorActive.load() && g_ready.load() && GameIsForeground();
        for (int i = 0; i < kPads; ++i) {
            PadSound& pad = g_pads[i];
            const int count = pad.keyCount.load();
            bool down = false;
            for (int k = 0; k < count && !down; ++k) {
                const int vk = pad.keys[k].load();
                if (vk > 0 && (GetAsyncKeyState(vk) & 0x8000) != 0) down = true;
            }
            const bool edge = down && !previous[i];
            previous[i] = down;
            const int id = pad.id.load();
            if (!edge || !active || id < 0) continue;
            Play(id, pad.volume.load());
            std::lock_guard<std::mutex> lock(g_earlyMutex);
            g_early.push_back({i, GetTickCount64()});
        }
    }
    if (timer) CloseHandle(timer);
}

} // namespace

void SetPadSound(int player, int pad, int soundId, float volume, const int* virtualKeys, int keyCount) {
    const int index = player * 4 + pad;
    if (index < 0 || index >= kPads) return;
    PadSound& slot = g_pads[index];
    slot.keyCount = 0;
    for (int k = 0; k < keyCount && k < 4; ++k) slot.keys[k] = virtualKeys[k];
    slot.volume = volume;
    slot.id = soundId;
    slot.keyCount = std::min(keyCount, 4);
    if (!g_monitorRunning && g_ready) {
        g_monitorRunning = true;
        g_monitorThread = std::thread(MonitorRun);
    }
}

void StopKeyMonitor() {
    g_monitorRunning = false;
    if (g_monitorThread.joinable()) g_monitorThread.join();
}

void ClearPadSounds() {
    g_monitorActive = false;
    for (PadSound& pad : g_pads) {
        pad.id = -1;
        pad.keyCount = 0;
    }
    std::lock_guard<std::mutex> lock(g_earlyMutex);
    g_early.clear();
}

void SetMonitorActive(bool active) {
    g_monitorActive = active;
}

bool ConsumeEarlyHit(int player, int pad) {
    const int index = player * 4 + pad;
    const ULONGLONG now = GetTickCount64();
    std::lock_guard<std::mutex> lock(g_earlyMutex);
    g_early.erase(std::remove_if(g_early.begin(), g_early.end(), [&](const EarlyHit& e) { return now - e.tick > kEarlyHitLifeMs; }),
                  g_early.end());
    for (auto it = g_early.begin(); it != g_early.end(); ++it) {
        if (it->pad == index) {
            g_early.erase(it);
            return true;
        }
    }
    return false;
}

} // namespace HitAudio
