// swift-tools-version: 6.0
import PackageDescription

// TodoModular 웹 앱(Wasm) 패키지(ADR-0024). JavaScriptKit 의존을 루트·공유 패키지에 넣지 않으려고 따로 둔다.
//   TodoWebSupport     DOM 화면 기반 클래스, 루트 화면, 자리표시 화면
//   FeatureXxxWeb      피처의 웹 화면(뷰 계약 구현)과 뷰 팩토리. 자기 Interface만 안다. (iOS의 FeatureXxxUI)
//   TodoModularWeb     BridgeJS가 JS로 내보내는 층, 전체 앱과 피처별 데모 조립
// `@JS` 선언은 TodoModularWeb 한 타깃에만 둔다. Android가 swift-java 층을 TodoModularBridge 하나에 두는 것과 같다.
// 빌드: swift package --swift-sdk <wasm SDK> js (README 참고)

let ribs: Target.Dependency = .product(name: "RIBs", package: "RIBs")
let ribsWeb: Target.Dependency = .product(name: "RIBsWeb", package: "RIBs")
let javaScriptKit: Target.Dependency = .product(name: "JavaScriptKit", package: "JavaScriptKit")
let features = ["LoggedOut", "LoggedIn", "TodoList", "TodoDetail"]

func shared(_ name: String) -> Target.Dependency { .product(name: name, package: "TodoModularShared") }

let featureTargets: [Target] = features.map { name in
    .target(
        name: "Feature\(name)Web",
        dependencies: [ribs, ribsWeb, javaScriptKit, "TodoWebSupport", shared("TodoCore"), shared("Feature\(name)Interface")]
    )
}

let package = Package(
    name: "TodoModularWeb",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(name: "RIBs", path: "../../.."),
        .package(name: "TodoModularShared", path: "../Shared"),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", exact: "0.63.0"),
    ],
    targets: [
        .target(name: "TodoWebSupport", dependencies: [ribs, ribsWeb, javaScriptKit]),
        .executableTarget(
            name: "TodoModularWeb",
            dependencies: [
                ribs, ribsWeb, javaScriptKit, "TodoWebSupport",
                .product(name: "JavaScriptEventLoop", package: "JavaScriptKit"),
                shared("TodoCore"), shared("TodoCoreTesting"), shared("TodoData"), shared("TodoAppRoot"),
            ] + features.flatMap { name -> [Target.Dependency] in
                [
                    .target(name: "Feature\(name)Web"),
                    shared("Feature\(name)Interface"), shared("Feature\(name)"), shared("Feature\(name)Testing"),
                ]
            },
            swiftSettings: [.enableExperimentalFeature("Extern")],
            plugins: [.plugin(name: "BridgeJS", package: "JavaScriptKit")]
        ),
    ] + featureTargets,
    swiftLanguageModes: [.v6]
)
