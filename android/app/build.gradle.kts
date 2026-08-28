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
    val configured = File(storePath)
    if (configured.isAbsolute && configured.exists()) return configured

    val candidates = listOf(
        rootProject.file(storePath),
        rootProject.file("app/$storePath"),
    )
    return candidates.firstOrNull { it.exists() }
}

val storePathFromProps = if (keystorePropertiesFile.exists()) {
    keystoreProperties["storeFile"] as? String
} else null

val resolvedStoreFile: File? = storePathFromProps?.takeIf { it.isNotBlank() }?.let { resolveKeystoreFile(it) }
val hasSigningProperties = keystorePropertiesFile.exists() &&
    listOf("storePassword", "keyPassword", "keyAlias", "storeFile").all {
        (keystoreProperties[it] as? String)?.isNotBlank() == true
    }
val hasValidKeystore = hasSigningProperties && resolvedStoreFile?.isFile == true

android {
    namespace = "id.haansiro.mporttestspeed"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications (java.time etc. on older Android)
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "id.haansiro.mporttestspeed"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Do NOT set ndk.abiFilters here.
        // Flutter --split-per-abi / --target-platform already controls ABIs.
        // Combining both causes:
        //   "Conflicting configuration … ndk abiFilters cannot be present when splits abi filters are set"

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
            require(hasValidKeystore) {
                "Release signing is not configured. CI must generate android/key.properties " +
                    "from GitHub Secrets and provide a valid private-key keystore."
            }
            signingConfig = signingConfigs.getByName("release")
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

dependencies {
    // Java 8+ API desugaring for flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
