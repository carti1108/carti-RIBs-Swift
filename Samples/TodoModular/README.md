# TodoModular (µFeature 샘플)

로그인 → 할 일 목록 → 상세 흐름을 피처마다 Interface·Impl·Testing 모듈로 나눈 샘플입니다(ADR-0024). RIB 트리와 데이터 계층은 공유 패키지 하나에 두고, iOS·웹·Android가 화면만 따로 그립니다.

| 위치 | 내용 |
|---|---|
| [Shared](Shared/Package.swift) | 공유 Swift 패키지. 피처 RIB, 루트(`TodoAppRoot`), 도메인(`TodoCore`), HTTP 데이터 계층(`TodoData`) |
| [iOS](iOS/README.md) | SwiftUI 앱(Tuist), 피처별 Example 앱, `URLSession` 전송 |
| [Web](Web/README.md) | Wasm + React 앱, 피처별 데모 페이지, `fetch` 전송 |
| [Android](Android/README.md) | Compose 앱, 피처별 데모 앱, `HttpURLConnection` 전송 |

## 공유 패키지

| 모듈 | 내용 |
|---|---|
| `FeatureXxxInterface` | 부모가 아는 것: 빌더 프로토콜, 리스너, 뷰 계약(상태·액션) |
| `FeatureXxx` | RIB 구현(Interactor·Router·Builder) |
| `FeatureXxxTesting` | 다른 피처 테스트가 쓰는 가짜 빌더와 뷰 |
| `TodoCore` | `Todo`, `TodoRepository`, `AuthService` 같은 도메인 타입. Foundation 없음 |
| `TodoData` | `HTTPTransport`, `TodoAPIClient`, `RemoteTodoRepository`, `BearerTokenTransport`. `FoundationEssentials`만 씀(ADR-0032) |
| `TodoAppRoot` | 피처를 조립하는 루트 RIB과 `TodoApp` |

```sh
cd Samples/TodoModular/Shared
swift build && swift test
```

## 할 일 API

`TodoData`는 `HTTPTransport` 프로토콜 하나로 요청을 보냅니다. 플랫폼마다 구현이 다릅니다(ADR-0033).

| 플랫폼 | 전송 | 서버를 주지 않으면 |
|---|---|---|
| iOS | `URLSessionHTTPTransport` | 앱 안의 샘플 서버 |
| 웹 | `fetch`(JavaScriptKit) | 같은 출처의 정적 JSON |
| Android | Kotlin `HttpUrlConnectionTransport`(swift-java) | 앱 안의 샘플 서버 |

- 쓰기 요청(추가·수정·삭제), Bearer 토큰, RFC 9457 Problem Details 오류 본문은 ADR-0034에 있습니다.
- 전송을 `BearerTokenTransport`로 감싸면 401을 받았을 때 토큰을 한 번 갱신해 다시 보냅니다. 그래도 401이면 목록이 로그인 화면으로 돌아가게 합니다(ADR-0036). 샘플 앱은 토큰을 쓰지 않아 감싸지 않습니다.
- 서버에 닿지 못하거나 CORS로 막히면 `unreachable`입니다. 웹에서 CORS 실패와 네트워크 실패는 구분되지 않습니다([빌드 문서](../../docs/building.md)).

## 새 피처 만들기

`new-rib` 플러그인의 `--feature`가 이 구조대로 Interface·Impl·Testing·Tests를 만들고, `--android`·`--web`이 플랫폼 연결 코드를 만듭니다([저장소 README](../../README.md#새-rib-만들기), ADR-0029, ADR-0031). 모듈 경계는 `scripts/check-sample-boundaries.sh`가 검사합니다(ADR-0028).
