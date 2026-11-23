plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.compose)
}

// 피처 Compose 화면. Swift 짝은 swift/Sources/Feature*Android와 TodoModularBridge의 핸들이다. 다른 피처 UI를 모른다.
android {
    namespace = "com.carti.ribs.samples.todomodular.feature.tododetail.ui"
    compileSdk = 37
    defaultConfig { minSdk = 28 }
    buildFeatures { compose = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    api(project(":bridge"))
}
