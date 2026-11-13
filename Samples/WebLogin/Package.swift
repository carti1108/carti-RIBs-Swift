// swift-tools-version: 6.0
import PackageDescription

// Wasm 전용 샘플 패키지. JavaScriptKit 의존을 루트 패키지에 넣지 않으려고 따로 둔다(ADR-0009).
// 빌드: swift package --swift-sdk <wasm SDK> js (README 참고)
let package = Package(
    name: "WebLogin",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(name: "RIBs", path: "../.."),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", exact: "0.63.0"),
    ],
    targets: [
        .executableTarget(
            name: "WebLogin",
            dependencies: [
                .product(name: "RIBsWeb", package: "RIBs"),
                .product(name: "LoginShared", package: "RIBs"),
                .product(name: "JavaScriptKit", package: "JavaScriptKit"),
                .product(name: "JavaScriptEventLoop", package: "JavaScriptKit"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
