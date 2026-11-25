// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BJSSpike",
    dependencies: [.package(url: "https://github.com/swiftwasm/JavaScriptKit.git", exact: "0.63.0")],
    targets: [
        .executableTarget(
            name: "Facade",
            dependencies: ["JavaScriptKit"],
            swiftSettings: [.enableExperimentalFeature("Extern")],
            plugins: [.plugin(name: "BridgeJS", package: "JavaScriptKit")]
        )
    ],
    swiftLanguageModes: [.v6]
)
