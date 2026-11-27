import SwiftParser
import SwiftSyntax

public enum ContractParser {
    public static func parseFeature(
        featureName: String,
        interfaceSource: String,
        modelSources: [String]
    ) throws -> FeatureBridgeSpec {
        let modelStructs = try parseModelStructs(from: modelSources, featureName: featureName)
        let tree = Parser.parse(source: interfaceSource)

        let stateName = "\(featureName)ViewState"
        let actionName = "\(featureName)ViewAction"
        let controllableName = "\(featureName)ViewControllable"

        var stateFields: [ValueField]?
        var actions: [ActionCase]?
        var hasChildSlots = false

        for item in tree.statements {
            if let structDecl = item.item.as(StructDeclSyntax.self),
               structDecl.name.text == stateName {
                stateFields = try parseStructFields(structDecl, featureName: featureName)
            } else if let enumDecl = item.item.as(EnumDeclSyntax.self),
                      enumDecl.name.text == actionName {
                actions = try parseActionCases(enumDecl, featureName: featureName)
            } else if let protoDecl = item.item.as(ProtocolDeclSyntax.self),
                      protoDecl.name.text == controllableName {
                hasChildSlots = protoDecl.memberBlock.members.contains { member in
                    member.decl.is(FunctionDeclSyntax.self)
                }
            }
        }

        guard let resolvedStateFields = stateFields else {
            throw BridgeGenError.missingViewState(feature: featureName)
        }
        guard let resolvedActions = actions else {
            throw BridgeGenError.missingViewAction(feature: featureName)
        }

        var referencedStructs: [String: ValueStructSpec] = [:]
        for field in resolvedStateFields {
            try collectReferencedStructs(
                in: field.type,
                available: modelStructs,
                into: &referencedStructs,
                featureName: featureName
            )
        }
        for action in resolvedActions {
            for param in action.params {
                try collectReferencedStructs(
                    in: param.type,
                    available: modelStructs,
                    into: &referencedStructs,
                    featureName: featureName
                )
            }
        }

        return FeatureBridgeSpec(
            featureName: featureName,
            stateFields: resolvedStateFields,
            actions: resolvedActions,
            hasChildSlots: hasChildSlots,
            referencedStructs: referencedStructs
        )
    }

    private static func parseModelStructs(
        from sources: [String],
        featureName: String
    ) throws -> [String: ValueStructSpec] {
        var result: [String: ValueStructSpec] = [:]
        for source in sources {
            let tree = Parser.parse(source: source)
            for item in tree.statements {
                guard let structDecl = item.item.as(StructDeclSyntax.self) else { continue }
                let name = structDecl.name.text
                if let fields = try? parseStructFields(structDecl, featureName: featureName), !fields.isEmpty {
                    result[name] = ValueStructSpec(name: name, fields: fields)
                }
            }
        }
        return result
    }

    private static func parseStructFields(
        _ structDecl: StructDeclSyntax,
        featureName: String
    ) throws -> [ValueField] {
        var fields: [ValueField] = []
        for member in structDecl.memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }
            let isStatic = varDecl.modifiers.contains {
                $0.name.text == "static" || $0.name.text == "class"
            }
            if isStatic { continue }

            for binding in varDecl.bindings {
                if binding.accessorBlock != nil { continue }
                guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                      let typeSyntax = binding.typeAnnotation?.type else {
                    continue
                }
                let type = try parseType(typeSyntax, featureName: featureName, symbol: name)
                fields.append(ValueField(name: name, type: type))
            }
        }
        return fields
    }

    private static func parseActionCases(
        _ enumDecl: EnumDeclSyntax,
        featureName: String
    ) throws -> [ActionCase] {
        var cases: [ActionCase] = []
        for member in enumDecl.memberBlock.members {
            guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else { continue }
            for element in caseDecl.elements {
                let caseName = element.name.text
                var params: [ActionParam] = []
                if let paramList = element.parameterClause?.parameters {
                    for (idx, param) in paramList.enumerated() {
                        let rawFirst = param.firstName?.text
                        let rawSecond = param.secondName?.text
                        let label: String? = (rawFirst == "_" || rawFirst == nil) ? nil : rawFirst
                        let paramName = rawSecond ?? (rawFirst == "_" ? nil : rawFirst) ?? "arg\(idx)"
                        let type = try parseType(
                            param.type,
                            featureName: featureName,
                            symbol: "\(caseName).\(paramName)"
                        )
                        params.append(ActionParam(label: label, name: paramName, type: type))
                    }
                }
                cases.append(ActionCase(name: caseName, params: params))
            }
        }
        return cases
    }

    private static func parseType(
        _ typeSyntax: TypeSyntax,
        featureName: String,
        symbol: String
    ) throws -> BridgeType {
        if let opt = typeSyntax.as(OptionalTypeSyntax.self) {
            let wrapped = try parseType(opt.wrappedType, featureName: featureName, symbol: symbol)
            return .optional(wrapped)
        }
        if let arr = typeSyntax.as(ArrayTypeSyntax.self) {
            let element = try parseType(arr.element, featureName: featureName, symbol: symbol)
            return .array(element)
        }
        if let ident = typeSyntax.as(IdentifierTypeSyntax.self) {
            let name = ident.name.text
            if name == "Optional", let arg = ident.genericArgumentClause?.arguments.first?.argument.as(TypeSyntax.self) {
                let wrapped = try parseType(arg, featureName: featureName, symbol: symbol)
                return .optional(wrapped)
            }
            if name == "Array", let arg = ident.genericArgumentClause?.arguments.first?.argument.as(TypeSyntax.self) {
                let element = try parseType(arg, featureName: featureName, symbol: symbol)
                return .array(element)
            }
            if let primitive = BridgePrimitive(rawValue: name) {
                return .primitive(primitive)
            }
            if ident.genericArgumentClause == nil {
                return .customStruct(name: name)
            }
        }
        throw BridgeGenError.unsupportedType(
            feature: featureName,
            symbol: symbol,
            typeName: typeSyntax.trimmedDescription
        )
    }

    private static func collectReferencedStructs(
        in type: BridgeType,
        available: [String: ValueStructSpec],
        into target: inout [String: ValueStructSpec],
        featureName: String
    ) throws {
        switch type {
        case .primitive:
            return
        case .optional(let inner), .array(let inner):
            try collectReferencedStructs(in: inner, available: available, into: &target, featureName: featureName)
        case .customStruct(let name):
            guard let spec = available[name] else {
                throw BridgeGenError.unresolvedStruct(feature: featureName, structName: name)
            }
            target[name] = spec
        }
    }
}
