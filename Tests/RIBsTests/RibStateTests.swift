import Testing
@testable import RIBs

/// `%u`를 JSON 유니코드 이스케이프(백슬래시 u)로 바꾼다. 소스에 이스케이프를 그대로 적지 않으려는 용도.
private func json(_ template: String) -> String {
    template.replacing("%u", with: "\\" + "u")
}

struct RibStateTests {
    @Test func encodeThenDecode_restoresEveryAllowedType() throws {
        // Given
        let nested = RibState(["inner": .string("x"), "n": .int(-3)])
        let state = RibState([
            "string": .string("hello \"quoted\" \\ / \n\r\t \u{01} 한글 😀"),
            "int": .int(42),
            "intMin": .int(.min),
            "intMax": .int(.max),
            "double": .double(1.5),
            "wholeDouble": .double(2),
            "tinyDouble": .double(1e-7),
            "hugeDouble": .double(.greatestFiniteMagnitude),
            "negativeZero": .double(-0.0),
            "bool": .bool(true),
            "false": .bool(false),
            "null": .null,
            "list": .list([.int(1), .string("two"), .list([]), .state(nested), .null]),
            "state": .state(nested),
            "": .string(""),
        ])

        // When
        let decoded = try RibState(decoding: state.encodedString())

        // Then
        #expect(decoded == state)
        #expect(decoded["wholeDouble"] == .double(2))
        #expect(decoded["int"] == .int(42))
    }

    @Test func emptyState_roundTrips() throws {
        // Given
        let state = RibState()

        // When
        let encoded = state.encodedString()

        // Then
        #expect(encoded == "{}")
        #expect(try RibState(decoding: encoded) == state)
    }

    @Test func encodedString_sortsKeysDeterministically() {
        // Given
        let state = RibState(["b": .int(1), "a": .int(2), "c": .state(RibState(["z": .null, "y": .bool(false)]))])

        // When / Then
        #expect(state.encodedString() == #"{"a":2,"b":1,"c":{"y":false,"z":null}}"#)
        #expect(state.keys == ["a", "b", "c"])
    }

    @Test func encodedString_marksWholeDoubleAsDecimal() {
        #expect(RibState(["d": .double(2)]).encodedString() == #"{"d":2.0}"#)
        #expect(RibState(["d": .int(2)]).encodedString() == #"{"d":2}"#)
    }

    @Test func encodedString_escapesControlCharacters() {
        #expect(RibState(["s": .string("\u{01}\u{1F}")]).encodedString() == json(#"{"s":"%u0001%u001f"}"#))
    }

    @Test func equality_comparesValuesAndKeepsIntAndDoubleApart() {
        #expect(RibState(["a": .int(1)]) == RibState(["a": .int(1)]))
        #expect(RibState(["a": .int(1)]) != RibState(["a": .double(1)]))
        #expect(RibState(["a": .int(1)]) != RibState(["a": .int(2)]))
        #expect(RibState(["a": .null]) != RibState())
    }

    @Test func accessors_returnValueOnlyForMatchingCase() {
        // Given
        let nested = RibState(["k": .int(1)])

        // When / Then
        #expect(RibValue.string("s").stringValue == "s")
        #expect(RibValue.int(1).intValue == 1)
        #expect(RibValue.double(1).doubleValue == 1)
        #expect(RibValue.bool(true).boolValue == true)
        #expect(RibValue.list([.null]).listValue == [.null])
        #expect(RibValue.state(nested).stateValue == nested)
        #expect(RibValue.int(1).stringValue == nil)
        #expect(RibValue.null.intValue == nil)
        #expect(RibValue.string("1").doubleValue == nil)
        #expect(RibValue.int(0).boolValue == nil)
        #expect(RibValue.null.listValue == nil)
        #expect(RibValue.null.stateValue == nil)
    }

    @Test func subscriptAndContains_reflectStoredKeys() {
        // Given
        let state = RibState(["present": .null])

        // When / Then
        #expect(state.contains("present"))
        #expect(state["present"] == .null)
        #expect(!state.contains("missing"))
        #expect(state["missing"] == nil)
    }

    @Test func description_wrapsEncodedString() {
        #expect(RibState(["a": .int(1)]).description == #"RibState({"a":1})"#)
    }

    @Test(arguments: [
        (#" { "a" : [ 1 , 2.5 ] , "b" : true } "#, RibState(["a": .list([.int(1), .double(2.5)]), "b": .bool(true)])),
        (#"{"s":"\/%u00e9%ud83d%ude00"}"#, RibState(["s": .string("/é😀")])),
        (#"{"e":1e3,"E":-2E-2}"#, RibState(["e": .double(1000), "E": .double(-0.02)])),
        (#"{"a":1,"a":2}"#, RibState(["a": .int(2)])),
        (#"{"z":"%u0000"}"#, RibState(["z": .string("\u{0}")])),
    ])
    func decode_acceptsValidJSON(input: String, expected: RibState) throws {
        #expect(try RibState(decoding: json(input)) == expected)
    }

    @Test(arguments: [
        ("", "Expected '{'", 0),
        ("[1]", "Expected '{'", 0),
        (#"{"a":"#, "Unexpected end of input", 5),
        (#"{"a":1"#, "Expected '}'", 6),
        (#"{"a":1} extra"#, "Unexpected trailing characters", 8),
        (#"{"a":1,}"#, "Expected '\"'", 7),
        (#"{a:1}"#, "Expected '\"'", 1),
        (#"{"a" 1}"#, "Expected ':'", 5),
        (#"{"a":tru}"#, "Invalid literal", 5),
        (#"{"a":@}"#, "Unexpected '@'", 5),
        (#"{"a":1.2.3}"#, "Invalid number '1.2.3'", 5),
        (#"{"a":1e999}"#, "Invalid number '1e999'", 5),
        (#"{"a":9223372036854775808}"#, "Invalid number '9223372036854775808'", 5),
        (#"{"a":-}"#, "Invalid number '-'", 5),
        (#"{"a":"abc}"#, "Unterminated string", 10),
        (#"{"a":"\x"}"#, "Invalid escape '\\x'", 8),
        (#"{"a":"%u12"}"#, "Invalid unicode escape", 8),
        (#"{"a":"%uD800"}"#, "Unpaired surrogate", 12),
        (#"{"a":"%uD800%u0041"}"#, "Invalid surrogate pair", 18),
        (#"{"a":"%uDC00"}"#, "Invalid unicode escape", 12),
        (#"{"a":[1,2}"#, "Expected ']'", 9),
        (#"{"😀":x}"#, "Unexpected 'x'", 5),
    ])
    func decode_rejectsMalformedInputWithScalarOffset(input: String, message: String, offset: Int) {
        #expect(throws: RibStateDecodingError(message: message, offset: offset)) {
            try RibState(decoding: json(input))
        }
    }
}
