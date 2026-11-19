import Flutter
import UIKit
import UserNotifications
import flutter_foreground_task

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    excludeAppDataFromBackup()

    // flutter_foreground_task runs its TaskHandler in a separate headless
    // engine; plugins must be registered on that engine too (see the plugin's
    // README, "iOS > Swift").
    SwiftFlutterForegroundTaskPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    // Lets the "recording in progress" notification show while Katib is in
    // the foreground.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// Keeps meeting audio, transcripts, voiceprints and downloaded models out
  /// of iCloud / computer backups (privacy policy: they never leave the
  /// device; models are re-downloadable). Excluding a directory excludes
  /// everything inside it. Mirrors android:allowBackup="false" on Android.
  private func excludeAppDataFromBackup() {
    let fileManager = FileManager.default
    let directories: [FileManager.SearchPathDirectory] = [
      .documentDirectory,
      .applicationSupportDirectory,
    ]
    for directory in directories {
      guard var url = fileManager.urls(for: directory, in: .userDomainMask).first else {
        continue
      }
      do {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
      } catch {
        NSLog("Katib: could not exclude %@ from backup: %@", url.path, error.localizedDescription)
      }
    }
  }
}
