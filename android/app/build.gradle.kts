import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------------------------
// Release signing
//
// Release builds are signed with an upload key when one is configured, either
//   * through environment variables (used by the release workflow, so secrets
//     are passed verbatim and never parsed by java.util.Properties):
//       ANDROID_KEYSTORE_PATH, ANDROID_KEYSTORE_PASSWORD,
//       ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD
//   * or through android/key.properties (local builds, see docs/SETUP.md):
//       storeFile=/absolute/or/relative-to-android-app/path/upload-keystore.jks
//       storePassword=...
//       keyAlias=upload
//       keyPassword=...
//     Note: key.properties uses Java properties syntax, so a backslash in a
//     value must be written as \\. Non-ASCII values are read as UTF-8.
// A non-empty environment variable takes precedence over key.properties.
// Otherwise builds fall back to the debug key so that
// `flutter build apk --release` still works locally and in CI forks without
// secrets. Debug-signed artifacts are for testing only and cannot be uploaded
// to Google Play.
// ---------------------------------------------------------------------------
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.isFile) {
    keystorePropertiesFile.reader(Charsets.UTF_8).use { keystoreProperties.load(it) }
}

/** Environment variable overriding each signing value. */
val releaseSigningEnv =
    mapOf(
        "storeFile" to "ANDROID_KEYSTORE_PATH",
        "storePassword" to "ANDROID_KEYSTORE_PASSWORD",
        "keyAlias" to "ANDROID_KEY_ALIAS",
        "keyPassword" to "ANDROID_KEY_PASSWORD",
    )

fun releaseEnv(name: String): String? =
    providers.environmentVariable(releaseSigningEnv.getValue(name)).orNull?.takeIf { it.isNotEmpty() }

val hasReleaseKeystore = keystorePropertiesFile.isFile || releaseEnv("storeFile") != null

/** Reads a required signing value (env first, then key.properties), failing the build with a clear message. */
fun releaseProperty(name: String): String =
    releaseEnv(name)
        ?: keystoreProperties.getProperty(name)?.takeIf { it.isNotBlank() }
        ?: throw GradleException(
            "Release signing value '$name' is missing " +
                "(set ${releaseSigningEnv.getValue(name)} or add it to android/key.properties)",
        )

android {
    namespace = "app.insato.insato"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.insato.insato"
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
