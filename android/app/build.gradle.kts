@file:Suppress("DEPRECATION")

import java.net.URI
import java.util.Base64
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

if (releaseTaskRequested) {
    val apiUrls = (project.findProperty("dart-defines")?.toString() ?: "")
        .split(',')
        .mapNotNull { encoded ->
            runCatching { String(Base64.getDecoder().decode(encoded), Charsets.UTF_8) }
                .getOrNull()
                ?.takeIf { it.startsWith("CONECTALAR_API_BASE_URL=") }
                ?.substringAfter('=')
        }
    val apiUrl = apiUrls.singleOrNull()
    val uri = apiUrl?.let { runCatching { URI(it) }.getOrNull() }
    val host = uri?.host?.lowercase()?.trimEnd('.')
    val enderecoLocal = host == null || !host.contains('.') || host == "localhost" ||
        host.endsWith(".localhost") || host.endsWith(".local") || host.contains(':') ||
        Regex("""\d{1,3}(?:\.\d{1,3}){3}""").matches(host)
    val enderecoExemplo = host == "example.com" || host?.endsWith(".example.com") == true ||
        host?.endsWith(".example") == true || host?.endsWith(".test") == true ||
        host?.endsWith(".invalid") == true
    if (uri?.scheme != "https" || enderecoLocal || enderecoExemplo || uri?.rawUserInfo != null ||
        uri?.rawQuery != null || uri?.rawFragment != null) {
        throw GradleException(
            "Build release bloqueado: informe CONECTALAR_API_BASE_URL com uma URL HTTPS " +
                "de domínio público usando --dart-define, sem credenciais ou parâmetros."
        )
    }
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

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
