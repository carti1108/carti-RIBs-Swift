plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

// 피처 하나만 띄우는 앱(iOS FeatureXxxExample과 같은 역할). Swift 쪽은 FeatureDemoController가 맡는다.
android {
    namespace = "com.carti.ribs.samples.todomodular.feature.loggedout.demo"
    compileSdk = 37
    defaultConfig {
        applicationId = "com.carti.ribs.samples.todomodular.feature.loggedout.demo"
        minSdk = 28
        targetSdk = 37
        versionCode = 1
        versionName = "0.1"
    }
    buildFeatures { compose = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    implementation(project(":feature:loggedout:ui"))
}
