plugins {
    id("com.android.application")
}

// Who made this build, in Settings › Credits (as GALAXZ_BYLINE on iOS): -Pgalaxz.byline="by …"
val byline = (findProperty("galaxz.byline") as String?) ?: "by Luis Tosado"
val kit = rootProject.file("../Packages/GalaxzKit/Sources")

android {
    namespace = "org.galaxz.app"
    compileSdk = 36
    defaultConfig {
        applicationId = (findProperty("galaxz.id") as String?) ?: "org.galaxz.app"
        minSdk = 30
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
        ndk { abiFilters += "arm64-v8a" }
        resValue("string", "byline", byline)
    }
    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.getByName("debug")   // a test build to install by hand; not for a store
        }
    }
    sourceSets.getByName("main") {
        // the Swift library and libc++, put there by ../build.sh
        jniLibs.srcDir("build/jniLibs")
        // the shared package's own files, and the notices: the same files the iOS app carries
        assets.srcDir("build/galaxz-assets")
    }
    buildFeatures { resValues = true }
    packaging { jniLibs { useLegacyPackaging = true } }      // compressed: a smaller APK to send to a phone
}

val galaxzAssets by tasks.registering(Copy::class) {
    from("$kit/OPZModel/Resources/OPFree/engines.json", "$kit/OPZLink/Resources/OPFree/demo-session.json",
         rootProject.file("../LICENSE"), rootProject.file("../THIRD_PARTY.md"))
    into("build/galaxz-assets")
}
tasks.named("preBuild") { dependsOn(galaxzAssets) }
