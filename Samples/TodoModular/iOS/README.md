# TodoModular iOS 앱 (SwiftUI)

µFeature 샘플([개요](../README.md))의 iOS 앱입니다. 공유 패키지(`../Shared`)의 RIB 트리를 SwiftUI로 그리는 Tuist 프로젝트입니다.

## 구조

| 위치 | 내용 |
|---|---|
| `Features/<피처>/UI` | 순수 SwiftUI 뷰. 값과 콜백만 받습니다(ADR-0027) |
| `Features/<피처>/Adapter` | 뷰 계약을 구현하고 값을 순수 뷰에 넘기는 화면과 팩토리 |
| `Features/<피처>/Example` | 그 피처만 띄우는 Example 앱. 부모 대신 받은 이벤트를 화면에 보여 줍니다 |
| `Transport` | `URLSessionHTTPTransport`(ADR-0033)와 루프백 서버 테스트 |
| `App` | 전체 앱(`TodoModularApp.swift`)과 UI 테스트 |

앱에서 피처 어댑터를 모두 아는 곳은 `AppViewFactory` 하나뿐입니다.

## 빌드와 실행

Xcode와 Tuist 4.191.5가 필요합니다(`mise install tuist@4.191.5` 등).

```sh
cd Samples/TodoModular/iOS
tuist generate --no-open
xcodebuild test -workspace TodoModular.xcworkspace -scheme TodoModular \
  -destination 'platform=iOS Simulator,name=iPhone 17'          # 전체 앱 UI 테스트
xcodebuild test -workspace TodoModular.xcworkspace -scheme TodoTransport \
  -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TodoTransportTests   # 실제 소켓으로 URLSession 전송 확인
```

피처 Example 앱 스킴은 `FeatureLoggedInExample`, `FeatureLoggedOutExample`, `FeatureTodoListExample`, `FeatureTodoDetailExample`입니다.

## 실행 인자

| 인자 | 동작 |
|---|---|
| `-todoBaseURL <주소>` | 그 서버(`http`·`https`)에 `URLSession`으로 요청합니다. 주지 않으면 앱 안의 샘플 서버(`SampleTodoServer`)를 씁니다 |
| `-loginDelayMillis <ms>` | 로그인 응답 지연. 기본 800ms. 이름을 `fail`로 넣으면 로그인이 실패합니다 |
| `-todoFailures <n>` | 할 일 요청을 처음 n번 실패시킵니다. 오류·다시 시도 화면 확인용 |

- 트리 상태는 `@SceneStorage`에 저장하고, 앱이 다시 뜨면 같은 화면으로 돌아옵니다.
- 상세 화면은 화면 왼쪽 끝에서 밀어 닫아도 RIB 트리가 따라옵니다(ADR-0030). UI 테스트 `testSwipeBackClosesDetailAndKeepsTreeInSync`가 확인합니다.
- CI는 UI 테스트를 실패한 것만 한 번 더 돌립니다([빌드 문서](../../../docs/building.md#ci)).
