// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "SJSpike",
    platforms: [.macOS(.v15)],
    products: [.library(name: "LoginContract", type: .dynamic, targets: ["LoginContract"])],
    dependencies: [.package(url: "https://github.com/swiftlang/swift-java", exact: "0.7.0")],
    targets: [
        .target(
            name: "LoginContract",
            dependencies: [.product(name: "SwiftJava", package: "swift-java")],
            exclude: ["swift-java.config"],
            plugins: [.plugin(name: "JExtractSwiftPlugin", package: "swift-java")]
        )
    ],
    swiftLanguageModes: [.v6]
)
