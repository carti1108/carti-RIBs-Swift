public enum BridgePrimitive: String, Equatable, Sendable {
    case bool = "Bool"
    case int = "Int"
    case int64 = "Int64"
    case double = "Double"
    case string = "String"
}

public indirect enum BridgeType: Equatable, Sendable {
    case primitive(BridgePrimitive)
    case optional(BridgeType)
    case array(BridgeType)
    case named(String)
}

public struct ValueField: Equatable, Sendable {
    public let name: String
    public let type: BridgeType

    public init(name: String, type: BridgeType) {
        self.name = name
        self.type = type
    }
}

public struct EnumParam: Equatable, Sendable {
    public let label: String?
    public let name: String
    public let type: BridgeType

    public init(label: String?, name: String, type: BridgeType) {
        self.label = label
        self.name = name
        self.type = type
    }
}

public struct EnumCaseSpec: Equatable, Sendable {
    public let name: String
    public let params: [EnumParam]

    public init(name: String, params: [EnumParam] = []) {
        self.name = name
        self.params = params
    }
}

public struct StructSpec: Equatable, Sendable {
    public let fullName: String
    public let simpleName: String
    public let fields: [ValueField]

    public init(fullName: String, simpleName: String, fields: [ValueField]) {
        self.fullName = fullName
        self.simpleName = simpleName
        self.fields = fields
    }
}

public struct EnumSpec: Equatable, Sendable {
    public let fullName: String
    public let simpleName: String
    public let cases: [EnumCaseSpec]

    public var isSimple: Bool {
        cases.allSatisfy { $0.params.isEmpty }
    }

    public init(fullName: String, simpleName: String, cases: [EnumCaseSpec]) {
        self.fullName = fullName
        self.simpleName = simpleName
        self.cases = cases
    }
}

public enum NamedTypeSpec: Equatable, Sendable {
    case `struct`(StructSpec)
    case `enum`(EnumSpec)

    public var fullName: String {
        switch self {
        case .struct(let s): return s.fullName
        case .enum(let e): return e.fullName
        }
    }

    public var simpleName: String {
        switch self {
        case .struct(let s): return s.simpleName
        case .enum(let e): return e.simpleName
        }
    }
}

public struct FeatureSpec: Equatable, Sendable {
    public let featureName: String
    public let interfaceModule: String
    public let stateTypeName: String
    public let actionTypeName: String
    public let stateFields: [ValueField]
    public let actions: [EnumCaseSpec]
    public let hasChildSlots: Bool

    public init(
        featureName: String,
        interfaceModule: String,
        stateTypeName: String,
        actionTypeName: String,
        stateFields: [ValueField],
        actions: [EnumCaseSpec],
        hasChildSlots: Bool
    ) {
        self.featureName = featureName
        self.interfaceModule = interfaceModule
        self.stateTypeName = stateTypeName
        self.actionTypeName = actionTypeName
        self.stateFields = stateFields
        self.actions = actions
        self.hasChildSlots = hasChildSlots
    }
}

public struct BridgeSchema: Equatable, Sendable {
    public let features: [FeatureSpec]
    public let namedTypes: [String: NamedTypeSpec]
    public let orderedTypeNames: [String]
    public let importedModules: [String]

    public init(
        features: [FeatureSpec],
        namedTypes: [String: NamedTypeSpec],
        orderedTypeNames: [String],
        importedModules: [String]
    ) {
        self.features = features
        self.namedTypes = namedTypes
        self.orderedTypeNames = orderedTypeNames
        self.importedModules = importedModules
    }
}

public enum BridgeGenError: Error, Equatable, CustomStringConvertible {
    case missingViewState(feature: String)
    case missingViewAction(feature: String)
    case unsupportedType(context: String, typeName: String)
    case unresolvedType(context: String, typeName: String)

    public var description: String {
        switch self {
        case .missingViewState(let feature):
            return "\(feature): \(feature)ViewState struct를 찾을 수 없습니다."
        case .missingViewAction(let feature):
            return "\(feature): \(feature)ViewAction enum을 찾을 수 없습니다."
        case .unsupportedType(let context, let typeName):
            return "\(context): 지원하지 않는 경계 타입 '\(typeName)'"
        case .unresolvedType(let context, let typeName):
            return "\(context): 타입 '\(typeName)' 정의를 찾을 수 없습니다."
        }
    }
}
