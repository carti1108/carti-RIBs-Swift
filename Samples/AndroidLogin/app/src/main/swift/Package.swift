// swift-tools-version: 6.0
import PackageDescription

// Android 앱에 넣을 Swift 라이브러리(libAndroidLogin.so). Gradle이 Swift SDK for Android로 빌드한다(ADR-0010).
// AndroidLoginUI는 JNI 없이 호스트(macOS/Linux)에서도 빌드·테스트된다.
let package = Package(
    name: "AndroidLoginSwift",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AndroidLogin", type: .dynamic, targets: ["AndroidLogin"]),
    ],
    dependencies: [
        .package(name: "RIBs", path: "../../../../../.."),
    ],
    targets: [
        .target(
            name: "AndroidLoginUI",
            dependencies: [
                .product(name: "RIBs", package: "RIBs"),
                .product(name: "RIBsAndroid", package: "RIBs"),
                .product(name: "LoginShared", package: "RIBs"),
            ]
        ),
        .target(name: "AndroidLogin", dependencies: ["AndroidLoginUI"]),
        .testTarget(name: "AndroidLoginUITests", dependencies: ["AndroidLoginUI"]),
    ],
    swiftLanguageModes: [.v6]
)
