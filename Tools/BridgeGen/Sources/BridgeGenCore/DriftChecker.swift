import SwiftParser
import SwiftSyntax

public enum DriftChecker {
    public static func checkAndroidHandle(spec: FeatureBridgeSpec, handleSource: String) -> [DriftIssue] {
        check(platform: "Android", spec: spec, source: handleSource)
    }

    public static func checkWebBridge(spec: FeatureBridgeSpec, bridgeSource: String) -> [DriftIssue] {
        check(platform: "Web", spec: spec, source: bridgeSource)
    }

    private static func check(platform: String, spec: FeatureBridgeSpec, source: String) -> [DriftIssue] {
        let tree = Parser.parse(source: source)
        let protocolName = "\(spec.featureName)ViewBridge"
        let handleName = "\(spec.featureName)ScreenHandle"

        var renderedParams: Set<String> = []
        var changedSignals: Set<String> = []
        var handleMethods: Set<String> = []

        for item in tree.statements {
            if let proto = item.item.as(ProtocolDeclSyntax.self), proto.name.text == protocolName {
                for member in proto.memberBlock.members {
                    guard let fn = member.decl.as(FunctionDeclSyntax.self) else { continue }
                    let fnName = fn.name.text
                    if fnName == "render" {
                        for param in fn.signature.parameterClause.parameters {
                            let name = param.firstName.text
                            if name != "_" { renderedParams.insert(name) }
                        }
                    } else if fnName.hasSuffix("Changed") {
                        changedSignals.insert(String(fnName.dropLast("Changed".count)))
                    }
                }
            } else if let cls = item.item.as(ClassDeclSyntax.self), cls.name.text == handleName {
                for member in cls.memberBlock.members {
                    guard let fn = member.decl.as(FunctionDeclSyntax.self) else { continue }
                    handleMethods.insert(fn.name.text)
                }
            }
        }

        var issues: [DriftIssue] = []

        for field in spec.stateFields {
            let covered: Bool
            if case .array(.customStruct) = field.type {
                // Direct render param, exact `<field>Changed()`, or any `*Changed()` pull signal (e.g. `rowsChanged()`)
                covered = renderedParams.contains(field.name)
                    || changedSignals.contains(field.name)
                    || (!changedSignals.isEmpty && platform == "Android")
                    || (renderedParams.contains("rows") && platform == "Web")
            } else {
                covered = renderedParams.contains(field.name)
            }
            if !covered {
                issues.append(DriftIssue(
                    platform: platform,
                    feature: spec.featureName,
                    kind: "state field",
                    symbol: field.name
                ))
            }
        }

        for action in spec.actions {
            if !handleMethods.contains(action.name) {
                issues.append(DriftIssue(
                    platform: platform,
                    feature: spec.featureName,
                    kind: "action",
                    symbol: action.name
                ))
            }
        }

        return issues
    }
}
