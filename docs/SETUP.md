# Developer setup — Insato (إنصاتو)

This guide covers the toolchain, code generation, platform specifics, CI and
the release process. For the design see [ARCHITECTURE.md](ARCHITECTURE.md).

## 1. Toolchain

| Tool | Version |
|---|---|
| Flutter | **3.50.0**, stable channel (Dart 3.14) — the version CI uses |
| Android | JDK 17, Android SDK platform 36, NDK 28.2 (installed by the Flutter Gradle plugin on first build), Gradle 9.5 via wrapper, AGP 9.3 |
| iOS | macOS with a recent Xcode (iOS 16.4 deployment target), CocoaPods **not** required (Swift Package Manager, see §4.2) |
| Windows | Windows 10 1903+ / 11, Visual Studio 2022 with the *Desktop development with C++* workload |

```bash
flutter --version          # must report 3.50.x
flutter doctor -v          # resolve anything relevant to your target platform
```

## 2. First build

```bash
git clone <repo-url> insato && cd insato
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run                # pick a device / Windows desktop
```

### Code generation

The database layer uses [drift](https://drift.simonbinder.eu/); its
generated files (`lib/**/*.g.dart`) **are committed**. After changing a table,
query or anything annotated for drift, regenerate:

```bash
dart run build_runner build --delete-conflicting-outputs
# or, while developing:
dart run build_runner watch --delete-conflicting-outputs
```

CI regenerates and fails if the committed output is stale.

### Lints

`analysis_options.yaml` = `flutter_lints` + stricter rules (const
constructors, final locals, single quotes, `unawaited_futures`,
`cancel_subscriptions`, explicit return types, super parameters, …).
`flutter analyze` must report **zero** issues — infos included — because CI
treats every issue as a failure. Generated `*.g.dart` files are excluded.

## 3. Running with models and keys

- On first launch the app downloads the speech models (Silero VAD ~2 MB,
  WeSpeaker ~27 MB, Whisper Turbo ~1 GB by default) from the sherpa-onnx
  GitHub releases into the app's private data directory. Use Wi-Fi; on an
  emulator, prefer **Whisper Small** (~610 MB) to save time and RAM.
- Minutes engine: **Google Gemini** is the default. Create a free key at
  <https://aistudio.google.com/apikey>, enter it in **Settings → محرك كتابة
  المحضر**, and accept the free-tier data notice (nothing is sent before).
  The free tier is rate limited (a few requests per minute, a few dozen per
  day); the app waits out short per-minute limits once and otherwise reports
  them in Arabic. Claude (Anthropic key) is available as an optional engine;
  Deepgram is optional for cloud transcription. Keys live only in secure storage; never add
  keys to source, `.env` files or CI logs.
- Real devices are strongly recommended for audio work: emulator microphones
  are often low quality or silent. On the Android emulator enable
  *Extended controls → Microphone → Virtual microphone uses host audio input*.

## 4. Platform notes

### 4.1 Android

- `minSdk = 24` (Android 7.0) — the highest minimum among the plugins
  (`record_android`, `permission_handler_android`, `flutter_secure_storage`).
  `targetSdk`/`compileSdk` follow the Flutter defaults (36).
- Permissions declared in `android/app/src/main/AndroidManifest.xml`:
  `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS` (headset mic routing), `INTERNET`,
  `WAKE_LOCK`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MICROPHONE`,
  `POST_NOTIFICATIONS`; for v1.2 multi-device meetings also
  `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_MULTICAST_STATE`
  (mDNS discovery through `bonsoir` / NSD) and `CAMERA` (QR scanning with
  `mobile_scanner`; `android.hardware.camera` is declared *not required*).
  The guest's battery is read by `MainActivity.kt` (MethodChannel
  `insato/battery`).
- Multi-device meetings use plain `ws://` sockets on the LAN (all payloads
  are encrypted end to end by the app). Dart's own socket stack is not
  subject to `usesCleartextTraffic="false"`, which stays as is.
- The `flutter_foreground_task` service is declared with
  `foregroundServiceType="microphone"`. Android 14+ only allows starting it
  **while the app is visible and after `RECORD_AUDIO` has been granted** —
  the recording session requests permissions first, then starts the service.
- `allowBackup="false"` plus `data_extraction_rules.xml`: meeting data and
  Keystore-wrapped secrets are never backed up or transferred.
- 32-bit x86 native libraries shipped by `sherpa_onnx_android_x86` are
  excluded from packaging (Flutter has no x86 release engine). Supported ABIs:
  `arm64-v8a`, `armeabi-v7a`, `x86_64`.
