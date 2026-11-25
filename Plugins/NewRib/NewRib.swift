import Foundation
import PackagePlugin

/// RIB 스캐폴딩 명령 플러그인. 모드가 둘이다. 만드는 계약은 `render(state)`/`handle(action)` 모양이다(ADR-0029).
///
/// 한 모듈 모드: RIB 하나를 기존 모듈 안에 만든다.
///
///     swift package --allow-writing-to-package-directory new-rib \
///         --name Profile --sources Sources/App --tests Tests/AppTests --module App [--swiftui Sources/AppUI]
///
/// - <sources>/<Name>.swift: 뷰 계약, Dependency, Listener, Builder, Interactor, Router
/// - <tests>/<Name>InteractorTests.swift
/// - <swiftui>/<Name>View.swift, <Name>Screen.swift (선택): 순수 뷰와 어댑터
///
/// 피처 모드: µFeature 피처 하나를 타깃 네 개의 디렉터리로 만든다(ADR-0024).
///
///     swift package --allow-writing-to-package-directory new-rib \
///         --feature Profile [--root Features] [--prefix Feature] [--swiftui iOS/Features/Profile]
///
/// - <root>/<Name>/Interface/<Name>Interface.swift, Sources/<Name>.swift, Testing/<Name>Fakes.swift, Tests/<Name>Tests.swift
/// - <swiftui>/UI/<Name>View.swift, <swiftui>/Adapter/<Name>Screen.swift (선택)
///
/// 하나라도 이미 있으면 아무것도 만들지 않고 실패한다. `Package.swift`는 고치지 않고 넣을 줄을 출력한다.
@main
struct NewRib: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) throws {
        var extractor = ArgumentExtractor(arguments)
        let options = try Options(
            name: extractor.extractOption(named: "name").last,
            feature: extractor.extractOption(named: "feature").last,
            sources: extractor.extractOption(named: "sources").last,
            tests: extractor.extractOption(named: "tests").last,
            module: extractor.extractOption(named: "module").last,
            root: extractor.extractOption(named: "root").last,
            prefix: extractor.extractOption(named: "prefix").last,
            swiftUI: extractor.extractOption(named: "swiftui").last
        )
        guard extractor.remainingArguments.isEmpty else {
            throw NewRibError("Unknown arguments: \(extractor.remainingArguments.joined(separator: " "))")
        }

        let root = context.package.directoryURL
        let outputs = options.outputs.map { (root.appending(path: $0.path), $0.content) }
        let existing = outputs.map(\.0).filter { FileManager.default.fileExists(atPath: $0.path) }
        guard existing.isEmpty else {
            throw NewRibError("Refusing to overwrite: \(existing.map(\.path).joined(separator: ", "))")
        }
        for (url, content) in outputs {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.write(to: url, atomically: true, encoding: .utf8)
            print("created \(url.path)")
        }
        print(options.nextSteps)
    }
}

struct OutputFile {
    let path: String
    let content: String
}

enum Options {
    case rib(name: String, sources: String, tests: String, module: String, swiftUI: String?)
    case feature(name: String, root: String, prefix: String, swiftUI: String?)

    init(
        name: String?, feature: String?, sources: String?, tests: String?, module: String?,
        root: String?, prefix: String?, swiftUI: String?
    ) throws {
        switch (name, feature) {
        case (.some, .some):
            throw NewRibError("Use either --name (one module) or --feature (µFeature), not both")
        case (nil, nil):
            throw NewRibError("--name is required (e.g. --name Profile), or use --feature Profile")
        case (let name?, nil):
            guard root == nil, prefix == nil else { throw NewRibError("--root and --prefix belong to --feature") }
            guard let sources else { throw NewRibError("--sources is required (e.g. --sources Sources/App)") }
            guard let tests else { throw NewRibError("--tests is required (e.g. --tests Tests/AppTests)") }
            guard let module else { throw NewRibError("--module is required (the module that holds --sources)") }
            try Self.validate(name: name, option: "--name", paths: [sources, tests, swiftUI])
            self = .rib(name: name, sources: sources, tests: tests, module: module, swiftUI: swiftUI)
        case (nil, let feature?):
            guard sources == nil, tests == nil, module == nil else {
                throw NewRibError("--sources, --tests and --module belong to --name")
            }
            let root = root ?? "Features"
            try Self.validate(name: feature, option: "--feature", paths: [root, swiftUI])
            self = .feature(name: feature, root: root, prefix: prefix ?? "Feature", swiftUI: swiftUI)
        }
    }

