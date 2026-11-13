/// `RibState`에 넣을 수 있는 값. 프로세스 재시작 뒤에도 문자열로 되살릴 수 있는 타입만 둔다.
public enum RibValue: Hashable, Sendable {
    case string(String)
    case int(Int64)
    /// 유한값만 허용한다. NaN·무한대를 넣은 `RibState`는 만들 수 없다.
    case double(Double)
    case bool(Bool)
    case null
    case list([RibValue])
    case state(RibState)

    public var stringValue: String? { if case .string(let value) = self { value } else { nil } }
    public var intValue: Int64? { if case .int(let value) = self { value } else { nil } }
    public var doubleValue: Double? { if case .double(let value) = self { value } else { nil } }
    public var boolValue: Bool? { if case .bool(let value) = self { value } else { nil } }
    public var listValue: [RibValue]? { if case .list(let value) = self { value } else { nil } }
    public var stateValue: RibState? { if case .state(let value) = self { value } else { nil } }

    var isEncodable: Bool {
        switch self {
        case .double(let value): value.isFinite
        case .list(let items): items.allSatisfy(\.isEncodable)
        default: true
        }
    }
}

/// Android `Bundle`을 대신하는 읽기 전용 저장 상태.
/// 플랫폼은 `encodedString()`으로 얻은 문자열 하나만 저장하고 `init(decoding:)`으로 되살린다.
public struct RibState: Hashable, Sendable, CustomStringConvertible {
    private let values: [String: RibValue]

    /// 값에 NaN·무한대 `Double`이 있으면 실패한다.
    public init(_ values: [String: RibValue] = [:]) {
        for (key, value) in values {
            precondition(value.isEncodable, "RibState value for '\(key)' contains a non-finite Double")
        }
        self.values = values
    }

    /// `encodedString()`이 만든 문자열을 되살린다.
    public init(decoding encoded: String) throws(RibStateDecodingError) {
        self.init(try RibStateCodec.decode(encoded))
    }

    public subscript(key: String) -> RibValue? { values[key] }

    public func contains(_ key: String) -> Bool { values[key] != nil }

    public var keys: [String] { values.keys.sorted() }

    /// 플랫폼 저장소에 넣을 JSON 형식 문자열. 키는 정렬해 결정적으로 만든다.
    public func encodedString() -> String { RibStateCodec.encode(values) }

    public var description: String { "RibState(\(encodedString()))" }
}

/// `RibState(decoding:)` 실패. `offset`은 입력의 유니코드 스칼라 위치다.
public struct RibStateDecodingError: Error, Equatable, Sendable {
    public let message: String
    public let offset: Int
}
