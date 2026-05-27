plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.jcbpartner.ludo_pay_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.jcbpartner.ludo_pay_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
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

    // Rename split APKs: FestiBuvette_64.apk / FestiBuvette_32.apk
    applicationVariants.all {
        outputs.forEach { output ->
            val apkOutput = output as? com.android.build.gradle.internal.api.ApkVariantOutputImpl
            val abi = apkOutput?.getFilter(com.android.build.OutputFile.ABI)
            if (abi != null) {
                apkOutput.outputFileName = when (abi) {
                    "arm64-v8a"    -> "FestiBuvette_64.apk"
                    "armeabi-v7a"  -> "FestiBuvette_32.apk"
                    "x86_64"       -> "FestiBuvette_x86_64.apk"
                    else           -> "FestiBuvette_${abi}.apk"
                }
            }
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
