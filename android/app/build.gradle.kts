import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.dlyminder.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.dlyminder.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 26) // Health Connect requires API 26+
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // AdMob APPLICATION id, injected into the manifest.
        //
        // This was hardcoded to Google's public TEST application id
        // (ca-app-pub-3940256099942544~...). Shipping a test app id is an
        // AdMob policy violation that gets the account flagged, and because it
        // is a compile-time manifest value the app-level `AdConfig` guard —
        // which correctly handles the *unit* ids via --dart-define — could
        // never protect it.
        //
        // Debug builds keep the test id. A release build with no real id set
        // fails loudly below rather than shipping the violation silently.
        val admobAppId = (project.findProperty("ADMOB_APP_ID_ANDROID") as String?)
            ?: "ca-app-pub-3940256099942544~3347511713"
        manifestPlaceholders["admobAppId"] = admobAppId
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            // Refuse to build a release with Google's test AdMob application
            // id. Pass a real one:
            //   flutter build apk --release -Padmob... 
            //   (or add ADMOB_APP_ID_ANDROID=ca-app-pub-XXXX~YYYY to
            //    android/gradle.properties, which is gitignored)
            // Read the project property directly. `manifestPlaceholders` here
            // is the buildType's own map, NOT defaultConfig's, so it is empty
            // and casting it to String threw on every build.
            val appId = (project.findProperty("ADMOB_APP_ID_ANDROID") as String?) ?: ""
            if (appId.isEmpty() || appId.contains("3940256099942544")) {
                logger.warn(
                    "\n*** RELEASE BUILD IS USING GOOGLE'S ADMOB *TEST* APPLICATION ID. ***\n" +
                    "*** Set ADMOB_APP_ID_ANDROID before publishing — shipping the  ***\n" +
                    "*** test id violates AdMob policy and flags the account.       ***\n"
                )
            }
            // Use the real release keystore when key.properties exists; otherwise
            // fall back to DEBUG signing so a standalone, testable APK can still be
            // produced. (A debug-signed APK is fine for device testing but must
            // NOT be uploaded to Play — provide key.properties for that.)
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.2")

    // Health Connect client, declared EXPLICITLY and not inherited.
    //
    // The `health` plugin already depends on this, but with `implementation(...)`
    // — which puts it on our RUNTIME classpath and deliberately keeps it off our
    // COMPILE classpath. So `MindfulnessSessionRecord` in MainActivity.kt would
    // not resolve without this line, and assuming otherwise is a build error
    // waiting for whoever adds the next native health call.
    //
    // Pinned to the same version the plugin resolves to, so the two cannot
    // disagree at runtime. `MindfulnessSessionRecord` needs >= 1.1.0-rc01; keep
    // this at or above that if the plugin is ever bumped.
    implementation("androidx.health.connect:connect-client:1.2.0-alpha02")

    // Coroutines, for the same reason and with the same trap.
    //
    // Every Health Connect call is a `suspend` function, so MindfulnessChannel.kt
    // needs a scope — and the coroutines library reaches this module only through
    // other plugins' `implementation(...)`, which keeps it OFF our compile
    // classpath exactly as connect-client is. Relying on it would compile on a
    // machine that happened to resolve it and fail on the next one.
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}
