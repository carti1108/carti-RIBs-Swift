/// `RibState`를 JSON 문자열로 바꾸고 되살린다. Foundation 없이 표준 라이브러리만 쓴다.
/// 정수는 `.int`, 소수점이나 지수가 있는 수는 `.double`로 읽는다.
enum RibStateCodec {
    static func encode(_ values: [String: RibValue]) -> String {
        var output = ""
        writeObject(values, to: &output)
        return output
    }

    static func decode(_ encoded: String) throws(RibStateDecodingError) -> [String: RibValue] {
        var reader = Reader(encoded)
        let result = try reader.readObject()
        reader.skipWhitespace()
        guard reader.isAtEnd else { throw reader.error("Unexpected trailing characters") }
        return result
    }

    private static func writeObject(_ values: [String: RibValue], to output: inout String) {
        output.append("{")
        for (index, key) in values.keys.sorted().enumerated() {
            if index > 0 { output.append(",") }
            writeString(key, to: &output)
            output.append(":")
            writeValue(values[key] ?? .null, to: &output)
        }
        output.append("}")
    }

    private static func writeValue(_ value: RibValue, to output: inout String) {
        switch value {
        case .null: output.append("null")
        case .string(let text): writeString(text, to: &output)
        case .bool(let flag): output.append(flag ? "true" : "false")
        case .int(let number): output.append(String(number))
        case .double(let number): output.append(encodeDouble(number))
        case .state(let state): writeObject(Dictionary(uniqueKeysWithValues: state.keys.map { ($0, state[$0] ?? .null) }), to: &output)
        case .list(let items):
            output.append("[")
            for (index, item) in items.enumerated() {
                if index > 0 { output.append(",") }
                writeValue(item, to: &output)
            }
            output.append("]")
        }
    }

    /// 다시 읽을 때 `.double`이 되도록 소수점이나 지수가 없으면 `.0`을 붙인다.
    private static func encodeDouble(_ value: Double) -> String {
        let text = String(value)
        return text.contains(where: { $0 == "." || $0 == "e" || $0 == "E" }) ? text : text + ".0"
    }

    private static func writeString(_ text: String, to output: inout String) {
        output.append("\"")
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": output.append("\\\"")
            case "\\": output.append("\\\\")
            case "\n": output.append("\\n")
            case "\r": output.append("\\r")
            case "\t": output.append("\\t")
            default:
                if scalar.value < 0x20 {
                    let hex = String(scalar.value, radix: hexRadix)
                    output.append("\\u" + String(repeating: "0", count: unicodeDigits - hex.count) + hex)
                } else {
                    output.unicodeScalars.append(scalar)
                }
            }
        }
        output.append("\"")
    }

    static let hexRadix = 16
    static let unicodeDigits = 4
}

private struct Reader {
    private let scalars: [Unicode.Scalar]
    private(set) var position = 0

    init(_ text: String) {
        scalars = Array(text.unicodeScalars)
    }

    var isAtEnd: Bool { position >= scalars.count }

    func error(_ message: String) -> RibStateDecodingError {
        RibStateDecodingError(message: message, offset: position)
    }

    mutating func readObject() throws(RibStateDecodingError) -> [String: RibValue] {
        try expect("{")
        var result: [String: RibValue] = [:]
        if consumeIf("}") { return result }
        repeat {
            skipWhitespace()
            let key = try readString()
            try expect(":")
            result[key] = try readValue()
        } while consumeIf(",")
        try expect("}")
        return result
    }

    private mutating func readValue() throws(RibStateDecodingError) -> RibValue {
        skipWhitespace()
        guard !isAtEnd else { throw error("Unexpected end of input") }
        let scalar = scalars[position]
        switch scalar {
        case "{": return .state(RibState(try readObject()))
        case "[": return .list(try readList())
        case "\"": return .string(try readString())
        case "t": return try readLiteral("true", .bool(true))
        case "f": return try readLiteral("false", .bool(false))
        case "n": return try readLiteral("null", .null)
        default:
            guard scalar == "-" || scalar.properties.numericType == .decimal else {
                throw error("Unexpected '\(scalar)'")
            }
            return try readNumber()
        }
    }

