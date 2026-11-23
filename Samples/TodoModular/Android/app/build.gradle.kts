plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

// 모든 피처 UI 모듈을 잇는 앱. Swift 쪽은 TodoAppController(TodoAppRoot)가 맡는다.
android {
    namespace = "com.carti.ribs.samples.todomodular"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.carti.ribs.samples.todomodular"
        minSdk = 28
        targetSdk = 37
        versionCode = 1
        versionName = "0.1"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildFeatures { compose = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    listOf("loggedout", "loggedin", "todolist", "tododetail").forEach { implementation(project(":feature:$it:ui")) }

    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.test.junit)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.androidx.test.espresso)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
}
