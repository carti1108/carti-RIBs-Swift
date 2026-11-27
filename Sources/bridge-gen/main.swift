import BridgeGenCore
import Foundation

struct Options {
    var coreDirs: [String] = []
    var featuresDir: String = ""
    var modulePrefix: String = "Feature"
    var extraImports: [String] = []
    var swiftOut: String?
    var tsOut: String?
    var kotlinOut: String?
    var kotlinPackage: String?
    var checkOnly: Bool = false
}

func parseOptions(_ args: [String]) -> Options? {
    var options = Options()
    var i = 1
    while i < args.count {
        let arg = args[i]
        if arg == "--check" {
            options.checkOnly = true
            i += 1
            continue
        }
        guard i + 1 < args.count else { return nil }
        let value = args[i + 1]
        switch arg {
        case "--core-dir": options.coreDirs.append(value)
        case "--features-dir": options.featuresDir = value
        case "--module-prefix": options.modulePrefix = value
        case "--extra-import": options.extraImports.append(value)
        case "--swift-out": options.swiftOut = value
        case "--ts-out": options.tsOut = value
        case "--kotlin-out": options.kotlinOut = value
        case "--kotlin-package": options.kotlinPackage = value
        default: return nil
        }
        i += 2
    }
    guard !options.featuresDir.isEmpty else { return nil }
    if options.kotlinOut != nil && options.kotlinPackage == nil { return nil }
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

func emitOrCheck(path: String, content: String, checkOnly: Bool) throws -> Bool {
    let url = URL(fileURLWithPath: path)
    let fm = FileManager.default
    if checkOnly {
        guard fm.fileExists(atPath: url.path) else {
            FileHandle.standardError.write(Data(("missing generated file: \(url.path)\n").utf8))
            return false
        }
        let existing = try String(contentsOf: url, encoding: .utf8)
            .replacingOccurrences(of: "\r\n", with: "\n")
        let normalized = content.replacingOccurrences(of: "\r\n", with: "\n")
        if existing != normalized {
            FileHandle.standardError.write(Data(("out-of-date generated file: \(url.path)\n").utf8))
            return false
        }
        return true
    } else {
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
        print("Generated \(url.path)")
        return true
    }
}

func run() throws -> Int32 {
    guard let options = parseOptions(CommandLine.arguments) else {
        let usage = """
        Usage: bridge-gen --features-dir <dir> [--core-dir <dir> ...]
          [--module-prefix <prefix>] [--extra-import <module> ...]
          [--swift-out <file>] [--ts-out <file>]
          [--kotlin-out <file> --kotlin-package <pkg>] [--check]
        """
        FileHandle.standardError.write(Data((usage + "\n").utf8))
        return 2
    }

    let fm = FileManager.default
    var modelSources: [String] = []
    for coreDir in options.coreDirs {
        for url in collectSwiftFiles(under: coreDir) {
            modelSources.append(try String(contentsOf: url, encoding: .utf8))
        }
    }

    let featuresURL = URL(fileURLWithPath: options.featuresDir)
    let featureDirs = try fm.contentsOfDirectory(at: featuresURL, includingPropertiesForKeys: [.isDirectoryKey])
        .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

    var featureInputs: [FeatureInput] = []
    for dir in featureDirs {
        let featureName = dir.lastPathComponent
        let interfaceFile = dir.appendingPathComponent("Interface/\(featureName)Interface.swift")
        guard fm.fileExists(atPath: interfaceFile.path) else { continue }
        let source = try String(contentsOf: interfaceFile, encoding: .utf8)
        featureInputs.append(FeatureInput(
            featureName: featureName,
            interfaceModule: "\(options.modulePrefix)\(featureName)Interface",
            interfaceSource: source
        ))
    }

    let schema = try ContractParser.parseSchema(
        features: featureInputs,
        modelSources: modelSources,
        extraImports: options.extraImports
    )

    var allOk = true
    if let swiftOut = options.swiftOut {
        let content = SwiftChannelGenerator.generate(schema: schema)
        if try !emitOrCheck(path: swiftOut, content: content, checkOnly: options.checkOnly) {
            allOk = false
        }
    }
    if let tsOut = options.tsOut {
        let content = TypeScriptGenerator.generate(schema: schema)
        if try !emitOrCheck(path: tsOut, content: content, checkOnly: options.checkOnly) {
            allOk = false
        }
    }
    if let kotlinOut = options.kotlinOut, let pkg = options.kotlinPackage {
        let content = KotlinGenerator.generate(schema: schema, packageName: pkg)
        if try !emitOrCheck(path: kotlinOut, content: content, checkOnly: options.checkOnly) {
            allOk = false
        }
    }

    return allOk ? 0 : 1
}

do {
    exit(try run())
} catch {
    FileHandle.standardError.write(Data(("bridge-gen error: \(error)\n").utf8))
    exit(1)
}
