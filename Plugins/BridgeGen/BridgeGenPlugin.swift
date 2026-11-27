import Foundation
import PackagePlugin

@main
struct BridgeGenCommandPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) throws {
        let tool = try context.tool(named: "bridge-gen")
        let process = Process()
        process.executableURL = tool.url
        process.arguments = arguments
        process.currentDirectoryURL = context.package.directoryURL
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw BridgeGenPluginError.failed(status: process.terminationStatus)
        }
    }
}

enum BridgeGenPluginError: Error, CustomStringConvertible {
    case failed(status: Int32)

    var description: String {
        switch self {
        case .failed(let status):
            return "bridge-gen exited with status \(status)"
        }
    }
}
