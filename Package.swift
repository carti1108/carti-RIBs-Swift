// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RIBs",
    // SwiftUI 어댑터가 Observation(@Observable)을 쓰므로 Apple 플랫폼 최소 버전을 둔다.
    // 다른 플랫폼(Linux, Wasm, Android)에는 영향이 없다.
    platforms: [.macOS(.v14), .iOS(.v17), .tvOS(.v17), .watchOS(.v10), .visionOS(.v1)],
    products: [
        .library(name: "RIBs", targets: ["RIBs"]),
        .library(name: "RIBsSwiftUI", targets: ["RIBsSwiftUI"]),
        .library(name: "RIBsUIKit", targets: ["RIBsUIKit"]),
        .library(name: "RIBsWeb", targets: ["RIBsWeb"]),
        .library(name: "RIBsAndroid", targets: ["RIBsAndroid"]),
        .library(name: "LoginShared", targets: ["LoginShared"]),
        .plugin(name: "NewRib", targets: ["NewRib"]),
    ],
    dependencies: [
        // 문서 생성(`swift package generate-documentation`)에만 쓰는 명령 플러그인이다.
        // 라이브러리 타깃은 이 패키지에 의존하지 않으므로 빌드 산출물(Wasm·Android 포함)에 들어가지 않는다(ADR-0012).
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
    ],
    targets: [
        .target(name: "RIBs"),
        .target(name: "RIBsSwiftUI", dependencies: ["RIBs"]),
        .target(name: "RIBsUIKit", dependencies: ["RIBs"]),
        .target(name: "RIBsWeb", dependencies: ["RIBs"]),
        // Android 어댑터(ADR-0010). C 타깃은 libdispatch 메인 큐를 ALooper에 붙인다.
        .target(
            name: "CRIBsAndroid",
            linkerSettings: [
                .linkedLibrary("android", .when(platforms: [.android])),
                // 메인 큐 SPI를 직접 부르므로 libdispatch를 명시한다(--static-swift-stdlib에서도 묶이도록).
                .linkedLibrary("dispatch", .when(platforms: [.android])),
                .linkedLibrary("BlocksRuntime", .when(platforms: [.android])),
            ]
        ),
        .target(name: "RIBsAndroid", dependencies: ["RIBs", "CRIBsAndroid"]),
        .target(name: "LoginShared", dependencies: ["RIBs"], path: "Samples/LoginShared/Sources"),
        .plugin(
            name: "NewRib",
            capability: .command(
                intent: .custom(verb: "new-rib", description: "RIB 뼈대를 만든다. 한 모듈 안의 RIB(--name) 또는 µFeature 피처(--feature)."),
                permissions: [.writeToPackageDirectory(reason: "새 RIB 소스 파일을 만든다.")]
            )
        ),
        .testTarget(name: "RIBsTests", dependencies: ["RIBs"]),
        .testTarget(name: "RIBsSwiftUITests", dependencies: ["RIBsSwiftUI"]),
        .testTarget(name: "RIBsUIKitTests", dependencies: ["RIBsUIKit"]),
        .testTarget(name: "RIBsWebTests", dependencies: ["RIBsWeb"]),
        .testTarget(name: "RIBsAndroidTests", dependencies: ["RIBsAndroid"]),
        // new-rib이 만든 뼈대를 임시 패키지에서 실제로 빌드·테스트한다.
        .testTarget(name: "NewRibTests"),
        .testTarget(name: "LoginSharedTests", dependencies: ["LoginShared"], path: "Samples/LoginShared/Tests"),
    ],
    swiftLanguageModes: [.v6]
)
