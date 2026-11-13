plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

// Swift 라이브러리 빌드 설정(ADR-0010). 기본값은 swift.org 6.4.2 툴체인과 같은 버전의 Swift SDK for Android다.
// 환경 변수로 바꿀 수 있다: SWIFT_EXEC(swift 실행 파일), SWIFT_ANDROID_API(트리플의 API 수준).
val swiftExecutable: String = System.getenv("SWIFT_EXEC")
    ?: "${System.getProperty("user.home")}/Library/Developer/Toolchains/swift-6.4.2-RELEASE.xctoolchain/usr/bin/swift"
        .takeIf { file(it).exists() }
    ?: "swift"
// Swift SDK for Android는 ANDROID_NDK_HOME의 NDK(r30)를 쓴다. 없으면 흔한 설치 위치를 본다.
val androidNdkHome: String = System.getenv("ANDROID_NDK_HOME")
    ?: "${System.getProperty("user.home")}/Library/Android/android-ndk-r30".takeIf { file(it).exists() }
    ?: throw GradleException("Set ANDROID_NDK_HOME to an Android NDK r30 install.")
val swiftAndroidApi: Int = System.getenv("SWIFT_ANDROID_API")?.toInt() ?: 28
val swiftSdkBundle = "swift-6.4.2-RELEASE_android.artifactbundle"
val swiftPackageDir = file("src/main/swift")
val swiftJniLibsDir = layout.buildDirectory.dir("swiftJniLibs")

/** Android ABI → Swift 트리플 아키텍처, NDK 트리플. Apple Silicon 에뮬레이터는 arm64-v8a다. */
val swiftAbis = mapOf(
    "arm64-v8a" to ("aarch64" to "aarch64-linux-android"),
    "x86_64" to ("x86_64" to "x86_64-linux-android"),
)
val requestedAbis: List<String> =
    (findProperty("swiftAbis") as String?)?.split(",")?.map(String::trim) ?: listOf("arm64-v8a")

android {
    namespace = "com.carti.ribs.samples.swiftandroid"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.carti.ribs.samples.swiftandroid"
        minSdk = swiftAndroidApi
        targetSdk = 37
        versionCode = 1
        versionName = "0.1"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        ndk { abiFilters += requestedAbis }
    }

    buildFeatures {
        compose = true
    }

    sourceSets["main"].jniLibs.directories.add(swiftJniLibsDir.get().asFile.path)
}

fun swiftSdkRoot(): File {
    val home = System.getProperty("user.home")
    return listOf("$home/Library/org.swift.swiftpm/swift-sdks", "$home/.swiftpm/swift-sdks", "$home/.config/swiftpm/swift-sdks")
        .map { file("$it/$swiftSdkBundle") }
        .firstOrNull { it.exists() }
        ?: throw GradleException("Swift SDK for Android not found: $swiftSdkBundle. Run `swift sdk install` first.")
}

val swiftLibTasks = requestedAbis.map { abi ->
    val (swiftArch, ndkTriple) = swiftAbis[abi] ?: throw GradleException("Unsupported ABI: $abi")
    val triple = "$swiftArch-unknown-linux-android$swiftAndroidApi"
    val variantName = abi.replace("-", "").replaceFirstChar(Char::uppercaseChar)
    val buildArgs = listOf("build", "--swift-sdk", triple, "--static-swift-stdlib", "-c", "release")

    val build = tasks.register<Exec>("swiftBuild$variantName") {
        workingDir(swiftPackageDir)
        environment("ANDROID_NDK_HOME", androidNdkHome)
        commandLine(listOf(swiftExecutable) + buildArgs)
        inputs.dir(swiftPackageDir.resolve("Sources"))
        inputs.dir(rootDir.resolve("../../Sources"))
        inputs.dir(rootDir.resolve("../LoginShared/Sources"))
        outputs.upToDateWhen { false } // SwiftPM이 증분 빌드를 맡는다.
    }

    tasks.register<Copy>("swiftCopy$variantName") {
        dependsOn(build)
        // --static-swift-stdlib라 Swift 런타임은 libAndroidLogin.so 안에 들어간다. libc++_shared.so만 함께 넣는다.
        from(provider { swiftSdkRoot().resolve("swift-android/ndk-sysroot/usr/lib/$ndkTriple") }) {
            include("libc++_shared.so")
        }
        from(provider {
            val output = providers.exec {
                workingDir(swiftPackageDir)
                environment("ANDROID_NDK_HOME", androidNdkHome)
                commandLine(listOf(swiftExecutable) + buildArgs + "--show-bin-path")
            }.standardOutput.asText.get().trim().lines().last()
            file(output)
        }) {
            include("libAndroidLogin.so")
        }
        into(swiftJniLibsDir.map { it.dir(abi) })
    }
}

tasks.named("preBuild") { dependsOn(swiftLibTasks) }

dependencies {
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)

    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.test.junit)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.androidx.test.espresso)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
}
