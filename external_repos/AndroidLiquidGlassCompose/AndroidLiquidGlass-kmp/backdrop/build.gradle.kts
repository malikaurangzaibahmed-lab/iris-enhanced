plugins {
    id("com.android.library")
    kotlin("multiplatform")
    id("org.jetbrains.compose")
}

kotlin {
    androidTarget {
        compilations.all {
            kotlinOptions {
                jvmTarget = "11"
                freeCompilerArgs += "-Xcontext-receivers"
            }
        }
    }

    jvm("desktop")

    js {
        browser()
    }

    macosArm64()
    iosArm64()
    iosSimulatorArm64()

    sourceSets {
        val commonMain by getting {
            dependencies {
                implementation(compose.foundation)
                implementation(compose.ui)
            }
        }
        val skikoMain by creating {
            dependsOn(commonMain)
        }
        val desktopMain by getting { dependsOn(skikoMain) }
        val macosArm64Main by getting { dependsOn(skikoMain) }
        val iosMain by creating { dependsOn(skikoMain) }
        val iosArm64Main by getting { dependsOn(iosMain) }
        val iosSimulatorArm64Main by getting { dependsOn(iosMain) }
        val jsMain by getting { dependsOn(skikoMain) }
        // wasmJsMain removed
    }
}

android {
    namespace = "com.kyant.backdrop"
    compileSdk = 34
    defaultConfig {
        minSdk = 24
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
}
