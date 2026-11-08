plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Gradle plugin Android aur Kotlin plugins ke baad aana chahiye
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.highschool.assam"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.highschool.assam"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Abhi debug key se sign hoga taaki APK install ho sake.
            // Play Store ke liye apni keystore lagani hogi.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}
