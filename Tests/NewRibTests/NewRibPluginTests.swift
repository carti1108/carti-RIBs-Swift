import Foundation
import Testing

// 명령 플러그인은 테스트 타깃에서 import할 수 없다. 그래서 임시 패키지를 만들어 그 안에서
// `swift package new-rib`와 `swift test`를 실제로 돌린다. 이 패키지를 경로 의존으로 받으므로 한 번 실행에 수십 초가 걸린다.
// Windows는 `swift` 실행 파일을 찾는 방법이 달라 뺀다. Windows에서는 확인하지 않았다.
#if os(macOS) || os(Linux)

/// 임시 디렉터리에 만든 패키지. 끝나면 지운다.
private final class FixturePackage {
    let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: "ribs-new-rib-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    func write(_ content: String, to path: String) throws {
        let url = directory.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: directory.appending(path: path).path)
    }

    func read(_ path: String) throws -> String {
        try String(contentsOf: directory.appending(path: path), encoding: .utf8)
    }

    /// `swift <arguments>`를 이 패키지에서 돌리고 종료 코드와 출력(표준 출력 + 표준 오류)을 돌려준다.
    func swift(_ arguments: String...) throws -> (status: Int32, output: String) {
        try run(arguments)
    }

    /// `swift package new-rib <arguments>`를 이 패키지에서 돌린다.
    func newRibArguments(_ arguments: [String]) throws -> (status: Int32, output: String) {
        try run(["package", "--allow-writing-to-package-directory", "new-rib"] + arguments)
    }

    private func run(_ arguments: [String]) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift"] + arguments
        process.currentDirectoryURL = directory
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}

@Suite struct NewRibPluginTests {
    /// 이 저장소의 루트. 임시 패키지가 경로 의존으로 받는다.
    private static let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path

    #if os(macOS)
    private static let hasSwiftUI = true
    #else
    private static let hasSwiftUI = false
    #endif

    /// 한 모듈 모드(`--name`)와 피처 모드(`--feature`)의 타깃을 함께 둔 매니페스트. SwiftUI 타깃은 macOS에서만 넣는다.
    private static var manifest: String {
        let swiftUITargets = hasSwiftUI ? """
                .target(name: "AppUI", dependencies: ["App", ribs, ribsSwiftUI]),
                .target(name: "FeatureProfileUI", path: "iOS/Profile/UI"),
                .target(
                    name: "FeatureProfileAdapter",
                    dependencies: ["FeatureProfileInterface", "FeatureProfileUI", ribs, ribsSwiftUI],
                    path: "iOS/Profile/Adapter"
                ),
        """ : ""
        return """
        // swift-tools-version: 6.0
        import PackageDescription

        let ribs: Target.Dependency = .product(name: "RIBs", package: "RIBs")
        let ribsSwiftUI: Target.Dependency = .product(name: "RIBsSwiftUI", package: "RIBs")

        let package = Package(
            name: "Fixture",
            platforms: [.macOS(.v14)],
            dependencies: [.package(name: "RIBs", path: "\(repositoryRoot)")],
            targets: [
                .target(name: "App", dependencies: [ribs]),
                .testTarget(name: "AppTests", dependencies: ["App", ribs]),
                .target(name: "FeatureProfileInterface", dependencies: [ribs], path: "Features/Profile/Interface"),
                .target(name: "FeatureProfile", dependencies: ["FeatureProfileInterface", ribs], path: "Features/Profile/Sources"),
                .target(
                    name: "FeatureProfileTesting",
                    dependencies: ["FeatureProfileInterface", ribs],
                    path: "Features/Profile/Testing"
                ),
                .testTarget(
                    name: "FeatureProfileTests",
                    dependencies: ["FeatureProfileInterface", "FeatureProfile", "FeatureProfileTesting", ribs],
                    path: "Features/Profile/Tests"
                ),
        \(swiftUITargets)
            ],
            swiftLanguageModes: [.v6]
        )
        """
    }

