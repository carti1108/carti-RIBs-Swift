rootProject.name = "todo-modular-android"

pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenCentral()
        google()
    }
}

dependencyResolutionManagement {
    repositories {
        mavenCentral()
        google()
    }
}

// µFeature 구조(ADR-0024). Swift 로직은 ../Shared, Android 화면 객체와 JNI는 swift/에 있다.
//   :bridge                Swift .so 빌드, swift-java 생성 Java 소스, 공용 Compose 도우미
//   :feature:<f>:ui        피처 Compose 화면. :bridge만 의존한다
//   :feature:<f>:demo      피처 하나만 띄우는 앱(iOS FeatureXxxExample)
//   :app                   모든 :ui를 잇는 앱
include(":bridge", ":app")
listOf("loggedout", "loggedin", "todolist", "tododetail").forEach { feature ->
    include(":feature:$feature:ui", ":feature:$feature:adapter", ":feature:$feature:demo")
}