    private mutating func readList() throws(RibStateDecodingError) -> [RibValue] {
        try expect("[")
        var result: [RibValue] = []
        if consumeIf("]") { return result }
        repeat { result.append(try readValue()) } while consumeIf(",")
        try expect("]")
        return result
    }

    private mutating func readString() throws(RibStateDecodingError) -> String {
        try expect("\"")
        var result = String.UnicodeScalarView()
        while true {
            guard !isAtEnd else { throw error("Unterminated string") }
            let scalar = scalars[position]
            position += 1
            switch scalar {
            case "\"": return String(result)
            case "\\": result.append(try readEscape())
            default: result.append(scalar)
            }
        }
    }

    private mutating func readEscape() throws(RibStateDecodingError) -> Unicode.Scalar {
        guard !isAtEnd else { throw error("Unterminated escape") }
        let scalar = scalars[position]
        position += 1
        switch scalar {
        case "\"", "\\", "/": return scalar
        case "n": return "\n"
        case "r": return "\r"
        case "t": return "\t"
        case "u":
            let high = try readHex4()
            guard (0xD800...0xDBFF).contains(high) else {
                guard let decoded = Unicode.Scalar(high) else { throw error("Invalid unicode escape") }
                return decoded
            }
            guard consumeExact("\\u") else { throw error("Unpaired surrogate") }
            let low = try readHex4()
            guard (0xDC00...0xDFFF).contains(low),
                  let decoded = Unicode.Scalar(0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00))
            else { throw error("Invalid surrogate pair") }
            return decoded
        default:
            throw error("Invalid escape '\\\(scalar)'")
        }
    }

    private mutating func readHex4() throws(RibStateDecodingError) -> UInt32 {
        let digits = RibStateCodec.unicodeDigits
        guard position + digits <= scalars.count,
              let code = UInt32(String(String.UnicodeScalarView(scalars[position..<position + digits])), radix: RibStateCodec.hexRadix)
        else { throw error("Invalid unicode escape") }
        position += digits
        return code
    }

    private mutating func readNumber() throws(RibStateDecodingError) -> RibValue {
        let start = position
        while !isAtEnd, "+-0123456789.eE".unicodeScalars.contains(scalars[position]) { position += 1 }
        let token = String(String.UnicodeScalarView(scalars[start..<position]))
        let isDecimal = token.contains { $0 == "." || $0 == "e" || $0 == "E" }
        if isDecimal, let value = Double(token), value.isFinite { return .double(value) }
        if !isDecimal, let value = Int64(token) { return .int(value) }
        throw RibStateDecodingError(message: "Invalid number '\(token)'", offset: start)
    }

    private mutating func readLiteral(_ literal: String, _ value: RibValue) throws(RibStateDecodingError) -> RibValue {
        guard consumeExact(literal) else { throw error("Invalid literal") }
        return value
    }

    private mutating func consumeExact(_ literal: String) -> Bool {
        let expected = Array(literal.unicodeScalars)
        guard position + expected.count <= scalars.count,
              Array(scalars[position..<position + expected.count]) == expected
        else { return false }
        position += expected.count
        return true
    }

    mutating func skipWhitespace() {
        while !isAtEnd, scalars[position].properties.isWhitespace { position += 1 }
    }

    private mutating func consumeIf(_ scalar: Unicode.Scalar) -> Bool {
        skipWhitespace()
        guard !isAtEnd, scalars[position] == scalar else { return false }
        position += 1
        return true
    }

    private mutating func expect(_ scalar: Unicode.Scalar) throws(RibStateDecodingError) {
        guard consumeIf(scalar) else { throw error("Expected '\(scalar)'") }
    }
}
