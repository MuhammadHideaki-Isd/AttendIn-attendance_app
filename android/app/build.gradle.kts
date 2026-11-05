plugins {
    id("com.android.application")

    // Google Services Gradle Plugin
    id("com.google.gms.google-services")

    // Kotlin Android Plugin
    id("org.jetbrains.kotlin.android")

    // Flutter Gradle Plugin
    // Must be applied after Android and Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.attendance_app"
    compileSdk = flutter.compileSdkVersion

    defaultConfig {
        applicationId = "com.example.attendance_app_deki"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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

dependencies {
    // Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:35.1.0"))

    // Firebase Analytics
    implementation("com.google.firebase:firebase-analytics")
}
