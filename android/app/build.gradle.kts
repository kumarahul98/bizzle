plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "traevy.traevy"
    // compileSdk is the SDK headers used at build time. Phase 2 plugins
    // (flutter_local_notifications 21, geolocator_android, package_info_plus)
    // require API 36 headers; compileSdk is backward-compatible so bumping it
    // does not change runtime behavior, which is governed by targetSdk (34)
    // and minSdk (34), keeping Phase 1 D-08 intact.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications (Phase 2) for Java 8+ API
        // desugaring on minSdk 34 builds. Pair with coreLibraryDesugaring dep
        // below.
        isCoreLibraryDesugaringEnabled = true
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
            // Sign release builds with the debug keystore so sideloaded APKs
            // install on physical devices for testing. Replace with a real
            // release signingConfig before publishing to the Play Store —
            // debug-signed APKs cannot be uploaded.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
