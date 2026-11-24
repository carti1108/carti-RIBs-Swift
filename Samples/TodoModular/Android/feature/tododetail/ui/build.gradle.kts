plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.compose)
}

// 순수 뷰 모듈(ADR-0027). Compose에만 의존한다. `:bridge`(Swift 라이브러리와 생성된 바인딩)에 의존하지 않는다.
android {
    namespace = "com.carti.ribs.samples.todomodular.feature.tododetail.ui"
    compileSdk = 37
    defaultConfig {
        minSdk = 28
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    buildFeatures { compose = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    api(platform(libs.androidx.compose.bom))
    api(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.ui.tooling.preview)
    debugImplementation(libs.androidx.compose.ui.tooling) // Android Studio 미리보기

    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.test.junit)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.androidx.test.espresso) // ui-test가 끌어오는 옛 Espresso는 API 37에서 실패한다
    debugImplementation(libs.androidx.compose.ui.test.manifest)
}
