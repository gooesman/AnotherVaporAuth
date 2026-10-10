import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is loaded from android/key.properties (git-ignored, never
// committed). When it's absent — CI, or a dev who only builds debug — release
// APKs fall back to the debug keystore so `flutter run --release` still works.
// Store bundles (bundleRelease) are the exception: they must never ship
// debug-signed, so those fail closed below when key.properties is missing.
// See android/key.properties.example.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

// Fork previews have a separate identity and a persistent private signing key,
// so installing future previews can update them without touching AVA/dev data.
val avaForkPreview = (project.findProperty("avaForkPreview") as String?) == "true"
if (avaForkPreview) {
    val requiredSigningFields = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    if (!hasReleaseSigning ||
        requiredSigningFields.any { keystoreProperties.getProperty(it).isNullOrBlank() }
    ) {
        throw GradleException(
            "AVA Fork previews require android/key.properties with storeFile, " +
                "storePassword, keyAlias and keyPassword; debug-key fallback is disabled."
        )
    }
    if (!file(keystoreProperties.getProperty("storeFile")).isFile) {
        throw GradleException("AVA Fork preview signing keystore does not exist.")
    }
}

android {
    namespace = "pro.dotslash.ava"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // AGP disables generated values unless requested; the debug/fork labels
    // below are deliberately resource-backed so their manifest stays shared.
    buildFeatures {
        resValues = true
    }

    // The optional ARM64 core must be installed by Android into nativeLibraryDir,
    // never copied to/exec'd from writable app storage. It is an unchanged ELF
    // executable packaged with a .so name, not a library to dlopen or strip.
    packaging {
        jniLibs {
            useLegacyPackaging = true
            keepDebugSymbols += "**/libava_steam_core.so"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = if (avaForkPreview) "pro.dotslash.ava.fork" else "pro.dotslash.ava"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resValue("string", "ava_app_label", if (avaForkPreview) "AVA Fork" else "AVA")
        if (avaForkPreview) {
            // --target-platform limits Flutter's own binaries, while plugins
            // may still contribute other ABIs. Match the bundled ARM64 core
            // and avoid shipping unusable native libraries in this preview.
            ndk {
                abiFilters.clear()
                abiFilters += "arm64-v8a"
            }
        }
    }

    // Distribution channels. Same applicationId on purpose: play and cn have
    // always shipped under one package name and upgrades must keep working
    // in both directions. Play-only dependencies (ads/billing/sign-in) hook
    // into the `play` flavor; the cn APK must never contain them.
    flavorDimensions += "channel"
    productFlavors {
        create("play") { dimension = "channel" }
        create("cn") { dimension = "channel" }
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = (keystoreProperties["storeFile"] as String).let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
                keystoreProperties.getProperty("storeType")?.let { storeType = it }
            }
        }
    }

    buildTypes {
        debug {
            // Installs side-by-side with a store build instead of colliding
            // with it. The Play APK owns `pro.dotslash.ava` and is signed by
            // Play App Signing, so a locally-signed APK can never replace it —
            // `install -r` fails, and the only way through would be an
            // uninstall, which wipes the user's maFiles/keystore. A suffixed
            // id sidesteps that entirely: the dev copy is its own app with its
            // own (empty) data. Release builds keep the real id untouched.
            applicationIdSuffix = if (avaForkPreview) null else ".dev"
            versionNameSuffix = if (avaForkPreview) "-fork" else "-dev"
            resValue("string", "ava_app_label", if (avaForkPreview) "AVA Fork" else "AVA dev")
            if (avaForkPreview) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
        release {
            // The optimized fork keeps the installed preview's package,
            // signing identity and version-name suffix for in-place updates.
            if (avaForkPreview) {
                versionNameSuffix = "-fork"
            }
            // Use the real upload key when key.properties is present; otherwise
            // fall back to debug signing so release builds still run locally/CI.
            signingConfig = if (hasReleaseSigning)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            // Keep rules for reflection-based libraries (ML Kit barcode) that
            // R8 full mode otherwise breaks in release builds.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// Fail closed on anything shippable built without the upload key.
//
// The AAB was already covered: it would be debug-signed and rejected by Play.
// The release *APK* was not, and that is the more dangerous of the two — the
// cn channel ships an APK directly to users, and the Android debug keystore's
// password is a published constant. A debug-signed AVA in someone's hands can
// be replaced by an update anyone is able to sign.
//
// `flutter run --release` on a machine with no key still has a way through,
// because refusing that outright would be obnoxious — but it has to be asked
// for by name, so it can never happen to a build that was meant to ship.
val allowDebugSigning = (project.findProperty("allowDebugSigning") as String?) == "true"
gradle.taskGraph.whenReady {
    // bundleRelease / bundle<Flavor>Release, assembleRelease / assemble<Flavor>Release
    val shippable = Regex("^(bundle|assemble)\\w*Release$")
    if (!hasReleaseSigning && !allowDebugSigning &&
        allTasks.any { it.project == project && shippable.matches(it.name) }
    ) {
        throw GradleException(
            "A release artifact was requested but android/key.properties is " +
                "missing — it would be signed with the public Android debug " +
                "key. Provide the upload key (see android/key.properties.example), " +
                "or pass -PallowDebugSigning=true if this build is only ever " +
                "going to run on your own machine."
        )
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

dependencies {
    // Play-channel-only Google services. Every entry below MUST stay
    // `playImplementation`: the hard requirement is that the cn flavor's APK
    // physically contains no billing/ads classes. (GMS itself is *allowed* in
    // cn — 93% of the GMS classes in that APK are mobile_scanner's bundled
    // ML Kit barcode reader, used offline for the Steam login QR. Reading this
    // comment as "no GMS at all" is what produced a false regression report on
    // 2026-07-27; see CLAUDE.md 构建渠道.) The matching Kotlin
    // sources live in src/play/kotlin/ and are reached from src/main only via
    // one reflection probe in MainActivity.
    "playImplementation"("com.android.billingclient:billing-ktx:8.0.0")
    "playImplementation"("com.google.android.gms:play-services-ads:24.4.0")
    "playImplementation"("com.google.android.ump:user-messaging-platform:3.2.0")
    "playImplementation"("androidx.credentials:credentials:1.5.0")
    "playImplementation"("androidx.credentials:credentials-play-services-auth:1.5.0")
    "playImplementation"("com.google.android.libraries.identity.googleid:googleid:1.1.1")
}
