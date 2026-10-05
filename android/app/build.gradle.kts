import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// กุญแจเซ็น APK ตัวจริง อ่านจาก android/key.properties (สร้างด้วย create-keystore.ps1)
// ไฟล์นี้และไฟล์ .jks ห้าม commit และต้องสำรองไว้ ถ้าหายจะอัปเดตแอปทับของเดิมไม่ได้
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKey = keystorePropertiesFile.exists()
if (hasReleaseKey) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
} else {
    // ไม่มี key.properties = APK release จะเซ็นด้วย debug key ซึ่งใครก็มี
    // แจกแบบนี้ไม่ได้ และอัปเดตทับแอปที่เซ็นด้วยกุญแจจริงไม่ได้ จึงเตือนให้เห็นชัด ๆ
    logger.warn(
        "WARNING: android/key.properties not found. Release builds will be signed " +
            "with the DEBUG key. Run create-keystore.ps1 before distributing the APK."
    )
}

android {
    namespace = "th.ac.rmutt.cpe.cpe_air_remote"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "th.ac.rmutt.cpe.cpe_air_remote"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // มี key.properties = เซ็นด้วยกุญแจของโปรเจกต์
            // ไม่มี = ใช้ debug key (ติดตั้งทดสอบได้ แต่ไม่ควรแจกใช้งานจริง)
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
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
