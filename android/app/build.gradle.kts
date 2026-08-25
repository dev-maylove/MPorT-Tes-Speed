import java.util.Properties
import java.io.FileInputStream
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    // kotlin-android plugin removed — using built-in Kotlin (AGP 9+)
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore properties if available
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun resolveKeystoreFile(storePath: String): File? {
    val inApp = file(storePath)
    if (inApp.exists()) return inApp
    val inRoot = rootProject.file(storePath)
    if (inRoot.exists()) return inRoot
    val inAppExplicit = rootProject.file("app/$storePath")
    if (inAppExplicit.exists()) return inAppExplicit
    return null
}

val storePathFromProps = if (keystorePropertiesFile.exists()) {
    keystoreProperties["storeFile"] as? String
} else null

val resolvedStoreFile: File? = storePathFromProps?.let { resolveKeystoreFile(it) }
val hasValidKeystore = resolvedStoreFile != null

android {
    namespace = "id.haansiro.mporttestspeed"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "id.haansiro.mporttestspeed"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Phone-first ABIs (drop x86/x86_64 — emulator-only).
        // CI still uses --split-per-abi for even smaller per-device APKs.
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }

        // App UI is Indonesian/English only — drop unused locale resources from deps
        resourceConfigurations += listOf("en", "in", "id")
    }

    signingConfigs {
        if (hasValidKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storePassword = keystoreProperties["storePassword"] as String
                storeFile = resolvedStoreFile
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasValidKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Fallback: debug signing — avoids validateSigningRelease failure
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            isDebuggable = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        resources {
            excludes += setOf(
                "META-INF/LICENSE*",
                "META-INF/NOTICE*",
                "META-INF/AL2.0",
                "META-INF/LGPL2.1",
                "META-INF/*.kotlin_module",
                "META-INF/DEPENDENCIES",
                "META-INF/INDEX.LIST",
                "**/kotlin-tooling-metadata.json",
                "DebugProbesKt.bin",
            )
        }
        // Compress .so inside APK (smaller download; slight first-load cost)
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}
