plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

// Swift 라이브러리 빌드 설정(ADR-0010). 기본값은 swift.org 6.4.2 툴체인과 같은 버전의 Swift SDK for Android다.
// 환경 변수로 바꿀 수 있다: SWIFT_CLI(swift 실행 파일), SWIFT_ANDROID_API(트리플의 API 수준).
// SWIFT_EXEC는 쓰지 않는다. SwiftPM이 그 이름을 swiftc 경로로 읽어서, swift를 넣으면 manifest 컴파일이 깨진다.
val swiftExecutable: String = System.getenv("SWIFT_CLI")
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

// swift-java(JNI 모드)가 `swift build` 중에 만드는 것들. Java 바인딩 소스와, 그 소스가 기대는 swiftkit-core jar다.
val swiftJavaGeneratedDir =
    swiftPackageDir.resolve(".build/plugins/outputs/swift/AndroidLogin/destination/JExtractSwiftPlugin/src/generated/java")
val swiftKitCoreJar = swiftPackageDir.resolve(".build/checkouts/swift-java/SwiftKitCore/build/libs/swiftkit-core-0.7.0.jar")
// swift-java 플러그인은 JAVA_HOME의 JDK로 Gradle을 돌리고, PATH의 `swift`로 빌드 설정을 읽는다.
// /usr/bin/swift(xcrun)가 먼저 잡히면 swift.org 툴체인에서 실패하므로 고른 툴체인의 bin을 PATH 앞에 둔다.
val swiftJavaHome: String = System.getenv("JAVA_HOME") ?: System.getProperty("java.home")
val swiftToolchainPath: String =
    listOfNotNull(file(swiftExecutable).parentFile?.takeIf { it.isAbsolute }?.path, System.getenv("PATH"))
        .joinToString(File.pathSeparator)

/** Android ABI → Swift 트리플 아키텍처, NDK 트리플. Apple Silicon 에뮬레이터는 arm64-v8a다. */
val swiftAbis = mapOf(
    "arm64-v8a" to ("aarch64" to "aarch64-linux-android"),
    "x86_64" to ("x86_64" to "x86_64-linux-android"),
)
// swift-java의 SwiftJava는 동적 라이브러리 전용이다. `--static-swift-stdlib`로 묶으면 .so마다 런타임이 따로 들어가고
// libSwiftJava.so가 libdispatch 심볼을 찾지 못해 로드되지 않는다. 그래서 Swift 런타임을 SDK의 .so로 함께 넣는다.
// 목록은 libAndroidLogin.so와 libSwiftJava.so의 NEEDED를 따라간 결과다.
val swiftRuntimeLibs = listOf(
    "libswiftCore.so", "libswift_Concurrency.so", "libswift_StringProcessing.so", "libswift_RegexParser.so",
    "libswift_Builtin_float.so", "libswift_math.so", "libswiftAndroid.so", "libswiftObservation.so",
    "libswiftSynchronization.so", "libdispatch.so", "libBlocksRuntime.so", "libFoundationEssentials.so",
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

    // swift-java가 만든 Java 소스는 Java 17 문법(instanceof 패턴)을 쓴다.
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets["main"].jniLibs.directories.add(swiftJniLibsDir.get().asFile.path)
    sourceSets["main"].java.directories.add(swiftJavaGeneratedDir.path)
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
    val buildArgs = listOf("build", "--disable-sandbox", "--swift-sdk", triple, "-c", "release")

    val build = tasks.register<Exec>("swiftBuild$variantName") {
        workingDir(swiftPackageDir)
        environment("ANDROID_NDK_HOME", androidNdkHome)
        environment("JAVA_HOME", swiftJavaHome)
        environment("PATH", swiftToolchainPath)
        commandLine(listOf(swiftExecutable) + buildArgs)
        inputs.dir(swiftPackageDir.resolve("Sources"))
        inputs.dir(rootDir.resolve("../../Sources"))
        inputs.dir(rootDir.resolve("../LoginShared/Sources"))
        outputs.upToDateWhen { false } // SwiftPM이 증분 빌드를 맡는다.
    }

    tasks.register<Copy>("swiftCopy$variantName") {
        dependsOn(build)
        from(provider { swiftSdkRoot().resolve("swift-android/ndk-sysroot/usr/lib/$ndkTriple") }) {
            include("libc++_shared.so")
        }
        from(provider { swiftSdkRoot().resolve("swift-android/swift-resources/usr/lib/swift-$swiftArch/android") }) {
            include(swiftRuntimeLibs)
        }
        from(provider {
            val output = providers.exec {
                workingDir(swiftPackageDir)
                environment("ANDROID_NDK_HOME", androidNdkHome)
                environment("JAVA_HOME", swiftJavaHome)
                environment("PATH", swiftToolchainPath)
        environment("JAVA_HOME", swiftJavaHome)
        environment("PATH", swiftToolchainPath)
                commandLine(listOf(swiftExecutable) + buildArgs + "--show-bin-path")
            }.standardOutput.asText.get().trim().lines().last()
            file(output)
        }) {
            include("libAndroidLogin.so", "libSwiftJava.so")
        }
        into(swiftJniLibsDir.map { it.dir(abi) })
    }
}

tasks.named("preBuild") { dependsOn(swiftLibTasks) }

dependencies {
    // `swiftBuild*` 작업이 만든다. preBuild가 그 작업에 의존하므로 컴파일 시점에는 있다.
    implementation(files(swiftKitCoreJar))
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.ui.tooling.preview)
    debugImplementation(libs.androidx.compose.ui.tooling) // Android Studio 미리보기
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)

    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.test.junit)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.androidx.test.espresso)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
}
