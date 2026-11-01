#pragma once

// 叩いた音などの効果音を、遅れを小さくして鳴らす出力（Windows の WASAPI 共有モード）
// raylib の音声出力は曲の再生に合わせた大きめのバッファで鳴るので、叩いてから音が出るまでに遅れる。
// ここでは IAudioClient3 の最小の周期（多くの環境で 2〜10ms）で、自前で混ぜて出す。
// Windows のヘッダーは raylib.h とぶつかるので、この関数だけを外に見せる。
namespace HitAudio {

// 出力を始める。使えなければ false（そのときは raylib で鳴らす）
bool Init();
void Shutdown();
bool IsReady();
// 出力の周期・バッファ・先に書いておく量（ms。確認用）
float PeriodMs();
float BufferMs();
float QueueMs();

// 16bit の音を登録して番号を返す（出力の形式に合わせて変換しておく）。失敗したら -1
int Register(const short* samples, int frames, int channels, int sampleRate);

// 登録した音を鳴らす（同じ音を重ねて鳴らせる）
void Play(int id, float volume = 1.0f);
void StopAll();

// ---- 叩いた瞬間の音 ----
// 画面は 120FPS で描くので、キーの入力を画面の切れ目でしか見ないと、叩いてから音が出るまでに最大 1 フレーム（約 8ms）遅れる。
// 専用のスレッドでキーを 1ms ごとに見て、叩いた瞬間に音を鳴らす。画面側は、判定のときに「もう鳴らした」と知って、音を重ねない。
// 太鼓の面・ふち（pad: 0 左ふち 1 左面 2 右面 3 右ふち）ごとに、鳴らす音と割り当てたキー（Windows の仮想キー）を登録する
void SetPadSound(int player, int pad, int soundId, float volume, const int* virtualKeys, int keyCount);
void ClearPadSounds();
// 叩いたときに音を鳴らす監視を、入れる／切る（ポーズ中・演奏のあと・ウィンドウが前にないときは鳴らさない）
void SetMonitorActive(bool active);
// 監視が先に音を鳴らした叩きを1つ使う（画面側の判定で、同じ叩きの音を重ねて鳴らさないため）。なければ false
bool ConsumeEarlyHit(int player, int pad);

} // namespace HitAudio
