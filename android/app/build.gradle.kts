import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------------------------
// Release signing
//
// When android/key.properties exists (see docs/SETUP.md, created by the
// release workflow from repository secrets), release builds are signed with
// that upload key. Otherwise they fall back to the debug key so that
// `flutter build apk --release` still works locally and in CI forks without
// secrets. Debug-signed artifacts are for testing only and cannot be uploaded
// to Google Play.
//
// key.properties format:
//   storeFile=/absolute/or/relative-to-android-app/path/upload-keystore.jks
//   storePassword=...
//   keyAlias=upload
//   keyPassword=...
// ---------------------------------------------------------------------------
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.isFile
if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

/** Reads a required key.properties entry, failing the build with a clear message. */
fun releaseProperty(name: String): String =
    keystoreProperties.getProperty(name)?.takeIf { it.isNotBlank() }
        ?: throw GradleException("android/key.properties is missing '$name'")

android {
    namespace = "app.katib.katib"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.katib.katib"
        // API 24 (Android 7.0) is the highest minimum among the plugins in use:
        // record_android, permission_handler_android and flutter_secure_storage
        // require 24; sherpa_onnx_android_* and flutter_foreground_task need 21.
        // Set explicitly so a Flutter SDK default change cannot lower it.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(releaseProperty("storeFile"))
                storePassword = releaseProperty("storePassword")
                keyAlias = releaseProperty("keyAlias")
                keyPassword = releaseProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (hasReleaseKeystore) {
                    signingConfigs.getByName("release")
                } else {
                    // Fallback so CI and local release builds work without secrets.
                    signingConfigs.getByName("debug")
                }
        }
    }

    packaging {
        jniLibs {
            // sherpa_onnx ships a 32-bit x86 build (sherpa_onnx_android_x86), but
            // Flutter has no x86 engine for release builds, so those libraries
            // could never be loaded. Dropping them keeps the universal APK and
            // the app bundle smaller. arm64-v8a, armeabi-v7a and x86_64 remain.
            excludes += "**/x86/*.so"
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
