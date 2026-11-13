import ProjectDescription

// 생성: Samples/iOSLogin에서 `tuist generate --no-open`. 루트 SwiftPM 패키지를 로컬 의존성으로 쓴다.
let project = Project(
    name: "LoginSample",
    packages: [
        .local(path: "../.."),
    ],
    targets: [
        .target(
            name: "LoginSample",
            destinations: .iOS,
            product: .app,
            bundleId: "com.carti.ribs.swift.samples.login",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: ["UILaunchScreen": [:]]),
            sources: ["Sources/**"],
            dependencies: [
                .package(product: "RIBs"),
                .package(product: "RIBsSwiftUI"),
                .package(product: "LoginShared"),
            ],
            settings: .settings(base: ["SWIFT_VERSION": "6.0"])
        ),
        .target(
            name: "LoginSampleUITests",
            destinations: .iOS,
            product: .uiTests,
            bundleId: "com.carti.ribs.swift.samples.login.uitests",
            deploymentTargets: .iOS("17.0"),
            sources: ["UITests/**"],
            dependencies: [.target(name: "LoginSample")]
        ),
    ]
)
