plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "traevy.traevy"
    // compileSdk is the SDK headers used at build time. drift_flutter pulls in
    // jni / jni_flutter which require API 35 headers. Runtime behavior is
    // governed by targetSdk (34) and minSdk (34), keeping D-08 intact.
    compileSdk = 35
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "traevy.traevy"
        // Phase 1 D-08: pin minSdk and targetSdk to 34. The user accepts the
        // narrower device coverage in exchange for a modern API baseline.
        // Do not replace these with `flutter.*` indirection.
        minSdk = 34
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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
