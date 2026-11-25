// swift-tools-version: 6.1
import PackageDescription

// TodoModular Android 앱에 넣을 Swift 라이브러리(libTodoModularBridge.so) 하나(ADR-0024).
// swift-java의 SwiftJava는 동적 라이브러리 전용이라 .so마다 Swift 런타임을 따로 넣을 수 없다(ADR-0021).
// 그래서 피처별 Android 화면 모듈은 SwiftPM 타깃으로만 나누고, 링크는 한 .so로 한다.
//   TodoAndroidSupport      화면 기반 클래스, 화면 등록부, 루트 화면
//   FeatureXxxAndroid       피처의 Android 화면(뷰 계약 구현)과 뷰 팩토리. 자기 Interface만 안다. (iOS의 FeatureXxxUI)
//   TodoModularAndroid      전체 앱과 피처별 단독 실행(demo) 조립. 호스트에서 테스트한다.
//   TodoModularBridge       swift-java가 Java 바인딩을 만드는 층과 손으로 쓴 JNI 진입점
// 빌드에 JAVA_HOME(JDK 21)과 `swift build --disable-sandbox`가 필요하다.

let ribs: Target.Dependency = .product(name: "RIBs", package: "RIBs")
let ribsAndroid: Target.Dependency = .product(name: "RIBsAndroid", package: "RIBs")
let features = ["LoggedOut", "LoggedIn", "TodoList", "TodoDetail"]

func shared(_ name: String) -> Target.Dependency { .product(name: name, package: "TodoModularShared") }

let featureTargets: [Target] = features.map { name in
    .target(
        name: "Feature\(name)Android",
        dependencies: [ribs, ribsAndroid, "TodoAndroidSupport", shared("TodoCore"), shared("Feature\(name)Interface")]
    )
}

let package = Package(
    name: "TodoModularAndroidSwift",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "TodoModularBridge", type: .dynamic, targets: ["TodoModularBridge"]),
    ],
    dependencies: [
        .package(name: "RIBs", path: "../../../.."),
        .package(name: "TodoModularShared", path: "../../Shared"),
        .package(url: "https://github.com/swiftlang/swift-java", exact: "0.7.0"),
    ],
    targets: [
        .target(name: "TodoAndroidSupport", dependencies: [ribs, ribsAndroid]),
        .target(
            name: "TodoModularAndroid",
            dependencies: [ribs, ribsAndroid, "TodoAndroidSupport", shared("TodoCore"), shared("TodoCoreTesting"), shared("TodoAppRoot")]
                + features.flatMap { name -> [Target.Dependency] in
                    [
                        .target(name: "Feature\(name)Android"),
                        shared("Feature\(name)Interface"), shared("Feature\(name)"), shared("Feature\(name)Testing"),
                    ]
                }
        ),
        .target(
            name: "TodoModularBridge",
            dependencies: [
                "TodoModularAndroid", "TodoAndroidSupport", ribsAndroid,
                .product(name: "SwiftJava", package: "swift-java"),
            ] + features.map { .target(name: "Feature\($0)Android") },
            exclude: ["swift-java.config"],
            plugins: [.plugin(name: "JExtractSwiftPlugin", package: "swift-java")]
        ),
        .testTarget(
            name: "TodoModularAndroidTests",
            dependencies: ["TodoModularAndroid", "TodoAndroidSupport", ribs, shared("TodoCore"), shared("TodoCoreTesting")]
                + features.map { .target(name: "Feature\($0)Android") }
        ),
    ] + featureTargets,
    swiftLanguageModes: [.v6]
)
