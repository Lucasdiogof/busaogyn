import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Assinatura de release: android/key.properties (local, fora do git) ou
// variáveis BUSAOGYN_ANDROID_* (CI). Sem chave de upload, build release
// falha, a menos que BUSAOGYN_ALLOW_DEBUG_SIGNED_RELEASE=true peça um
// artefato de validação assinado com a chave de debug (não publicável).
val allowDebugSignedRelease = System.getenv("BUSAOGYN_ALLOW_DEBUG_SIGNED_RELEASE") == "true"
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
                when {
                    releaseSigning != null -> signingConfigs.getByName("release")
                    allowDebugSignedRelease -> signingConfigs.getByName("debug")
                    else -> null
                }
        }
    }
}

// Falha cedo e com mensagem clara em vez de gerar um release sem assinatura
// ou assinado por engano com a chave de debug.
gradle.taskGraph.whenReady {
    val releaseRequested =
        allTasks.any {
            it.project == project &&
                (it.name == "assembleRelease" || it.name == "bundleRelease")
        }
    if (releaseRequested && releaseSigning == null) {
        if (allowDebugSignedRelease) {
            logger.warn(
                "BusãoGyn: release de VALIDAÇÃO assinado com a chave de debug " +
                    "(BUSAOGYN_ALLOW_DEBUG_SIGNED_RELEASE=true). Não publicável.",
            )
        } else {
            throw GradleException(
                "Release sem chave de upload. Configure android/key.properties ou " +
                    "BUSAOGYN_ANDROID_* (docs/MOBILE_RELEASE.md). Para um build só de " +
                    "validação, defina BUSAOGYN_ALLOW_DEBUG_SIGNED_RELEASE=true.",
            )
        }
    }
}

flutter {
    source = "../.."
}
