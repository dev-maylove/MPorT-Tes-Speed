import java.util.Properties
import java.io.FileInputStream
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore properties if available
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun resolveKeystoreFile(storePath: String): File? {
    // Relative to app module
    val inApp = file(storePath)
    if (inApp.exists()) return inApp
    // Relative to android/
    val inRoot = rootProject.file(storePath)
    if (inRoot.exists()) return inRoot
    // Explicit android/app/
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
    }

    signingConfigs {
        // Only create release config when keystore file really exists
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
                // Fallback: unsigned/debug signing — avoids validateSigningRelease failure
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
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
