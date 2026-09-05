plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.dayflower.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications requires this to use modern java.time
        // APIs on older Android versions.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.dayflower.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

    }

    // 🔴 **Without this the APK carries three copies of WebRTC.**
    //
    // `--target-platform android-arm64` trims the Flutter engine and the Dart
    // snapshot, but it does nothing to a *plugin's* prebuilt JNI — so
    // livekit_client's `libjingle_peerconnection_so.so` shipped for arm64
    // (11.5 MB), x86_64 (15.3 MB) and armeabi-v7a (6.5 MB) alike. That put the
    // APK at 62.2 MB, over the 50 MB ceiling the in-app updater has to live
    // under (see tool/publish_update.dart), so it could not be published.
    //
    // ⚠️ **`defaultConfig.ndk.abiFilters` does not do this.** It was tried
    // first, and verified reading the right value (`android-arm64 ->
    // [arm64-v8a]`), and the repackaged APK still contained all three — the
    // Flutter Gradle plugin sets abiFilters itself and wins. Excluding at
    // packaging time is applied unconditionally and actually drops them.
    //
    // Derived from Flutter's own `target-platform` property rather than
    // hardcoded, so `publish_update.dart --abi armeabi-v7a` keeps producing a
    // working 32-bit APK instead of one with no matching native libs. A plain
    // build with no `--target-platform` still packages every architecture.
    packaging {
        val requestedAbis =
            (project.findProperty("target-platform") as String?)
                ?.split(",")
                ?.map(String::trim)
                ?.mapNotNull { platform ->
                    when (platform) {
                        "android-arm64" -> "arm64-v8a"
                        "android-arm" -> "armeabi-v7a"
                        "android-x64" -> "x86_64"
                        "android-x86" -> "x86"
                        else -> null
                    }
                }
                .orEmpty()

        if (requestedAbis.isNotEmpty()) {
            val unusedAbis =
                listOf("arm64-v8a", "armeabi-v7a", "x86_64", "x86") - requestedAbis.toSet()
            jniLibs {
                excludes += unusedAbis.map { abi -> "lib/$abi/**" }.toSet()
            }
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
