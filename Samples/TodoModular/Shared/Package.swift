// swift-tools-version: 6.0
import PackageDescription

// µFeature 샘플의 공유 패키지(ADR-0024). 피처마다 Interface·Impl·Testing·Tests 4개 타깃을 둔다.
// Impl은 자기 Interface, 자식 Interface, TodoCore만 의존한다. 실제 Impl을 잇는 곳은 TodoAppRoot 하나다.
// 경계 검사: scripts/check-sample-boundaries.sh (ADR-0028). SwiftPM의 --explicit-target-dependency-import-check는
// macOS 호스트 빌드에서만 Impl 간 import를 잡는다(Windows와 Wasm 빌드에서는 잡지 못한다).

let ribs: Target.Dependency = .product(name: "RIBs", package: "RIBs")

/// 피처 하나의 타깃 4개. `interfaces`는 이 피처가 아는 다른 피처의 Interface 이름(예: "TodoList")이다.
func feature(_ name: String, interfaces: [String] = []) -> [Target] {
    let path = "Features/\(name)"
    let interface = "Feature\(name)Interface"
    let otherInterfaces = interfaces.map { Target.Dependency.target(name: "Feature\($0)Interface") }
    let otherTestings = interfaces.map { Target.Dependency.target(name: "Feature\($0)Testing") }
    return [
        .target(name: interface, dependencies: [ribs, "TodoCore"] + otherInterfaces, path: "\(path)/Interface"),
        .target(
            name: "Feature\(name)",
            dependencies: [ribs, "TodoCore", .target(name: interface)] + otherInterfaces,
            path: "\(path)/Sources"
        ),
        .target(
            name: "Feature\(name)Testing",
            dependencies: [ribs, "TodoCore", "TodoCoreTesting", .target(name: interface)] + otherInterfaces,
            path: "\(path)/Testing"
        ),
        .testTarget(
            name: "Feature\(name)Tests",
            dependencies: [
                ribs, "TodoCore", "TodoCoreTesting",
                .target(name: interface), .target(name: "Feature\(name)"), .target(name: "Feature\(name)Testing"),
            ] + otherInterfaces + otherTestings,
            path: "\(path)/Tests"
        ),
    ]
}

let features = ["LoggedOut", "LoggedIn", "TodoList", "TodoDetail"]
let featureTargets =
    feature("LoggedOut")
    + feature("LoggedIn", interfaces: ["TodoList", "TodoDetail"])
    + feature("TodoList")
    + feature("TodoDetail")

/// 플랫폼(Tuist 등)이 모듈별로 받을 수 있도록 테스트가 아닌 타깃마다 제품을 둔다.
let libraryNames = ["TodoCore", "TodoCoreTesting", "TodoAppRoot"]
    + features.flatMap { ["Feature\($0)Interface", "Feature\($0)", "Feature\($0)Testing"] }

let package = Package(
    name: "TodoModularShared",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: libraryNames.map { .library(name: $0, targets: [$0]) },
    dependencies: [
        .package(name: "RIBs", path: "../../.."),
    ],
    targets: [
        .target(name: "TodoCore", dependencies: [ribs], path: "Core/Sources"),
        .target(name: "TodoCoreTesting", dependencies: [ribs, "TodoCore"], path: "Core/Testing"),
        .testTarget(name: "TodoCoreTests", dependencies: ["TodoCore", "TodoCoreTesting"], path: "Core/Tests"),
        .target(
            name: "TodoAppRoot",
            dependencies: [ribs, "TodoCore"] + features.flatMap {
                [Target.Dependency.target(name: "Feature\($0)Interface"), .target(name: "Feature\($0)")]
            },
            path: "App/Sources"
        ),
        .testTarget(
            name: "TodoAppRootTests",
            dependencies: [ribs, "TodoCore", "TodoCoreTesting", "TodoAppRoot"] + features.flatMap {
                [Target.Dependency.target(name: "Feature\($0)Interface"), .target(name: "Feature\($0)Testing")]
            },
            path: "App/Tests"
        ),
    ] + featureTargets,
    swiftLanguageModes: [.v6]
)