    private static let placeholderDirectories = [
        "Sources/App", "Tests/AppTests", "Sources/AppUI",
        "Features/Profile/Interface", "Features/Profile/Sources", "Features/Profile/Testing", "Features/Profile/Tests",
        "iOS/Profile/UI", "iOS/Profile/Adapter",
    ]

    @Test func generatedSkeletonsBuildAndTheirTestsPass() throws {
        let fixture = try FixturePackage()
        try fixture.write(Self.manifest, to: "Package.swift")
        // 타깃 디렉터리가 비어 있으면 매니페스트를 읽지 못한다.
        for directory in Self.placeholderDirectories {
            try fixture.write("// 자리표시\n", to: "\(directory)/Placeholder.swift")
        }

        // 한 모듈 모드
        var ribArguments = ["--name", "Settings", "--sources", "Sources/App", "--tests", "Tests/AppTests", "--module", "App"]
        if Self.hasSwiftUI { ribArguments += ["--swiftui", "Sources/AppUI"] }
        let rib = try fixture.newRibArguments(ribArguments)
        #expect(rib.status == 0, "\(rib.output)")
        #expect(fixture.exists("Sources/App/Settings.swift"))
        #expect(fixture.exists("Tests/AppTests/SettingsInteractorTests.swift"))

        // 피처 모드
        var featureArguments = ["--feature", "Profile", "--root", "Features"]
        if Self.hasSwiftUI { featureArguments += ["--swiftui", "iOS/Profile"] }
        let feature = try fixture.newRibArguments(featureArguments)
        #expect(feature.status == 0, "\(feature.output)")
        for path in ["Interface/ProfileInterface.swift", "Sources/Profile.swift", "Testing/ProfileFakes.swift", "Tests/ProfileTests.swift"] {
            #expect(fixture.exists("Features/Profile/\(path)"), "missing \(path)")
        }
        // Package.swift는 고치지 않고 넣을 줄을 알려 준다.
        #expect(feature.output.contains(#"feature("Profile")"#), "\(feature.output)")
        #expect(try fixture.read("Package.swift") == Self.manifest)

        if Self.hasSwiftUI {
            #expect(fixture.exists("Sources/AppUI/SettingsView.swift"))
            #expect(fixture.exists("Sources/AppUI/SettingsScreen.swift"))
            // 순수 뷰는 SwiftUI만 import한다(ADR-0027).
            let pureView = try fixture.read("iOS/Profile/UI/ProfileView.swift")
            let imports = pureView.split(separator: "\n").filter { $0.hasPrefix("import ") }
            #expect(imports == ["import SwiftUI"])
            #expect(fixture.exists("iOS/Profile/Adapter/ProfileScreen.swift"))
        }

        // 생성된 계약은 render(state)/handle(action) 모양이다(ADR-0025).
        let interface = try fixture.read("Features/Profile/Interface/ProfileInterface.swift")
        #expect(interface.contains("func render(_ state: ProfileViewState)"))
        #expect(interface.contains("func handle(_ action: ProfileViewAction)"))

        // 만든 그대로 빌드되고, 함께 만든 테스트가 통과한다.
        let test = try fixture.swift("test")
        #expect(test.status == 0, "\(test.output.suffix(3000))")

        // 이미 있는 파일은 덮어쓰지 않는다.
        let again = try fixture.newRibArguments(featureArguments)
        #expect(again.status != 0)
        #expect(again.output.contains("Refusing to overwrite"), "\(again.output)")
    }

    @Test func rejectsNameThatIsNotPascalCase() throws {
        let fixture = try FixturePackage()
        try fixture.write(Self.manifest, to: "Package.swift")
        for directory in Self.placeholderDirectories {
            try fixture.write("// 자리표시\n", to: "\(directory)/Placeholder.swift")
        }

        let result = try fixture.newRibArguments(["--feature", "profile-page", "--root", "Features"])

        #expect(result.status != 0)
        #expect(result.output.contains("PascalCase"), "\(result.output)")
        #expect(!fixture.exists("Features/profile-page"))
    }
}

#endif
