import SwiftParser
import SwiftSyntax

public struct FeatureInput: Sendable {
    public let featureName: String
    public let interfaceModule: String
    public let interfaceSource: String

    public init(featureName: String, interfaceModule: String, interfaceSource: String) {
        self.featureName = featureName
        self.interfaceModule = interfaceModule
        self.interfaceSource = interfaceSource
    }
}

public enum ContractParser {
    public static func parseSchema(
        features inputs: [FeatureInput],
        modelSources: [String],
        extraImports: [String] = []
    ) throws -> BridgeSchema {
        var rawTypes: [String: NamedTypeSpec] = [:]
        var imports: Set<String> = Set(extraImports)

        for source in modelSources {
            let tree = Parser.parse(source: source)
            collectImports(from: tree, into: &imports)
            try collectNamedTypes(in: tree.statements, scope: [], into: &rawTypes)
        }

        var parsedFeatures: [FeatureSpec] = []
        for input in inputs {
            let tree = Parser.parse(source: input.interfaceSource)
            collectImports(from: tree, into: &imports)
            imports.insert(input.interfaceModule)
            try collectNamedTypes(in: tree.statements, scope: [], into: &rawTypes)

            let stateName = "\(input.featureName)ViewState"
            let actionName = "\(input.featureName)ViewAction"
            let controllableName = "\(input.featureName)ViewControllable"

            guard case .struct(let stateSpec) = rawTypes[stateName] else {
                throw BridgeGenError.missingViewState(feature: input.featureName)
            }
            guard case .enum(let actionSpec) = rawTypes[actionName] else {
                throw BridgeGenError.missingViewAction(feature: input.featureName)
            }

            let hasChildSlots = findProtocol(named: controllableName, in: tree.statements)?
                .memberBlock.members.contains { $0.decl.is(FunctionDeclSyntax.self) } ?? false

            let resolvedFields = try stateSpec.fields.map { field in
                ValueField(
                    name: field.name,
                    type: try resolveType(
                        field.type,
                        scope: [stateName],
                        available: rawTypes,
                        context: "\(input.featureName).\(field.name)"
                    )
                )
            }

            let resolvedActions = try actionSpec.cases.map { c in
                EnumCaseSpec(
                    name: c.name,
                    params: try c.params.map { p in
                        EnumParam(
                            label: p.label,
                            name: p.name,
                            type: try resolveType(
                                p.type,
                                scope: [actionName],
                                available: rawTypes,
                                context: "\(input.featureName).\(c.name).\(p.name)"
                            )
                        )
                    }
                )
            }

            parsedFeatures.append(FeatureSpec(
                featureName: input.featureName,
                interfaceModule: input.interfaceModule,
                stateTypeName: stateName,
                actionTypeName: actionName,
                stateFields: resolvedFields,
                actions: resolvedActions,
                hasChildSlots: hasChildSlots
            ))
        }

        // Collect transitive dependencies from all feature stateFields and actions
        var usedTypes: [String: NamedTypeSpec] = [:]
        var orderedNames: [String] = []
        var visiting: Set<String> = []

        func visitType(_ type: BridgeType, context: String) throws {
            switch type {
            case .primitive:
                return
            case .optional(let inner), .array(let inner):
                try visitType(inner, context: context)
            case .named(let fullName):
                if usedTypes[fullName] != nil || visiting.contains(fullName) { return }
                guard let spec = rawTypes[fullName] else {
                    throw BridgeGenError.unresolvedType(context: context, typeName: fullName)
                }
                visiting.insert(fullName)
                let scope = fullName.split(separator: ".").map(String.init)
                let resolvedSpec: NamedTypeSpec
                switch spec {
                case .struct(let s):
                    let fields = try s.fields.map { f -> ValueField in
                        let resolved = try resolveType(f.type, scope: scope, available: rawTypes, context: "\(fullName).\(f.name)")
                        try visitType(resolved, context: "\(fullName).\(f.name)")
                        return ValueField(name: f.name, type: resolved)
                    }
                    resolvedSpec = .struct(StructSpec(fullName: s.fullName, simpleName: s.simpleName, fields: fields))
                case .enum(let e):
                    let cases = try e.cases.map { c -> EnumCaseSpec in
                        let params = try c.params.map { p -> EnumParam in
                            let resolved = try resolveType(p.type, scope: scope, available: rawTypes, context: "\(fullName).\(c.name).\(p.name)")
                            try visitType(resolved, context: "\(fullName).\(c.name).\(p.name)")
                            return EnumParam(label: p.label, name: p.name, type: resolved)
                        }
                        return EnumCaseSpec(name: c.name, params: params)
                    }
                    resolvedSpec = .enum(EnumSpec(fullName: e.fullName, simpleName: e.simpleName, cases: cases))
                }
                visiting.remove(fullName)
                usedTypes[fullName] = resolvedSpec
                orderedNames.append(fullName)
            }
        }

        for feature in parsedFeatures {
            for field in feature.stateFields {
                try visitType(field.type, context: "\(feature.stateTypeName).\(field.name)")
            }
            for action in feature.actions {
                for param in action.params {
                    try visitType(param.type, context: "\(feature.actionTypeName).\(action.name).\(param.name)")
                }
            }
        }

        imports.remove("RIBs")
        return BridgeSchema(
            features: parsedFeatures,
            namedTypes: usedTypes,
            orderedTypeNames: orderedNames,
            importedModules: imports.sorted()
        )
    }

