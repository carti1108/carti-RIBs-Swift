# 작업 규칙

이 레포에서 작업하는 사람과 에이전트가 따르는 규칙입니다.

## 기준

- **원본은 [uber/RIBs-iOS](https://github.com/uber/RIBs-iOS)**다(ADR-0001). 새 API를 만들기 전에 원본에 같은 역할의 파일이 있는지 확인하고, 있으면 이름·시그니처·호출 순서를 맞춘다.
- 원본과 다르게 해야 하면 이유를 doc 주석과 ADR에 남긴다.
- 원본에서 deprecated인 API는 옮기지 않는다.

## 문서

- ADR은 [docs/adr/](docs/adr/README.md)에 둔다. 파일 하나에 하나, `ADR-<네 자리>-<영문-슬러그>.md`. 대안과 기각 이유가 없으면 쓰지 않는다.
- 채택된 ADR은 고치지 않는다. 결정이 바뀌면 새 ADR을 쓰고 옛 것의 상태만 `대체됨`으로 바꾼다.

## 코드

- `Sources/RIBs`는 표준 라이브러리와 `_Concurrency`만 쓴다. `import Foundation`·`Dispatch`·`Combine` 금지(ADR-0004). CI(`.github/workflows/ci.yml`)가 `Sources/RIBs`의 import를 `Swift`·`_Concurrency`로 제한해 검사한다.
- 샘플 공유 코드에서는 데이터 계층 모듈(`TodoData`)만 `FoundationEssentials`를 쓴다(ADR-0032). 피처와 `TodoCore`는 Foundation 없이 둔다.
- Swift 6 언어 모드, 엄격한 동시성. 생명주기 타입은 모두 `@MainActor`다(ADR-0003). 내부에 락을 두지 않는다.
- 비동기 작업은 `Interactor.task(_:)`/`Worker.task(_:)`로 활성 구간에 묶는다. Rx·Combine은 쓰지 않는다(ADR-0002).
- DI는 손으로 짠 `Component`로 한다(ADR-0005). 숨은 전역·싱글턴을 두지 않는다. 예외는 Android 샘플의 브리지 진입점뿐이다. Kotlin이 부르는 함수(`@_cdecl`, swift-java 내보내기)는 상태를 둘 인스턴스가 없어 앱 컨트롤러와 `JavaVM` 포인터를 전역에 둔다. 공유 모듈의 RIB 코드는 이 전역을 읽지 않는다.
- 계약 위반은 `precondition`으로 메시지와 함께 실패시킨다. 복구 가능한 실패는 typed throws로 던진다.

## 테스트

- 테스트를 먼저 쓴다(RED → GREEN → 정리). Swift Testing(`import Testing`)만 쓴다.
- mock 라이브러리 없이 가짜 구현을 손으로 만든다.
- 커밋 전 `swift build && swift test`를 통과시킨다.

## 커밋

- 의미 단위로 나눈다. 메시지는 `<type>: <설명>`, 설명은 한국어. type은 feat, fix, refactor, docs, test, chore, perf, ci.
- 원격 푸시, 저장소 공개, PR 생성은 소유자 확인 후에만 한다.
