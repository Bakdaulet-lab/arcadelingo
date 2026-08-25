import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Релизный ключ. Хранилище и пароли живут вне репозитория (.gitignore держит
// и `android/key.properties`, и `*.jks`, и проверяет это тест
// `test/android/release_signing_test.dart`), поэтому сборочный скрипт читает
// их из файла, которого у свежего клона нет.
//
// `rootProject` здесь — каталог `android/`, а не корень репозитория: файл
// лежит там же, где его ищет шаблон Flutter и куда его кладёт docs/dev/release.md.
val keyPropertiesFile: File = rootProject.file("key.properties")

val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) {
        keyPropertiesFile.inputStream().use { load(it) }
    }
}

/** Путь из `key.properties`; относительный считается от каталога `android/`. */
fun keystoreFile(): File = rootProject.file(keyProperties.getProperty("storeFile"))

/**
 * Почему релизная подпись невозможна — человеческими словами, или `null`,
 * если всё на месте.
 *
 * Считается один раз при конфигурации и НЕ роняет сборку сам по себе: debug
 * собирается своим отладочным ключом и о `key.properties` знать не обязан.
 * Роняет только релиз — ниже, в `whenReady`.
 */
val releaseSigningProblem: String? = run {
    if (!keyPropertiesFile.exists()) {
        return@run "нет файла ${keyPropertiesFile.path}"
    }
    val missing = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
        .filter { keyProperties.getProperty(it).isNullOrBlank() }
    if (missing.isNotEmpty()) {
        return@run "в ${keyPropertiesFile.path} не заполнено: ${missing.joinToString(", ")}"
    }
    if (!keystoreFile().exists()) {
        return@run "storeFile указывает на ${keystoreFile().path}, а такого файла нет"
    }
    null
}

/**
 * Сообщение вместо гредловской каши.
 *
 * Без него отказ выглядит как «SigningConfig "release" is missing required
 * property "storeFile"» на сорок строк стека — верно по сути и бесполезно
 * тому, кто собирает релиз впервые.
 */
val releaseSigningHelp: String = """
    Релизная сборка не подписана: $releaseSigningProblem

    Релиз подписывается собственным ключом. Отладочный ключ у каждой машины
    свой и в магазин не принимается: ни первой публикацией, ни обновлением
    поверх уже установленной беты.

    Создай ключ по docs/dev/release.md — там команда keytool с разбором каждого
    параметра, куда положить хранилище и что записать в android/key.properties.
""".trimIndent()

// Падать надо до первой задачи релиза, а не после часа компиляции на
// упаковке. `whenReady` — самый ранний момент, когда уже известно, что именно
// собирают: конфигурация к этому времени прошла, а выполнение ещё не начато.
//
// Проверка по имени задачи, а не по запрошенной цели, потому что `gradlew
// build` собирает оба варианта, не называя ни одного из них.
gradle.taskGraph.whenReady {
    if (releaseSigningProblem != null && allTasks.any { it.name.endsWith("Release") }) {
        throw GradleException(releaseSigningHelp)
    }
}

android {
    namespace = "com.baks.arcadelingo"
    compileSdk = flutter.compileSdkVersion
    // Не flutter.ndkVersion (26.3.11579264): shared_preferences_android
    // требует 27.0.12077973, и сборка предупреждает об этом на каждом прогоне.
    // Версии NDK обратно совместимы, поэтому берётся наибольшая из требуемых.
    // Как только Flutter поднимет свою до 27+, строку надо убрать — пин,
    // переживший причину, однажды окажется ниже нужного.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // applicationId не менять никогда: после первой публикации он и есть
        // приложение в магазине. Сторожится test/brand/brand_assets_test.dart.
        applicationId = "com.baks.arcadelingo"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Оба числа приходят из `version:` в pubspec.yaml — docs/dev/release.md.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // Пустой конфиг при отсутствующем ключе — не небрежность: debug не
            // имеет права упасть из-за релизного ключа, а релиз до собственной
            // проверки AGP не доходит — его останавливает `whenReady` выше.
            if (releaseSigningProblem == null) {
                storeFile = keystoreFile()
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
        // debug не описан намеренно: у него отладочный ключ из ~/.android, и
        // `flutter run` обязан работать на машине, где ключа релиза нет вовсе.
    }
}

flutter {
    source = "../.."
}
