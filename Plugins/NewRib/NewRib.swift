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
///         --feature Profile [--root Features] [--prefix Feature] [--swiftui iOS/Features/Profile] \
///         [--android Android/swift/Sources --android-bridge TodoModularBridge --android-support TodoAndroidSupport] \
///         [--web Web/Sources --web-bridge TodoModularWeb --web-support TodoWebSupport]
///
/// - <root>/<Name>/Interface/<Name>Interface.swift, Sources/<Name>.swift, Testing/<Name>Fakes.swift, Tests/<Name>Tests.swift
/// - <swiftui>/UI/<Name>View.swift, <swiftui>/Adapter/<Name>Screen.swift (선택)
/// - <android>/<Prefix><Name>Android/<Name>AndroidScreen.swift, <android>/<android-bridge>/<Name>Handle.swift (선택, ADR-0031)
/// - <web>/<Prefix><Name>Web/<Name>WebScreen.swift, <web>/<web-bridge>/<Name>Bridge.swift (선택, ADR-0031)
///
/// 연결 모드: 플랫폼 연결 코드만 만든다. 공유 코드와 플랫폼 코드가 다른 패키지에 있을 때 플랫폼 패키지에서 돌린다.
///
///     swift package --allow-writing-to-package-directory new-rib \
///         --connect Profile [--prefix Feature] --web Sources --web-bridge TodoModularWeb --web-support TodoWebSupport
///
/// `--android`·`--web`은 TodoModular 샘플의 구조를 전제로 한다. support 모듈에 `BridgedScreen`/`WebScreen`이 있어야 한다.
///
/// 하나라도 이미 있으면 아무것도 만들지 않고 실패한다. `Package.swift`는 고치지 않고 넣을 줄을 출력한다.
@main
struct NewRib: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) throws {
        var extractor = ArgumentExtractor(arguments)
        let options = try Options(
            name: extractor.extractOption(named: "name").last,
            feature: extractor.extractOption(named: "feature").last,
            connect: extractor.extractOption(named: "connect").last,
            sources: extractor.extractOption(named: "sources").last,
            tests: extractor.extractOption(named: "tests").last,
            module: extractor.extractOption(named: "module").last,
            root: extractor.extractOption(named: "root").last,
            prefix: extractor.extractOption(named: "prefix").last,
            swiftUI: extractor.extractOption(named: "swiftui").last,
            android: try Platform(
                "android",
                sources: extractor.extractOption(named: "android").last,
                bridge: extractor.extractOption(named: "android-bridge").last,
                support: extractor.extractOption(named: "android-support").last
            ),
            web: try Platform(
                "web",
                sources: extractor.extractOption(named: "web").last,
                bridge: extractor.extractOption(named: "web-bridge").last,
                support: extractor.extractOption(named: "web-support").last
            )
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

/// 플랫폼 연결 코드를 둘 곳. 옵션 셋(`--<p>`, `--<p>-bridge`, `--<p>-support`)은 함께 주거나 모두 뺀다.
struct Platform {
    /// 플랫폼 Swift 패키지의 소스 디렉터리. 이 아래에 피처 타깃과 브리지 타깃 디렉터리가 있다.
    let sources: String
    /// swift-java·BridgeJS가 도는 타깃(디렉터리 이름과 같다).
    let bridge: String
    /// 화면 기반 클래스가 있는 모듈.
    let support: String

    init?(_ option: String, sources: String?, bridge: String?, support: String?) throws {
        if sources == nil, bridge == nil, support == nil { return nil }
        guard let sources, let bridge, let support else {
            throw NewRibError("--\(option), --\(option)-bridge and --\(option)-support must be given together")
        }
        for module in [bridge, support]
        where module.isEmpty || !module.unicodeScalars.allSatisfy({ ($0.isASCII && CharacterSet.alphanumerics.contains($0)) || $0 == "_" }) {
            throw NewRibError("--\(option)-bridge and --\(option)-support must be module names: \(module)")
        }
        guard !sources.isEmpty else { throw NewRibError("--\(option) must not be empty") }
        self.sources = sources
        self.bridge = bridge
        self.support = support
    }

    /// 두 플랫폼의 브리지 파일이 같은 타깃에 들어가면 같은 이름의 타입이 두 번 선언된다.
    static func validate(android: Platform?, web: Platform?) throws {
        guard let android, let web, android.sources == web.sources, android.bridge == web.bridge else { return }
        throw NewRibError("--android-bridge and --web-bridge must be different bridge targets")
    }
}

enum Options {
    case rib(name: String, sources: String, tests: String, module: String, swiftUI: String?)
    case feature(name: String, root: String, prefix: String, swiftUI: String?, android: Platform?, web: Platform?)
    case connection(name: String, prefix: String, android: Platform?, web: Platform?)

    init(
        name: String?, feature: String?, connect: String?, sources: String?, tests: String?, module: String?,
        root: String?, prefix: String?, swiftUI: String?, android: Platform?, web: Platform?
    ) throws {
        try Platform.validate(android: android, web: web)
        if let connect {
            guard name == nil, feature == nil, sources == nil, tests == nil, module == nil, root == nil, swiftUI == nil else {
                throw NewRibError("--connect takes only --prefix, --android and --web options")
            }
            guard android != nil || web != nil else { throw NewRibError("--connect needs --android or --web") }
            try Self.validate(name: connect, option: "--connect", paths: [android?.sources, web?.sources])
            self = .connection(name: connect, prefix: prefix ?? "Feature", android: android, web: web)
            return
        }
        switch (name, feature) {
        case (.some, .some):
            throw NewRibError("Use either --name (one module) or --feature (µFeature), not both")
        case (nil, nil):
            throw NewRibError("--name is required (e.g. --name Profile), or use --feature Profile")
        case (let name?, nil):
            guard root == nil, prefix == nil, android == nil, web == nil else {
                throw NewRibError("--root, --prefix, --android and --web belong to --feature")
            }
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
            try Self.validate(name: feature, option: "--feature", paths: [root, swiftUI, android?.sources, web?.sources])
            self = .feature(name: feature, root: root, prefix: prefix ?? "Feature", swiftUI: swiftUI, android: android, web: web)
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
        case .feature(let name, let root, let prefix, let swiftUI, let android, let web):
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
            files += Self.platformFiles(name: name, module: module, android: android, web: web)
            return files
        case .connection(let name, let prefix, let android, let web):
            return Self.platformFiles(name: name, module: "\(prefix)\(name)", android: android, web: web)
        }
    }

    private static func platformFiles(name: String, module: String, android: Platform?, web: Platform?) -> [OutputFile] {
        var files: [OutputFile] = []
        if let android {
            files += [
                OutputFile(
                    path: "\(android.sources)/\(module)Android/\(name)AndroidScreen.swift",
                    content: Templates.androidScreen(name, module: module, support: android.support)
                ),
                OutputFile(
                    path: "\(android.sources)/\(android.bridge)/\(name)Handle.swift",
                    content: Templates.androidHandle(name, module: module)
                ),
            ]
        }
        if let web {
            files += [
                OutputFile(
                    path: "\(web.sources)/\(module)Web/\(name)WebScreen.swift",
                    content: Templates.webScreen(name, module: module, support: web.support)
                ),
                OutputFile(
                    path: "\(web.sources)/\(web.bridge)/\(name)Bridge.swift",
                    content: Templates.webBridge(name, module: module, support: web.support)
                ),
            ]
        }
        return files
    }

    var nextSteps: String {
        switch self {
        case .rib(let name, _, _, _, _):
            return "Next: add make\(name)View() to your view factory, wire \(name)Builder in the parent Component/Router."
        case .feature(let name, _, let prefix, let swiftUI, let android, let web):
            var lines = [
                "Next:",
                "  1. Declare the four targets (\(prefix)\(name)Interface, \(prefix)\(name), \(prefix)\(name)Testing, \(prefix)\(name)Tests).",
                "     With the TodoModular helper, add this to Package.swift: feature(\"\(name)\") (and \"\(name)\" to `features`)",
                "  2. Have the parent's Dependency hand out any \(name)Buildable, and build \(name)Builder in the assembly module.",
            ]
            if swiftUI != nil {
                lines.append("  - Declare \(prefix)\(name)UI (SwiftUI only) and \(prefix)\(name)Adapter (depends on the UI and the Interface).")
            }
            lines += Self.platformSteps(name: name, prefix: prefix, android: android, web: web)
            return lines.joined(separator: "\n")
        case .connection(let name, let prefix, let android, let web):
            return (["Next:"] + Self.platformSteps(name: name, prefix: prefix, android: android, web: web)).joined(separator: "\n")
        }
    }

    private static func platformSteps(name: String, prefix: String, android: Platform?, web: Platform?) -> [String] {
        var lines: [String] = []
        if let android {
            lines.append("  - Android: declare \(prefix)\(name)Android (depends on the Interface, RIBsAndroid, \(android.support)) and add it to \(android.bridge).")
            lines.append("    \(name)Handle.swift expects a @MainActor global `controller` with screen(id:as:) in \(android.bridge). Write the Kotlin adapter that implements \(name)ViewBridge.")
        }
        if let web {
            lines.append("  - Web: declare \(prefix)\(name)Web (depends on the Interface, JavaScriptKit, \(web.support)) and add it to \(web.bridge).")
            lines.append("    Pass \(Templates.lowerCamel(name))ViewFactory(view) to \(name)Builder. Write the JS view that implements \(name)ViewBridge.")
        }
        return lines
    }
}

struct NewRibError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
