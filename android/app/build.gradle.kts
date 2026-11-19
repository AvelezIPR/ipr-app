import groovy.json.JsonSlurper

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/**
 * Configuración PÚBLICA por flavor: una sola fuente de verdad, `config/<flavor>.json`
 * (ADR-009). El host de los App Links sale de `deepLinkHost`; así el manifiesto y la
 * app no pueden divergir. Nunca contiene secretos (SC-038).
 */
fun flavorConfig(flavor: String): Map<*, *> =
    JsonSlurper().parse(rootProject.file("../config/$flavor.json")) as Map<*, *>

android {
    // El código vive en este paquete; el applicationId definitivo (co.ipr.app) está
    // PENDIENTE de confirmar con la titularidad de las cuentas de tienda (D-14).
    namespace = "co.ipr.ipr_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "co.ipr.app"
        // Mínimos reales PENDIENTES de SPK-02 / DN-01: se hereda lo que fija Flutter.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // AGP 9 desactiva `resValue` por defecto; el nombre de la app por flavor lo usa.
    buildFeatures {
        resValues = true
    }

    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "IPR Dev")
            manifestPlaceholders["deepLinkHost"] = flavorConfig("dev")["deepLinkHost"] as String
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".staging"
            resValue("string", "app_name", "IPR Staging")
            manifestPlaceholders["deepLinkHost"] = flavorConfig("staging")["deepLinkHost"] as String
        }
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "IPR Partes y Repuestos")
            manifestPlaceholders["deepLinkHost"] = flavorConfig("prod")["deepLinkHost"] as String
        }
    }

    buildTypes {
        release {
            // Release endurecido (SC-019): R8 activo, recursos reducidos, no depurable.
            isMinifyEnabled = true
            isShrinkResources = true
            isDebuggable = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // SIN firma en el repositorio: la firma ocurre solo en el flujo de release
            // desde CI con secretos del entorno (docs/09_devops/ci_cd.md §6.2). Por eso
            // `flutter run --release` no firma; usar `--debug` o `--profile` en local.
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
