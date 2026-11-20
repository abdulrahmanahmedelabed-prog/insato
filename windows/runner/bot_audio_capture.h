#ifndef RUNNER_BOT_AUDIO_CAPTURE_H_
#define RUNNER_BOT_AUDIO_CAPTURE_H_

// Meeting bot: WASAPI process-loopback capture of one process tree (the
// bot's Edge / Chrome browser), so only the meeting is recorded - not the
// user's other applications and not Insato itself.
//
// Uses ActivateAudioInterfaceAsync on the virtual device
// "VAD\Process_Loopback" with AUDIOCLIENT_ACTIVATION_TYPE_PROCESS_LOOPBACK
// and PROCESS_LOOPBACK_MODE_INCLUDE_TARGET_PROCESS_TREE (Windows 10
// version 2004, build 19041, or later). The activation structures are
// declared locally (same layout as audioclientactivationparams.h) and the
// function is resolved from Mmdevapi.dll at run time, so the runner builds
// with any Windows 10 SDK and still starts on older Windows, where
// IsSupported() simply returns false and the Dart side falls back to the
// full system loopback (SystemAudioCapture).
//
// The process-loopback client has no mix format; the stream is opened as
// 48 kHz stereo PCM16 with AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM and handed
// on as interleaved float32 packets (same Packet type and events as
// SystemAudioCapture). Callbacks run on the worker thread; the owner
// marshals them to the platform thread (see BotAudioChannel).

#include <windows.h>

#include <atomic>
#include <functional>
#include <string>
#include <thread>

#include "system_audio_capture.h"

class BotAudioCapture {
 public:
  using PacketCallback =
      std::function<void(SystemAudioCapture::Packet&& packet)>;
  // "started", or "error" with a code in |detail|: "unsupported", "activate",
  // "init", "capture", "com".
  using EventCallback =
      std::function<void(const std::string& type, const std::string& detail)>;

  BotAudioCapture(PacketCallback on_packet, EventCallback on_event);
  ~BotAudioCapture();

  BotAudioCapture(const BotAudioCapture&) = delete;
  BotAudioCapture& operator=(const BotAudioCapture&) = delete;

  // Starts capturing |pid| and its child processes. Waits (a few seconds at
  // most) until the stream is activated; returns false when it could not be
  // (unsupported Windows, invalid process, activation refused). Calling
  // Start while running stops the previous capture first.
  bool Start(DWORD pid);

  // Stops capture and joins the worker thread. Safe to call when stopped.
  void Stop();

  // True when process-loopback capture exists here (Windows build >= 19041
  // and ActivateAudioInterfaceAsync available).
  static bool IsSupported();

 private:
  enum class Outcome { kStopped, kFailed };

  void Run(DWORD pid);
  // Activates and captures until stop or failure. Reports the first
  // activation result through ready_event_ / ready_ok_.
  Outcome CaptureOnce(DWORD pid, bool* reported);
  void ReportReady(bool ok, bool* reported);

  PacketCallback on_packet_;
  EventCallback on_event_;
  // Manual-reset: Stop() was requested.
  HANDLE stop_event_ = nullptr;
  // Auto-reset: the audio engine has a packet for us.
  HANDLE audio_event_ = nullptr;
  // Manual-reset: the first activation finished (see ready_ok_).
  HANDLE ready_event_ = nullptr;
  std::atomic<bool> ready_ok_{false};
  std::thread thread_;
  std::atomic<bool> running_{false};
};

#endif  // RUNNER_BOT_AUDIO_CAPTURE_H_
