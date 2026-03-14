// android/app/build.gradle — La Italiana
// Copia este archivo a: android/app/build.gradle

plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
    id "com.google.gms.google-services"
}

// ── Leer key.properties ────────────────────────────────────────────────────
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    namespace "com.laitaliana.pizzeria"
    compileSdk 35
    ndkVersion flutter.ndkVersion

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = '17'
    }

    sourceSets {
        main.java.srcDirs += 'src/main/kotlin'
    }

    defaultConfig {
        applicationId "com.laitaliana.pizzeria"
        minSdk 21
        targetSdk 35
        versionCode 1
        versionName "1.0.0"
        multiDexEnabled true
    }

    // ── Firma de release ───────────────────────────────────────────────────
    signingConfigs {
        release {
            keyAlias     keystoreProperties['keyAlias']     ?: 'la-italiana'
            keyPassword  keystoreProperties['keyPassword']  ?: ''
            storeFile    keystoreProperties['storeFile']
                ? file(keystoreProperties['storeFile'])
                : file('la-italiana-keystore.jks')
            storePassword keystoreProperties['storePassword'] ?: ''
        }
    }

    buildTypes {
        debug {
            // debug no firma — sirve para probar en el cel directamente
            applicationIdSuffix ".debug"
            versionNameSuffix "-debug"
        }
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'),
                          'proguard-rules.pro'
        }
    }
}

flutter {
    source '../..'
}

dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk8:$kotlin_version"
    implementation platform('com.google.firebase:firebase-bom:33.0.0')
    implementation 'androidx.multidex:multidex:2.0.1'
}