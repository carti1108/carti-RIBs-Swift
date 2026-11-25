#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// RFC 9457 Problem Details. 오류 응답 본문에서 표준 멤버만 읽고 확장 멤버는 버린다.
public struct ProblemDetails: Equatable, Sendable, Decodable {
    /// 문제 종류를 가리키는 URI. 본문에 없으면 RFC 9457 §3.1.1에 따라 `about:blank`다.
    public let type: String
    public let title: String?
    public let status: Int?
    public let detail: String?
    public let instance: String?

    public init(
        type: String = "about:blank",
        title: String? = nil,
        status: Int? = nil,
        detail: String? = nil,
        instance: String? = nil
    ) {
        self.type = type
        self.title = title
        self.status = status
        self.detail = detail
        self.instance = instance
    }

    private enum CodingKeys: String, CodingKey {
        case type, title, status, detail, instance
    }

    /// 본문이 JSON 객체가 아니면 던진다. 멤버의 타입이 틀리면 그 멤버만 없는 것으로 본다(RFC 9457 §3.1).
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func member<T: Decodable>(_ type: T.Type, _ key: CodingKeys) -> T? {
            (try? container.decodeIfPresent(type, forKey: key)) ?? nil
        }
        self.init(
            type: member(String.self, .type) ?? "about:blank",
            title: member(String.self, .title),
            status: member(Int.self, .status),
            detail: member(String.self, .detail),
            instance: member(String.self, .instance)
        )
    }

    /// 본문이 JSON 객체면 읽는다. 비었거나 객체가 아니면(HTML 오류 페이지, 배열) nil이다.
    /// 전송 계층이 응답 헤더를 넘기지 않아 `Content-Type: application/problem+json`은 확인하지 않는다.
    static func decode(from body: [UInt8]) -> ProblemDetails? {
        guard !body.isEmpty else { return nil }
        return try? JSONDecoder().decode(ProblemDetails.self, from: Data(body))
    }
}
