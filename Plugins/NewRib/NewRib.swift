import Foundation
import PackagePlugin

/// RIB 스캐폴딩. carti-RIBs-KMP `./gradlew newRib`을 SwiftPM 명령 플러그인으로 옮겼다.
///
///     swift package --allow-writing-to-package-directory new-rib \
///         --name Profile --sources Sources/App --tests Tests/AppTests --module App [--swiftui Sources/AppUI]
///
/// 만드는 파일(하나라도 이미 있으면 아무것도 만들지 않고 실패한다):
/// - <sources>/<Name>.swift: 뷰 계약, Dependency, Listener, Builder, Interactor, Router
/// - <tests>/<Name>InteractorTests.swift
/// - <swiftui>/<Name>Screen.swift (선택): RIBsSwiftUI로 그리는 뷰 계약 구현
@main
struct NewRib: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) throws {
        var extractor = ArgumentExtractor(arguments)
        let options = try Options(
            name: extractor.extractOption(named: "name").last,
            sources: extractor.extractOption(named: "sources").last,
            tests: extractor.extractOption(named: "tests").last,
            module: extractor.extractOption(named: "module").last,
            swiftUI: extractor.extractOption(named: "swiftui").last
        )
        guard extractor.remainingArguments.isEmpty else {
            throw NewRibError("Unknown arguments: \(extractor.remainingArguments.joined(separator: " "))")
        }
        let root = context.package.directoryURL
        var outputs: [(URL, String)] = [
            (root.appending(path: "\(options.sources)/\(options.name).swift"), Templates.rib(options.name)),
            (
                root.appending(path: "\(options.tests)/\(options.name)InteractorTests.swift"),
                Templates.test(options.name, module: options.module)
            ),
        ]
        if let swiftUI = options.swiftUI {
            outputs.append((
                root.appending(path: "\(swiftUI)/\(options.name)Screen.swift"),
                Templates.swiftUIScreen(options.name, module: options.module)
            ))
        }
        let existing = outputs.map(\.0).filter { FileManager.default.fileExists(atPath: $0.path) }
        guard existing.isEmpty else {
            throw NewRibError("Refusing to overwrite: \(existing.map(\.path).joined(separator: ", "))")
        }
        for (url, content) in outputs {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.write(to: url, atomically: true, encoding: .utf8)
            print("created \(url.path)")
        }
        print("Next: add make\(options.name)View() to your view factory, wire \(options.name)Builder in the parent Component/Router.")
    }
}

struct Options {
    let name: String
    let sources: String
    let tests: String
    let module: String
    let swiftUI: String?

    init(name: String?, sources: String?, tests: String?, module: String?, swiftUI: String?) throws {
        guard let name else { throw NewRibError("--name is required (e.g. --name Profile)") }
        guard let sources else { throw NewRibError("--sources is required (e.g. --sources Sources/App)") }
        guard let tests else { throw NewRibError("--tests is required (e.g. --tests Tests/AppTests)") }
        guard let module else { throw NewRibError("--module is required (the module that holds --sources)") }
        guard let first = name.unicodeScalars.first, CharacterSet.uppercaseLetters.contains(first),
              name.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) && $0.isASCII })
        else { throw NewRibError("--name must be ASCII PascalCase: \(name)") }
        for path in [sources, tests, swiftUI].compactMap({ $0 }) where path.hasPrefix("/") || path.contains("..") {
            throw NewRibError("Paths must be relative to the package and stay inside it: \(path)")
        }
        self.name = name
        self.sources = sources
        self.tests = tests
        self.module = module
        self.swiftUI = swiftUI
    }
}

struct NewRibError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
