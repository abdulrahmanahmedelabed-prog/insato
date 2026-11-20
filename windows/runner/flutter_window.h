#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <memory>

#include "audio_decoder_channel.h"
#include "battery_channel.h"
#include "bot_audio_channel.h"
#include "system_audio_channel.h"
#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // F13: system-audio (WASAPI loopback) channels.
  std::unique_ptr<SystemAudioChannel> system_audio_;
  std::unique_ptr<BatteryChannel> battery_;
  // Recording import: Media Foundation audio decoder.
  std::unique_ptr<AudioDecoderChannel> audio_decoder_;
  // Meeting bot: process-loopback capture of the bot browser.
  std::unique_ptr<BotAudioChannel> bot_audio_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
