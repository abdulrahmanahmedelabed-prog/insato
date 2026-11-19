#ifndef RUNNER_SYSTEM_AUDIO_CAPTURE_H_
#define RUNNER_SYSTEM_AUDIO_CAPTURE_H_

// F13: WASAPI shared-mode loopback capture of the default render endpoint
// ("what the speakers play", e.g. the other side of a Zoom / Teams call).
//
// A worker thread (COM multithreaded apartment) opens the default render
// device (eRender / eConsole) in loopback mode, polls the capture client
// every few milliseconds and hands interleaved float32 packets to a callback
// together with the mix format (sample rate, channel count). When the user
// switches the default output device (IMMNotificationClient) or the device
// disappears (AUDCLNT_E_DEVICE_INVALIDATED), capture restarts on the new
// default device. Loopback delivers no packets while nothing is playing;
// the Dart side fills that time with silence by wall clock.
//
// Callbacks run on the worker thread; the owner must marshal them to the
// platform thread (see SystemAudioChannel).

#include <windows.h>

#include <atomic>
#include <cstdint>
#include <functional>
#include <string>
#include <thread>
#include <vector>

struct IMMDeviceEnumerator;

class SystemAudioCapture {
 public:
  // One block of captured audio, interleaved float32 in [-1, 1].
  struct Packet {
    uint32_t sample_rate = 0;
    uint32_t channels = 0;
    std::vector<float> samples;
  };

  // Called on the worker thread with each captured block.
  using PacketCallback = std::function<void(Packet&& packet)>;

  // Called on the worker thread with a status event: "started" (first
  // device opened), "restarted" (default device changed, capture moved),
  // or "error" with a short code in |detail| ("no_device", "init",
  // "capture", "com").
  using EventCallback =
      std::function<void(const std::string& type, const std::string& detail)>;

  SystemAudioCapture(PacketCallback on_packet, EventCallback on_event);
  ~SystemAudioCapture();

  SystemAudioCapture(const SystemAudioCapture&) = delete;
  SystemAudioCapture& operator=(const SystemAudioCapture&) = delete;

  // Starts the worker thread. Returns false when it could not be created.
  // Calling Start while running is a no-op that returns true.
  bool Start();

  // Stops capture and joins the worker thread. Safe to call when stopped.
  void Stop();

  // True while the worker thread is alive.
  bool IsRunning() const { return running_.load(); }

  // True when the audio endpoint API is available (call on a thread with
  // COM initialised, e.g. the platform thread).
  static bool IsSupported();

 private:
  enum class Outcome { kStopped, kRestart, kFailed };

  void Run();
  Outcome CaptureOnce(IMMDeviceEnumerator* enumerator, bool first);

  PacketCallback on_packet_;
  EventCallback on_event_;
  HANDLE stop_event_ = nullptr;
  HANDLE restart_event_ = nullptr;
  std::thread thread_;
  std::atomic<bool> running_{false};
};

#endif  // RUNNER_SYSTEM_AUDIO_CAPTURE_H_
