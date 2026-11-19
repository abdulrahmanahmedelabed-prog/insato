# Developer setup — Insato (إنصاتو)

This guide covers the toolchain, code generation, platform specifics, CI and
the release process. For the design see [ARCHITECTURE.md](ARCHITECTURE.md).

## 1. Toolchain

| Tool | Version |
|---|---|
| Flutter | **3.50.0**, stable channel (Dart 3.14) — the version CI uses |
| Android | JDK 17, Android SDK platform 36, NDK 28.2 (installed by the Flutter Gradle plugin on first build), Gradle 9.5 via wrapper, AGP 9.3 |
| iOS | macOS with a recent Xcode (iOS 15.0 deployment target), CocoaPods **not** required (Swift Package Manager, see §4.2) |
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
- Enter the Anthropic API key (required for minutes) and optionally the
  Deepgram key in **Settings**. Keys live only in secure storage; never add
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
  `POST_NOTIFICATIONS`.
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

- Deployment target **iOS 15.0** (plugins need ≥ 13.0; Flutter's default is
  15.0).
- Plugins are integrated with **Swift Package Manager** (enabled by default
  in Flutter 3.50; every plugin Insato uses ships a `Package.swift`), so the
  project has no `Podfile`.
- `Info.plist` contains `NSMicrophoneUsageDescription` (Arabic + English),
  `UIBackgroundModes = [audio]` (recording continues with the screen locked),
  display name **إنصاتو**, and `CFBundleLocalizations = [ar, en]`.
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
