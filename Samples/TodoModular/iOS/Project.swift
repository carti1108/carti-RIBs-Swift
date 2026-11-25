import ProjectDescription

// µFeature iOS 앱(ADR-0024). 생성: Samples/TodoModular/iOS에서 `tuist generate --no-open`.
// 피처 로직은 공유 SwiftPM 패키지(../Shared)에 있고, 여기에는 플랫폼 쪽 타깃만 둔다.
//   FeatureXxxUI       SwiftUI 화면(뷰 계약 구현)과 `XxxScreenFactory`. 자기 Interface만 안다.
//   FeatureXxxExample  피처 하나만 띄우는 앱. 부모·자식은 Testing 모듈의 가짜나 자리표시 화면으로 채운다.
//   TodoModular        `TodoAppRoot`와 모든 UI 모듈을 잇는 앱.

let deploymentTargets: DeploymentTargets = .iOS("17.0")
let swiftSettings: Settings = .settings(base: ["SWIFT_VERSION": "6.0"])
let bundlePrefix = "com.carti.ribs.swift.samples.todomodular"
let features = ["LoggedOut", "LoggedIn", "TodoList", "TodoDetail"]

func uiTarget(_ name: String) -> Target {
    .target(
        name: "Feature\(name)UI",
        destinations: .iOS,
        product: .staticFramework,
        bundleId: "\(bundlePrefix).feature.\(name.lowercased()).ui",
        deploymentTargets: deploymentTargets,
        sources: ["Features/\(name)/UI/**"],
        dependencies: [
            .package(product: "RIBs"),
            .package(product: "RIBsSwiftUI"),
            .package(product: "TodoCore"),
            .package(product: "Feature\(name)Interface"),
        ],
        settings: swiftSettings
    )
}

/// `childInterfaces`: 자리표시 자식을 만들 때 필요한 자식 피처 Interface.
func exampleTarget(_ name: String, childInterfaces: [String] = []) -> Target {
    .target(
        name: "Feature\(name)Example",
        destinations: .iOS,
        product: .app,
        bundleId: "\(bundlePrefix).feature.\(name.lowercased()).example",
        deploymentTargets: deploymentTargets,
        infoPlist: .extendingDefault(with: ["UILaunchScreen": [:]]),
        sources: ["Features/\(name)/Example/**"],
        dependencies: [
            .target(name: "Feature\(name)UI"),
            .package(product: "RIBs"),
            .package(product: "RIBsSwiftUI"),
            .package(product: "TodoCore"),
            .package(product: "TodoCoreTesting"),
            .package(product: "Feature\(name)Interface"),
            .package(product: "Feature\(name)"),
            .package(product: "Feature\(name)Testing"),
        ] + childInterfaces.map { .package(product: "Feature\($0)Interface") },
        settings: swiftSettings
    )
}

let project = Project(
    name: "TodoModular",
    packages: [
        .local(path: "../../.."),
        .local(path: "../Shared"),
    ],
    targets: features.map(uiTarget) + [
        exampleTarget("LoggedOut"),
        exampleTarget("LoggedIn", childInterfaces: ["TodoList", "TodoDetail"]),
        exampleTarget("TodoList"),
        exampleTarget("TodoDetail"),
    ] + [
        .target(
            name: "TodoModular",
            destinations: .iOS,
            product: .app,
            bundleId: bundlePrefix,
            deploymentTargets: deploymentTargets,
            infoPlist: .extendingDefault(with: ["UILaunchScreen": [:]]),
            sources: ["App/Sources/**"],
            dependencies: features.map { .target(name: "Feature\($0)UI") } + [
                .package(product: "RIBs"),
                .package(product: "RIBsSwiftUI"),
                .package(product: "TodoCore"),
                .package(product: "TodoAppRoot"),
            ] + features.map { .package(product: "Feature\($0)Interface") },
            settings: swiftSettings
        ),
        .target(
            name: "TodoModularUITests",
            destinations: .iOS,
            product: .uiTests,
            bundleId: "\(bundlePrefix).uitests",
            deploymentTargets: deploymentTargets,
            sources: ["App/UITests/**"],
            dependencies: [.target(name: "TodoModular")]
        ),
    ]
)