- **Release signing.** Create `android/key.properties` (git-ignored):

  ```properties
  storeFile=/absolute/path/to/upload-keystore.jks
  storePassword=…
  keyAlias=upload
  keyPassword=…
  ```

  (A relative `storeFile` is resolved against `android/app/`.) The file uses
  Java properties syntax, so a backslash in a value (e.g. a Windows path)
  must be written as `\\` (`C:\\keys\\upload.jks`), or use forward slashes;
  it is read as UTF-8.

  Release builds can also take the signing values from the environment
  variables `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`,
  `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD`. A non-empty variable
  overrides the matching `key.properties` entry, and its value is used
  verbatim (no properties escaping). With neither the file nor
  `ANDROID_KEYSTORE_PATH`, release builds are signed with the **debug key**
  so they still build and install for testing — such builds cannot be
  uploaded to Google Play.
  Create an upload key with:

  ```bash
  keytool -genkeypair -v -keystore upload-keystore.jks -keyalg RSA \
    -keysize 2048 -validity 10000 -alias upload
  ```

### 4.2 iOS

- Deployment target **iOS 16.4**: the floor of `llamadart` (llama.cpp, the
  on-device minutes engine, F14); the other plugins need ≥ 13.0.
- Plugins are integrated with **Swift Package Manager** (enabled by default
  in Flutter 3.50; every plugin Insato uses ships a `Package.swift`), so the
  project has no `Podfile`.
- `Info.plist` contains `NSMicrophoneUsageDescription` (Arabic + English),
  `UIBackgroundModes = [audio]` (recording continues with the screen locked),
  display name **إنصاتو**, and `CFBundleLocalizations = [ar, en]`.
- v1.2 multi-device meetings: `NSLocalNetworkUsageDescription` (iOS asks
  for local-network access the first time a host advertises / a guest
  browses or connects), `NSBonjourServices = [_insato._tcp]` (required for
  Bonjour advertising and browsing since iOS 14) and
  `NSCameraUsageDescription` (QR scanning). If the user refuses local
  network access, discovery finds nothing and connections fail: re-enable it
  under *Settings → Privacy & Security → Local Network → إنصاتو*.
- `ITSAppUsesNonExemptEncryption` is `false`. The multi-device link uses
  standard ChaCha20-Poly1305 / HKDF / PBKDF2 (package:cryptography) to
  protect the user's own data; confirm the export-compliance answer for
  your distribution before submitting to the App Store.
- `AppDelegate.swift` also registers the `insato/battery` MethodChannel
  (UIDevice battery level) for guest devices.
- **permission_handler** compiles each permission in only when enabled. With
  SwiftPM this is automatic: its `Package.swift` reads `Info.plist` and enables
  `PERMISSION_MICROPHONE` because `NSMicrophoneUsageDescription` is present.
  When building from **Xcode.app** (not `flutter build`/`flutter run`), the
  package cannot locate the app automatically; run once:

  ```bash
  launchctl setenv PERMISSION_HANDLER_INFO_PLIST "$PWD/ios/Runner/Info.plist"
  rm -rf ~/Library/Developer/Xcode/DerivedData
  ```

  Otherwise every permission reports *denied*.
- **If you disable SwiftPM** (`flutter config --no-enable-swift-package-manager`)
  Flutter generates a CocoaPods `Podfile`. You must then add the microphone
  macro to its `post_install` block, or the microphone permission is compiled
  out:

  ```ruby
  post_install do |installer|
    installer.pods_project.targets.each do |target|
      flutter_additional_ios_build_settings(target)
      target.build_configurations.each do |config|
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
          '$(inherited)',
          'PERMISSION_MICROPHONE=1',
          'PERMISSION_NOTIFICATIONS=1',
        ]
      end
    end
  end
  ```

  and uncomment `platform :ios, '15.0'` at its top.
- `AppDelegate.swift` registers plugins for `flutter_foreground_task`'s
  background engine and excludes the app's Documents / Application Support
  directories from iCloud and computer backups (privacy).
- Signing: open `ios/Runner.xcworkspace`, set your Team and a unique bundle
  identifier under *Runner → Signing & Capabilities*.

### 4.3 Windows

- Window title **إنصاتو — محاضر الاجتماعات**, default size 1280×800, minimum
  400×640 (logical pixels, DPI-scaled). The title is written as UTF-16
  escapes in `windows/runner/main.cpp`, so no `/utf-8` compiler flag is needed.