    private static func validate(name: String, option: String, paths: [String?]) throws {
        guard let first = name.unicodeScalars.first, CharacterSet.uppercaseLetters.contains(first),
              name.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) && $0.isASCII })
        else { throw NewRibError("\(option) must be ASCII PascalCase: \(name)") }
        for path in paths.compactMap({ $0 }) where path.hasPrefix("/") || path.contains("..") {
            throw NewRibError("Paths must be relative to the package and stay inside it: \(path)")
        }
    }

    var outputs: [OutputFile] {
        switch self {
        case .rib(let name, let sources, let tests, let module, let swiftUI):
            var files = [
                OutputFile(path: "\(sources)/\(name).swift", content: Templates.rib(name)),
                OutputFile(path: "\(tests)/\(name)InteractorTests.swift", content: Templates.ribTest(name, module: module)),
            ]
            if let swiftUI {
                files += [
                    OutputFile(path: "\(swiftUI)/\(name)View.swift", content: Templates.pureView(name, isPublic: false)),
                    OutputFile(
                        path: "\(swiftUI)/\(name)Screen.swift",
                        content: Templates.adapter(name, contractModule: module, viewModule: nil)
                    ),
                ]
            }
            return files
        case .feature(let name, let root, let prefix, let swiftUI):
            let module = "\(prefix)\(name)"
            let directory = "\(root)/\(name)"
            var files = [
                OutputFile(path: "\(directory)/Interface/\(name)Interface.swift", content: Templates.featureInterface(name)),
                OutputFile(path: "\(directory)/Sources/\(name).swift", content: Templates.featureImpl(name, module: module)),
                OutputFile(path: "\(directory)/Testing/\(name)Fakes.swift", content: Templates.featureFakes(name, module: module)),
                OutputFile(path: "\(directory)/Tests/\(name)Tests.swift", content: Templates.featureTest(name, module: module)),
            ]
            if let swiftUI {
                files += [
                    OutputFile(path: "\(swiftUI)/UI/\(name)View.swift", content: Templates.pureView(name, isPublic: true)),
                    OutputFile(
                        path: "\(swiftUI)/Adapter/\(name)Screen.swift",
                        content: Templates.adapter(name, contractModule: "\(module)Interface", viewModule: "\(module)UI")
                    ),
                ]
            }
            return files
        }
    }

    var nextSteps: String {
        switch self {
        case .rib(let name, _, _, _, _):
            return "Next: add make\(name)View() to your view factory, wire \(name)Builder in the parent Component/Router."
        case .feature(let name, _, let prefix, let swiftUI):
            var lines = [
                "Next:",
                "  1. Declare the four targets (\(prefix)\(name)Interface, \(prefix)\(name), \(prefix)\(name)Testing, \(prefix)\(name)Tests).",
                "     With the TodoModular helper, add this to Package.swift: feature(\"\(name)\")",
                "  2. Have the parent's Dependency hand out any \(name)Buildable, and build \(name)Builder in the assembly module.",
            ]
            if swiftUI != nil {
                lines.append("  3. Declare \(prefix)\(name)UI (SwiftUI only) and \(prefix)\(name)Adapter (depends on the UI and the Interface).")
            }
            return lines.joined(separator: "\n")
        }
    }
}

struct NewRibError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
