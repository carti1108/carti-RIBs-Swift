import BridgeGenCore
import Foundation

struct Options {
    var sharedRoot: String = ""
    var androidOut: String?
    var webOut: String?
    var checkAndroid: String?
    var checkWeb: String?
}

func parseOptions(_ args: [String]) -> Options? {
    var options = Options()
    var i = 1
    while i < args.count {
        let arg = args[i]
        guard i + 1 < args.count else { return nil }
        let value = args[i + 1]
        switch arg {
        case "--shared-root": options.sharedRoot = value
        case "--android-out": options.androidOut = value
        case "--web-out": options.webOut = value
        case "--check-android": options.checkAndroid = value
        case "--check-web": options.checkWeb = value
        default: return nil
        }
        i += 2
    }
    guard !options.sharedRoot.isEmpty else { return nil }
    return options
}

func collectSwiftFiles(under directory: String) -> [URL] {
    let fm = FileManager.default
    let rootURL = URL(fileURLWithPath: directory)
    guard let enumerator = fm.enumerator(at: rootURL, includingPropertiesForKeys: nil) else { return [] }
    var urls: [URL] = []
    for case let url as URL in enumerator {
        if url.pathExtension == "swift" {
            urls.append(url)
        }
    }
    return urls.sorted { $0.path < $1.path }
}

func run() throws -> Int32 {
    guard let options = parseOptions(CommandLine.arguments) else {
        let usage = """
        Usage: bridge-gen --shared-root <path>
          [--android-out <dir>] [--web-out <dir>]
          [--check-android <dir>] [--check-web <dir>]
        """
        FileHandle.standardError.write(Data((usage + "\n").utf8))
        return 2
    }

    let fm = FileManager.default
    let coreSourcesDir = URL(fileURLWithPath: options.sharedRoot).appendingPathComponent("Core/Sources").path
    let modelSources = try collectSwiftFiles(under: coreSourcesDir).map { try String(contentsOf: $0, encoding: .utf8) }

    let featuresDir = URL(fileURLWithPath: options.sharedRoot).appendingPathComponent("Features")
    let featureDirs = try fm.contentsOfDirectory(at: featuresDir, includingPropertiesForKeys: [.isDirectoryKey])
        .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

    var specs: [FeatureBridgeSpec] = []
    for dir in featureDirs {
        let featureName = dir.lastPathComponent
        let interfaceFile = dir.appendingPathComponent("Interface/\(featureName)Interface.swift")
        guard fm.fileExists(atPath: interfaceFile.path) else { continue }
        let interfaceSource = try String(contentsOf: interfaceFile, encoding: .utf8)
        let spec = try ContractParser.parseFeature(
            featureName: featureName,
            interfaceSource: interfaceSource,
            modelSources: modelSources
        )
        specs.append(spec)
    }

    if let androidOut = options.androidOut {
        try fm.createDirectory(atPath: androidOut, withIntermediateDirectories: true)
        for spec in specs {
            let code = AndroidBridgeGenerator.generateHandle(for: spec)
            let outFile = URL(fileURLWithPath: androidOut).appendingPathComponent("\(spec.featureName)Handle.swift")
            try code.write(to: outFile, atomically: true, encoding: .utf8)
            print("Generated \(outFile.path)")
        }
    }

    if let webOut = options.webOut {
        try fm.createDirectory(atPath: webOut, withIntermediateDirectories: true)
        for spec in specs {
            let code = WebBridgeGenerator.generateBridge(for: spec)
            let outFile = URL(fileURLWithPath: webOut).appendingPathComponent("\(spec.featureName)Bridge.swift")
            try code.write(to: outFile, atomically: true, encoding: .utf8)
            print("Generated \(outFile.path)")
        }
        let mounts = WebBridgeGenerator.generateViewMounts(for: specs)
        let mountsFile = URL(fileURLWithPath: webOut).appendingPathComponent("ViewMounts.swift")
        try mounts.write(to: mountsFile, atomically: true, encoding: .utf8)
        print("Generated \(mountsFile.path)")
    }

    var driftIssues: [DriftIssue] = []
    if let checkAndroid = options.checkAndroid {
        for spec in specs {
            let file = URL(fileURLWithPath: checkAndroid).appendingPathComponent("\(spec.featureName)Handle.swift")
            guard fm.fileExists(atPath: file.path) else {
                driftIssues.append(DriftIssue(platform: "Android", feature: spec.featureName, kind: "file", symbol: file.lastPathComponent))
                continue
            }
            let src = try String(contentsOf: file, encoding: .utf8)
            driftIssues += DriftChecker.checkAndroidHandle(spec: spec, handleSource: src)
        }
    }

    if let checkWeb = options.checkWeb {
        for spec in specs {
            let file = URL(fileURLWithPath: checkWeb).appendingPathComponent("\(spec.featureName)Bridge.swift")
            guard fm.fileExists(atPath: file.path) else {
                driftIssues.append(DriftIssue(platform: "Web", feature: spec.featureName, kind: "file", symbol: file.lastPathComponent))
                continue
            }
            let src = try String(contentsOf: file, encoding: .utf8)
            driftIssues += DriftChecker.checkWebBridge(spec: spec, bridgeSource: src)
        }
    }

    if !driftIssues.isEmpty {
        for issue in driftIssues {
            FileHandle.standardError.write(Data((issue.description + "\n").utf8))
        }
        return 1
    }

    return 0
}

do {
    exit(try run())
} catch {
    FileHandle.standardError.write(Data(("bridge-gen error: \(error)\n").utf8))
    exit(1)
}
