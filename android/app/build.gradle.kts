import java.io.FileInputStream
import java.util.Properties

// ============================================================
// Turkey Tunnel — Android app module
// ============================================================
// This module hosts BOTH the native game (Rust core bundled via the
// hooks package, landscape-locked) AND the gray off-ramp (Firebase +
// AppsFlyer + WebView). The game must continue to launch even when
// the off-ramp credentials are missing — the Google Services plugin
// is therefore only applied when google-services.json is present.
// ============================================================

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Gradle plugin applied LAST, after Android + Kotlin.
    id("dev.flutter.flutter-gradle-plugin")
}

// The Google Services plugin can only run if the credentials file is
// present. Keep this guard — otherwise `flutter build` fails on fresh
// checkouts before Firebase has been wired for the project.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Release signing config loaded from android/key.properties (gitignored).
val signProps = Properties()
val signPropsFile = rootProject.file("key.properties")
val hasSigning = signPropsFile.exists()
if (hasSigning) {
    FileInputStream(signPropsFile).use { signProps.load(it) }
}

android {
    namespace = "tr.turkeytunnel.turkey_tunnel"

    // compileSdk pinned to 36 for plugin compatibility with the current
    // Firebase + AppsFlyer + flutter_local_notifications stack
    // (.cursor/rules/gray_part_pitfalls.md §2).
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications 22+ (java.time.*).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "tr.turkeytunnel.lo"
        // API 26 is the lowest API the current attribution SDK stack
        // supports. Do NOT bump unless a dependency literally refuses
        // to build — every extra API level cuts eligible users.
        minSdk = 26
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasSigning) {
                keyAlias = signProps.getProperty("keyAlias")
                keyPassword = signProps.getProperty("keyPassword")
                storeFile = signProps.getProperty("storeFile")?.let { file(it) }
                storePassword = signProps.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Minification stays OFF until proper keep-rules are in place
            // for Firebase/AppsFlyer/Rust-hooks — otherwise release builds
            // silently strip plugin glue. Flip to true alongside a
            // reviewed proguard-rules.pro.
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = if (hasSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("androidx.core:core-ktx:1.15.0")
}

flutter {
    source = "../.."
}