- `runner.exe.manifest` sets the process code page to UTF-8 so native
  libraries (sherpa-onnx) can open model files under paths containing Arabic
  characters (e.g. an Arabic Windows user name).
- Microphone access requires *Settings → Privacy & security → Microphone →
  Let desktop apps access your microphone* to be **on**; otherwise capture
  yields silence (the `record` plugin always reports the permission as
  granted on Windows, so the capture service's silence watchdog warns the
  user instead).
- Data locations come from `CompanyName` / `ProductName` (both `Insato`) in
  `windows/runner/Runner.rc`, so never rename them:
  - `%LOCALAPPDATA%\Insato\Insato\` — `data\insato.sqlite`, `recordings\`,
    `exports\` (private, not roamed, not in Documents/OneDrive);
  - `%APPDATA%\Insato\Insato\` — `models\` and the DPAPI-encrypted
    `flutter_secure_storage.dat` holding the API keys.

  On first launch, `AppPaths.migrateLegacyWindowsData` moves what v1 kept in
  Documents (`insato.sqlite*`, `recordings\<uuid>.wav`) to the local folder.
  Files in `Documents\exports` are not migrated or deleted (the name is
  generic and may belong to other apps); new exports go to LocalAppData.
- The release output is the whole folder `build\windows\x64\runner\Release\`
  (exe + DLLs + `data\`); distribute it as one unit.
- **Firewall (v1.2 multi-device meetings).** The host listens for guests on
  a TCP port chosen at random (shown on the hosting screen) and advertises it
  over mDNS (UDP 5353). The first time a Windows PC hosts, Windows Defender
  Firewall asks whether to allow `insato.exe`: allow it on **private**
  networks, otherwise phones cannot connect (joining *from* Windows needs no
  rule). To fix a refused prompt: *Windows Security → Firewall & network
  protection → Allow an app through firewall → insato.exe → Private*, or in
  an elevated shell:

  ```powershell
  New-NetFirewallRule -DisplayName "Insato multi-device" -Direction Inbound `
    -Program "C:\path\to\insato.exe" -Action Allow -Profile Private
  ```

  The Wi-Fi network must be set to *Private* (a *Public* profile blocks
  inbound connections), and networks with client isolation (guest Wi-Fi,
  some hotels) do not let devices reach each other at all — use a phone
  hotspot instead. Windows has no camera QR scanner in Insato: guests on
  Windows type the code and address shown by the host.
- `windows/runner/battery_channel.cpp` serves the `insato/battery`
  MethodChannel (`GetSystemPowerStatus`).

### 4.4 Meeting bot (Windows)

Requirements on the user's PC: Microsoft Edge (preinstalled on Windows 10 /
11; Google Chrome is used when Edge is missing). Recording only the bot's
audio needs **Windows 10 version 2004 (build 19041) or later**
(process-loopback capture); older builds fall back to recording the whole
system output, with a warning. No WebView2 SDK, NuGet package or new link
library is needed (the runner resolves `ActivateAudioInterfaceAsync` from
Mmdevapi.dll at run time).

How each join flow has been verified so far (no Windows PC, no live
meetings in the development environment):

| Service | Verified by |
|---|---|
| Google Meet | code review + mock page in headless Chrome on Linux (real CDP driver, page script, permissions) |
| Microsoft Teams (web) | code review + mock page in headless Chrome on Linux |
| Zoom (web client) | code review + mock page in headless Chrome on Linux (passcode, waiting room, "host has not started", Join Audio by Computer) |
| Cisco Webex (web) | code review only — experimental |
| Native process loopback (C++) | code review only — never compiled here |

To verify on a real Windows PC (checklist):

1. `flutter build windows` compiles with `/W4 /WX` (new files
   `bot_audio_capture.cpp`, `bot_audio_channel.cpp`).
2. Meeting bot screen → paste a Meet link of a meeting you organise from
   another account / phone: Edge starts minimised with a fresh profile,
   the name is filled, microphone and camera are off, "Ask to join"
   appears on the organiser's side with the bot's name; admit it.
3. The recording starts only after admission; the status says
   "process audio only"; play music on the PC: it must **not** be in the
   recording; speak in the meeting from the other device: it must be.
4. Repeat with Teams (work link and teams.live.com), Zoom (link with pwd,
   link without pwd + typed passcode, meeting with a waiting room, meeting
   not yet started), and a Webex link.
