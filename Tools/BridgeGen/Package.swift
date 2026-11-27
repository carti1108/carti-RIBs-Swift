// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BridgeGen",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax", exact: "603.0.2"),
    ],
    targets: [
        .target(
            name: "BridgeGenCore",
            dependencies: [
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .executableTarget(
            name: "bridge-gen",
            dependencies: ["BridgeGenCore"]
        ),
        .testTarget(
            name: "BridgeGenTests",
            dependencies: ["BridgeGenCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
