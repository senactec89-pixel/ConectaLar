import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningPropertiesFile = rootProject.file("key.properties")
val releaseSigningProperties = Properties()
if (releaseSigningPropertiesFile.isFile) {
    releaseSigningPropertiesFile.inputStream().use {
        releaseSigningProperties.load(it)
    }
}
val releaseSigningKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val missingReleaseSigningKeys = releaseSigningKeys.filter {
    releaseSigningProperties.getProperty(it).isNullOrBlank()
}
val releaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (releaseTaskRequested && missingReleaseSigningKeys.isNotEmpty()) {
    throw GradleException(
        "Build release bloqueado: configure android/key.properties " +
            "com os campos storeFile, storePassword, keyAlias e keyPassword. " +
            "A chave release nunca deve ser enviada ao Git."
    )
}

android {
    namespace = "br.com.conectalar.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "br.com.conectalar.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["googleMapsApiKey"] =
            System.getenv("GOOGLE_MAPS_ANDROID_API_KEY") ?: ""
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.create("release") {
                if (missingReleaseSigningKeys.isEmpty()) {
                    storeFile = file(releaseSigningProperties.getProperty("storeFile"))
                    storePassword = releaseSigningProperties.getProperty("storePassword")
                    keyAlias = releaseSigningProperties.getProperty("keyAlias")
                    keyPassword = releaseSigningProperties.getProperty("keyPassword")
                }
            }
        }
    }
}

flutter {
    source = "../.."
}