5. End scenarios: organiser ends the meeting; everyone else leaves (bot
   leaves ~2 min later); organiser removes the bot; organiser declines the
   knock; user presses stop; user stops from the recording screen; user
   closes the bot's Edge window. Each ends with the right Arabic reason and
   a saved meeting when something was recorded.
6. Scheduled join a few minutes ahead while the app stays open.
7. On a Windows 10 build older than 19041 (or with process loopback
   failing) the fallback warning appears and system audio is recorded.
8. Check whether lowering the bot's volume in the Windows Volume Mixer
   affects the recording (not relied upon; documented limitation).
9. If a service changed its page, update `lib/features/meeting_bot/bot_scripts.dart`
   (texts / selectors / labels) and bump `kBotScriptsVersion`. "Show the
   bot window" on the bot screen helps to see where a flow stops.

Limitations: the meeting audio plays on the PC's speakers during the
recording (process loopback captures what the browser renders; muting the
browser with `--mute-audio` would silence the capture too). A CAPTCHA, a
sign-in requirement or a Webex site that requires an e-mail stops the bot:
it never bypasses them (for a CAPTCHA it shows its window so the user can
complete it).

## 5. Continuous integration

`.github/workflows/ci.yml` runs on every push and pull request
(Markdown/docs-only changes are skipped):

1. `flutter pub get` (Flutter 3.50.0 stable, SDK + pub cache cached)
2. drift code generation, failing if committed `*.g.dart` files are stale
3. `flutter analyze` (zero issues required)
4. `flutter test --coverage` (`coverage/lcov.info` uploaded as an artifact)

Reproduce locally before pushing:

```bash
dart run build_runner build --delete-conflicting-outputs && git diff --exit-code -- '*.g.dart'
flutter analyze
flutter test --coverage
```

## 6. Releasing

`.github/workflows/build.yml` builds all platforms on tags `v*` and on manual
dispatch:

| Job | Runner | Output |
|---|---|---|
| `build-android` | ubuntu-latest, Temurin JDK 17 | split APKs per ABI + `.aab` |
| `build-windows` | windows-latest | ZIP of `build/windows/x64/runner/Release` |
| `build-ios` | macos-latest | **unsigned** `.ipa` (`Payload/Runner.app`) |
| `release` | ubuntu-latest | GitHub Release with all artifacts + `SHA256SUMS.txt` (tags only) |

Steps:

1. Bump `version:` in `pubspec.yaml` (e.g. `1.2.0+1`; the build number is
   replaced in CI by the workflow run number so Android `versionCode` always
   increases).
2. Commit, then tag with exactly the same version and push:

   ```bash
   git tag v1.2.0 && git push origin v1.2.0
   ```

   The workflow fails early if the tag does not match `pubspec.yaml`. Tags
   containing `-` (e.g. `v1.2.0-beta.1`, with the same pubspec version) are
   published as pre-releases.
3. Optional repository secrets for a Play-ready Android build:

   | Secret | Value |
   |---|---|
   | `ANDROID_KEYSTORE_BASE64` | `base64 -w0 upload-keystore.jks` |
   | `ANDROID_KEYSTORE_PASSWORD` | keystore password |
   | `ANDROID_KEY_ALIAS` | key alias (e.g. `upload`) |
   | `ANDROID_KEY_PASSWORD` | key password |

   Without them, Android artifacts are debug-signed (fine for side-loading
   tests, rejected by Google Play). The workflow decodes the keystore into
   the runner's temporary directory and passes the path, passwords and alias
   to Gradle as the environment variables described in 4.1; it no longer
   writes them to `key.properties`, and it deletes the keystore at the end of
   the job.
4. The iOS IPA is unsigned: re-sign it (e.g. with your distribution
   certificate and provisioning profile via Xcode/fastlane) before installing
   or uploading to TestFlight. `ITSAppUsesNonExemptEncryption` is `false`
   (HTTPS only), so no export-compliance prompt is needed.

## 7. Repository conventions

- Shared contracts (`lib/core/models.dart`, `lib/core/interfaces.dart`,
  `lib/core/errors.dart`) change only deliberately, with all dependants
  updated in the same change.
- User-facing strings are Modern Standard Arabic; code, comments and docs
  are English (user docs bilingual).
- Pure-Dart logic gets unit tests under `test/`, mirroring `lib/` paths.
- Licensing: to be decided by the repository owner. Bundled fonts are under
  the SIL Open Font License 1.1 (`assets/fonts/OFL.txt`).
