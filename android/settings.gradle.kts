pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // Updated AGP to 8.9.1
    id("com.android.application") version "8.9.1" apply false

    // ✅ Google Services plugin (upgrade to latest stable)
    id("com.google.gms.google-services") version "4.4.2" apply false

    // Updated Kotlin plugin to 2.1.0 to match AGP requirements
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
