### ADR-0017 코어와 공유 모듈에서 FoundationEssentials를 허용한다
- 상태: 기각 (범위를 샘플 데이터 계층으로 좁혀 ADR-0032로 채택)
- 날짜: 2026-11-15
- 배경: ADR-0004는 코어 `RIBs`에서 Foundation을 금지했다. 그 대가로 상태 저장용 값 열거형 `RibValue`와 JSON 인코더·디코더(`RibStateCodec`, 222줄)를 직접 유지한다. 값 종류를 열거형으로 나누는 모양은 Android `Bundle`을 흉내 낸 것인데, Swift에서는 `Codable`이 같은 일을 표준 방식으로 한다. Swift 6부터 swift-foundation의 `FoundationEssentials`(Codable JSON, `Data`, `Date` 등, 국제화·네트워크 제외)가 모든 플랫폼에서 같은 Swift 구현으로 제공되어, ADR-0004가 걱정한 "플랫폼마다 구현과 크기가 다르다"는 문제가 크게 줄었다.
- 결정:
  - `RIBs`와 샘플 공유 모듈 `LoginShared`는 `FoundationEssentials`를 쓸 수 있다. 가져오기는 `#if canImport(FoundationEssentials) import FoundationEssentials #else import Foundation #endif`로 한다. Apple 플랫폼에는 `FoundationEssentials` 모듈이 따로 없어 `Foundation`을 쓴다.
  - 국제화(`FoundationInternationalization`), 네트워크(`FoundationNetworking`), `Dispatch`, `Combine`은 여전히 코어에서 쓰지 않는다.
  - `AGENTS.md`의 Foundation 금지 규칙을 이에 맞게 고친다. ADR-0004가 말한 CI 검사는 저장소에 아직 없다. CI를 붙일 때 금지 목록을 위 기준으로 검사한다.
- 고려했던 대안:
  (1) ADR-0004 유지: 직접 짠 JSON 코덱과 값 열거형을 계속 유지해야 하고, 앱 개발자가 저장할 값을 열거형으로 손수 바꿔야 해서 기각했다.
  (2) Foundation 전체 허용: Apple 외 플랫폼에서 국제화 데이터(ICU)까지 딸려 와 바이너리가 커지고, Wasm에서는 일부가 빌드되지 않아 기각했다.
- Wasm 확인(2026-11-15, Windows 호스트, Swift 6.4.2, `swift-6.4.2-RELEASE_wasm`, Node WASI로 실행):
  - `canImport(FoundationEssentials)`가 참이고, 중첩 `Codable`·`Data`·`[String: T]`를 `JSONEncoder`(`.sortedKeys`)로 인코딩한 뒤 `JSONDecoder`로 되살리는 왕복이 같은 값을 돌려준다. 한글과 따옴표가 든 문자열도 그대로 돌아오고, 다른 타입으로 디코딩하면 실패해 `try?`가 `nil`이 된다.
  - 크기: 같은 크기의 프로그램을 `-c release -Xlinker --strip-all`로 빌드하면 Foundation 없이 5.55MB(gzip 1.61MB), `FoundationEssentials`의 JSON을 쓰면 12.76MB(gzip 3.66MB)다. 웹 첫 로딩에서 gzip 기준 약 2MB가 늘어난다. `wasm-opt`로 줄일 수 있는지는 확인하지 않았다.
- 결과: ADR-0018(Snapshot)이 `Codable`과 `JSONEncoder`를 쓸 수 있다. 웹 샘플은 바이너리가 약 2배가 되는 비용을 받아들인다. 채택되면 ADR-0004와 ADR-0008의 상태를 `대체됨`으로 바꾼다.
- 관련: ADR-0004, ADR-0008, ADR-0018
