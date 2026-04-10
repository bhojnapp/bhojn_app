import java.util.Properties
import java.io.FileInputStream
import java.io.File

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

// 🕵️‍♂️ DETECTIVE 1: Check if key.properties exists
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    println("✅ BHOJN LOG: key.properties ekdum sahi jagah mil gayi!")
} else {
    println("🚨 BHOJN ERROR: key.properties NAHI MILI! Main yahan dhoondh raha tha: ${keystorePropertiesFile.absolutePath}")
}

// 🕵️‍♂️ DETECTIVE 2: Check if upload-keystore.jks exists
val myKeystoreFile = file("upload-keystore.jks")
if (myKeystoreFile.exists()) {
    println("✅ BHOJN LOG: upload-keystore.jks (Thappa) ekdum sahi jagah mil gaya!")
} else {
    println("🚨 BHOJN ERROR: upload-keystore.jks NAHI MILI! Main yahan dhoondh raha tha: ${myKeystoreFile.absolutePath}")
}

android {
    namespace = "com.example.bhojn_app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.bhojn_app"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias") as String?
            keyPassword = keystoreProperties.getProperty("keyPassword") as String?
            storeFile = myKeystoreFile // Seedha path jo upar check kiya hai
            storePassword = keystoreProperties.getProperty("storePassword") as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}