    private static func collectImports(from tree: SourceFileSyntax, into imports: inout Set<String>) {
        for item in tree.statements {
            if let importDecl = item.item.as(ImportDeclSyntax.self),
               let first = importDecl.path.first?.name.text {
                imports.insert(first)
            }
        }
    }

    private static func findProtocol(named name: String, in statements: CodeBlockItemListSyntax) -> ProtocolDeclSyntax? {
        for item in statements {
            if let proto = item.item.as(ProtocolDeclSyntax.self), proto.name.text == name {
                return proto
            }
        }
        return nil
    }

    private static func collectNamedTypes(
        in statements: CodeBlockItemListSyntax,
        scope: [String],
        into target: inout [String: NamedTypeSpec]
    ) throws {
        for item in statements {
            try collectDecl(Syntax(item.item), scope: scope, into: &target)
        }
    }

    private static func collectMemberTypes(
        in members: MemberBlockItemListSyntax,
        scope: [String],
        into target: inout [String: NamedTypeSpec]
    ) throws {
        for member in members {
            try collectDecl(Syntax(member.decl), scope: scope, into: &target)
        }
    }

    private static func collectDecl(
        _ syntax: Syntax,
        scope: [String],
        into target: inout [String: NamedTypeSpec]
    ) throws {
        if let structDecl = syntax.as(StructDeclSyntax.self) {
            let name = structDecl.name.text
            let fullName = (scope + [name]).joined(separator: ".")
            let fields = try parseStructFields(structDecl, context: fullName)
            target[fullName] = .struct(StructSpec(fullName: fullName, simpleName: name, fields: fields))
            try collectMemberTypes(in: structDecl.memberBlock.members, scope: scope + [name], into: &target)
        } else if let enumDecl = syntax.as(EnumDeclSyntax.self) {
            let name = enumDecl.name.text
            let fullName = (scope + [name]).joined(separator: ".")
            let cases = try parseEnumCases(enumDecl, context: fullName)
            target[fullName] = .enum(EnumSpec(fullName: fullName, simpleName: name, cases: cases))
            try collectMemberTypes(in: enumDecl.memberBlock.members, scope: scope + [name], into: &target)
        }
    }

    private static func parseStructFields(
        _ structDecl: StructDeclSyntax,
        context: String
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
                let type = try parseSyntaxType(typeSyntax, context: "\(context).\(name)")
                fields.append(ValueField(name: name, type: type))
            }
        }
        return fields
    }

    private static func parseEnumCases(
        _ enumDecl: EnumDeclSyntax,
        context: String
    ) throws -> [EnumCaseSpec] {
        var cases: [EnumCaseSpec] = []
        for member in enumDecl.memberBlock.members {
            guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else { continue }
            for element in caseDecl.elements {
                let caseName = element.name.text
                var params: [EnumParam] = []
                if let paramList = element.parameterClause?.parameters {
                    for (idx, param) in paramList.enumerated() {
                        let rawFirst = param.firstName?.text
                        let rawSecond = param.secondName?.text
                        let label: String? = (rawFirst == "_" || rawFirst == nil) ? nil : rawFirst
                        let paramName = rawSecond ?? (rawFirst == "_" ? nil : rawFirst) ?? (paramList.count == 1 ? "value" : "arg\(idx)")
                        let type = try parseSyntaxType(param.type, context: "\(context).\(caseName).\(paramName)")
                        params.append(EnumParam(label: label, name: paramName, type: type))
                    }
                }
                cases.append(EnumCaseSpec(name: caseName, params: params))
            }
        }
        return cases
    }

    private static func parseSyntaxType(_ typeSyntax: TypeSyntax, context: String) throws -> BridgeType {
        if let opt = typeSyntax.as(OptionalTypeSyntax.self) {
            return .optional(try parseSyntaxType(opt.wrappedType, context: context))
        }
        if let arr = typeSyntax.as(ArrayTypeSyntax.self) {
            return .array(try parseSyntaxType(arr.element, context: context))
        }
        if let ident = typeSyntax.as(IdentifierTypeSyntax.self) {
            let name = ident.name.text
            if name == "Optional", let arg = ident.genericArgumentClause?.arguments.first?.argument.as(TypeSyntax.self) {
                return .optional(try parseSyntaxType(arg, context: context))
            }
            if name == "Array", let arg = ident.genericArgumentClause?.arguments.first?.argument.as(TypeSyntax.self) {
                return .array(try parseSyntaxType(arg, context: context))
            }
            if let primitive = BridgePrimitive(rawValue: name) {
                return .primitive(primitive)
            }
            if ident.genericArgumentClause == nil {
                return .named(name)
            }
        }
        if let member = typeSyntax.as(MemberTypeSyntax.self) {
            return .named(member.trimmedDescription)
        }
        throw BridgeGenError.unsupportedType(context: context, typeName: typeSyntax.trimmedDescription)
    }

    private static func resolveType(
        _ type: BridgeType,
        scope: [String],
        available: [String: NamedTypeSpec],
        context: String
    ) throws -> BridgeType {
        switch type {
        case .primitive:
            return type
        case .optional(let inner):
            return .optional(try resolveType(inner, scope: scope, available: available, context: context))
        case .array(let inner):
            return .array(try resolveType(inner, scope: scope, available: available, context: context))
        case .named(let rawName):
            for end in stride(from: scope.count, through: 0, by: -1) {
                let candidate = (Array(scope.prefix(end)) + [rawName]).joined(separator: ".")
                if available[candidate] != nil {
                    return .named(candidate)
                }
            }
            throw BridgeGenError.unresolvedType(context: context, typeName: rawName)
        }
    }
}
