import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Assinatura de release: android/key.properties (local, fora do git) ou
// variáveis de ambiente (CI). Sem nenhuma das duas, o release é assinado
// com a chave de debug, o que serve para testes mas não para a Play Store.
val releaseSigning: Map<String, String>? =
    run {
        val keys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
        val file = rootProject.file("key.properties")
        val values =
            if (file.exists()) {
                val properties = Properties()
                file.inputStream().use { properties.load(it) }
                keys.associateWith { properties.getProperty(it).orEmpty() }
            } else {
                mapOf(
                    "storeFile" to System.getenv("BUSAOGYN_ANDROID_KEYSTORE_PATH").orEmpty(),
                    "storePassword" to System.getenv("BUSAOGYN_ANDROID_KEYSTORE_PASSWORD").orEmpty(),
                    "keyAlias" to System.getenv("BUSAOGYN_ANDROID_KEY_ALIAS").orEmpty(),
                    "keyPassword" to System.getenv("BUSAOGYN_ANDROID_KEY_PASSWORD").orEmpty(),
                )
            }
        when {
            values.values.all { it.isBlank() } -> null
            values.values.any { it.isBlank() } ->
                throw GradleException(
                    "Assinatura de release incompleta: informe storeFile, storePassword, " +
                        "keyAlias e keyPassword (key.properties ou BUSAOGYN_ANDROID_*).",
                )
            else -> values
        }
    }

android {
    namespace = "com.lucksrei.busaogyn"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.lucksrei.busaogyn"
        // minSdk 24, targetSdk 36 e compileSdk 36 no Flutter 3.38.5; versionName
        // e versionCode vêm de `version` no pubspec.yaml.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        releaseSigning?.let { signing ->
            create("release") {
                storeFile = rootProject.file(signing.getValue("storeFile"))
                storePassword = signing.getValue("storePassword")
                keyAlias = signing.getValue("keyAlias")
                keyPassword = signing.getValue("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (releaseSigning != null) {
                    signingConfigs.getByName("release")
                } else {
                    logger.warn(
                        "BusãoGyn: sem chave de upload configurada; o release será " +
                            "assinado com a chave de debug (não aceito pela Play Store).",
                    )
                    signingConfigs.getByName("debug")
                }
        }
    }
}

flutter {
    source = "../.."
}
