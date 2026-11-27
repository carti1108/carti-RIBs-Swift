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
    case customStruct(name: String)
}

public struct ValueField: Equatable, Sendable {
    public let name: String
    public let type: BridgeType

    public init(name: String, type: BridgeType) {
        self.name = name
        self.type = type
    }
}

public struct ValueStructSpec: Equatable, Sendable {
    public let name: String
    public let fields: [ValueField]

    public init(name: String, fields: [ValueField]) {
        self.name = name
        self.fields = fields
    }
}

public struct ActionParam: Equatable, Sendable {
    public let label: String?
    public let name: String
    public let type: BridgeType

    public init(label: String?, name: String, type: BridgeType) {
        self.label = label
        self.name = name
        self.type = type
    }
}

public struct ActionCase: Equatable, Sendable {
    public let name: String
    public let params: [ActionParam]

    public init(name: String, params: [ActionParam] = []) {
        self.name = name
        self.params = params
    }
}

public struct FeatureBridgeSpec: Equatable, Sendable {
    public let featureName: String
    public let stateFields: [ValueField]
    public let actions: [ActionCase]
    public let hasChildSlots: Bool
    public let referencedStructs: [String: ValueStructSpec]

    public init(
        featureName: String,
        stateFields: [ValueField],
        actions: [ActionCase],
        hasChildSlots: Bool,
        referencedStructs: [String: ValueStructSpec] = [:]
    ) {
        self.featureName = featureName
        self.stateFields = stateFields
        self.actions = actions
        self.hasChildSlots = hasChildSlots
        self.referencedStructs = referencedStructs
    }
}

public enum BridgeGenError: Error, Equatable, CustomStringConvertible {
    case missingViewState(feature: String)
    case missingViewAction(feature: String)
    case unsupportedType(feature: String, symbol: String, typeName: String)
    case unresolvedStruct(feature: String, structName: String)

    public var description: String {
        switch self {
        case .missingViewState(let feature):
            return "\(feature): \(feature)ViewState struct를 찾을 수 없습니다."
        case .missingViewAction(let feature):
            return "\(feature): \(feature)ViewAction enum을 찾을 수 없습니다."
        case .unsupportedType(let feature, let symbol, let typeName):
            return "\(feature).\(symbol): 지원하지 않는 경계 타입 '\(typeName)'"
        case .unresolvedStruct(let feature, let structName):
            return "\(feature): 외부 모델 struct '\(structName)' 정의를 찾을 수 없습니다."
        }
    }
}

public struct DriftIssue: Equatable, Sendable, CustomStringConvertible {
    public let platform: String
    public let feature: String
    public let kind: String
    public let symbol: String

    public init(platform: String, feature: String, kind: String, symbol: String) {
        self.platform = platform
        self.feature = feature
        self.kind = kind
        self.symbol = symbol
    }

    public var description: String {
        "[\(platform)] \(feature): 누락된 \(kind) '\(symbol)'"
    }
}
