### ADR-0018 트리 저장·복원을 `Codable` 기반 `RibSnapshot`으로 바꾼다
- 상태: 제안
- 날짜: 2026-11-15
- 배경:
  - 시스템이 프로세스를 정리하는 경우(Android 백그라운드 종료, 웹 새로고침·탭 정리, iOS 메모리 회수)에 사용자가 보던 화면으로 돌아오려면 RIB 트리 상태를 직렬화해 두어야 한다. 외부 앱 결제·인증, 카메라 다녀오기, 인증 문자 확인처럼 앱을 잠깐 떠나는 흐름에서 자주 일어난다. 사용자가 직접 앱을 종료한 경우는 복원 대상이 아니다.
  - 플랫폼마다 필요성이 다르다. Android는 회전·다크 모드·언어 변경만으로도 기본적으로 Activity를 다시 만들기 때문에 저장·복원이 생명주기의 일부이고, RIBs-Android도 `Bundle`을 생명주기에 넣었다. iOS는 회전으로 객체가 사라지지 않고, UIKit·SwiftUI의 복원 API(`restorationIdentifier`, `NSUserActivity`, `@SceneStorage`)는 앱이 고르는 선택 기능이며 뷰 컨트롤러 계층 기준이라 Router 트리에 그대로 쓸 수 없다. RIBs-iOS에 저장 장치가 없는 것은 이 차이 때문이다. 공유 코드에서 모든 플랫폼을 함께 다루려면 플랫폼 중립 장치가 코어에 있어야 한다.
  - 지금은 `RibState`(ADR-0016)가 이 일을 한다. RIBs-Android의 `Bundle`처럼 값 종류마다 `RibValue` 케이스(`string`·`int`·`double`·`bool`·`list`·`state`)로 감싸 넣고, 직접 짠 JSON 코덱으로 문자열을 만든다. 앱은 저장할 값을 하나하나 열거형으로 바꿔야 하고, 꺼낼 때도 `stringValue`·`intValue`로 다시 풀어야 한다.
  - 화면 쪽에 `ViewState`·`ViewAction` 패턴을 들일 예정이라 `RibState`라는 이름이 화면 상태와 헷갈린다.
- 결정:
  - `RibState`·`RibValue`·`RibStateCodec`·`RibStateDecodingError`를 없애고 `RibSnapshot`으로 바꾼다. `RibSnapshot`은 트리 구조만 담는 `Codable` 값이다.
    ```swift
    public struct RibSnapshot: Codable, Sendable, Equatable {
        var interactor: Data?               // Interactor가 내놓은 값을 JSON으로 인코딩한 것
        var children: [String: RibSnapshot] // 자식 tag → 자식 스냅샷
    }
    ```
  - Interactor는 자기 상태를 앱이 정의한 `Codable` 타입으로 내놓고 되받는다.
    ```swift
    open func snapshot() -> (any Encodable)?                     // 기본 nil: 저장할 것 없음
    public final func restoredSnapshot<T: Decodable>(as type: T.Type) -> T?
    ```
    저장된 값이 없거나 형식이 맞지 않으면 `nil`을 돌려주고, 그 RIB은 처음 상태로 시작한다. 앱 버전이 바뀌어 옛 스냅샷과 타입이 달라져도 앱을 멈추지 않는다.
  - `interactor`가 `Data`라서 JSON 안에서는 base64 문자열로 들어간다. 저장 문자열을 사람이 읽기 어렵지만 플랫폼은 내용을 해석하지 않고 통째로 저장만 하므로 그대로 둔다.
  - 플랫폼은 `RibSnapshot`을 `JSONEncoder`로 인코딩한 문자열(또는 `Data`) 하나만 저장한다. `LaunchRouter.launch(from:snapshot:)`, `mount(snapshot:)`로 되살린다.
  - tag로 자식 상태를 찾는 규칙, tag 없는 자식을 저장하면 `precondition`으로 실패하는 규칙은 그대로 둔다.
  - 스냅샷에는 화면 위치와 식별자(열린 항목 id, 선택된 탭, 작성 중인 입력)만 넣는다. 도메인 데이터는 저장소·서비스에서 다시 읽는다. 이 지침을 DocC와 README에 적는다.
- 고려했던 대안:
  (1) 복원하지 않고 루트부터 다시 시작(RIBs-iOS와 같음): Android에서 앱을 잠깐 떠났다 오면 진행이 사라져 기각했다.
  (2) 도메인 데이터만 저장하고 시작할 때 화면을 결정: 실제 앱에 필요한 방식이라 지침으로 함께 쓰지만, 열려 있던 상세 같은 화면 위치를 잃어 단독으로는 기각했다.
  (3) 경로(`/todos/3` 같은 route) 하나로 저장하고 라우팅으로 복원: 딥링크와 장치를 공유할 수 있으나, 경로를 해석해 트리를 만드는 라우팅 계층이 아직 없고 화면 내부 상태를 담지 못해 지금은 기각했다. 딥링크를 도입할 때 다시 검토한다.
  (4) 플랫폼 뷰에서 저장(Compose `rememberSaveable`, `SceneStorage`): 플랫폼마다 따로 구현해야 해 "뷰만 빼고 공유한다"는 목표와 맞지 않아 기각했다.
  (5) `RibState` 유지: 앞의 배경 때문에 기각했다.
  (6) 이름 후보 `RibArchive`·`RibRestoration`·`RibSavedState`: 각각 `NSKeyedArchiver`를 떠올리게 하거나, 어색하거나, "State"가 남아 화면 상태와 겹쳐 `RibSnapshot`을 골랐다.
- 결과:
  - 코어에서 `RibStateCodec.swift`와 `RibValue` 관련 코드가 빠진다. 앱은 `Codable` 구조체 하나로 저장 상태를 정의한다.
  - `RIBsAndroid`는 화면 트리를 Kotlin에 넘길 때 `RibValue`를 쓰고 있다. 이 전달 형식도 `Encodable` 기반으로 바꾼다(화면 `ViewState` 결정과 함께 다룬다).
  - 웹(ADR-0013)과 iOS 샘플의 저장 코드, `LifecycleRestoreTest`, `RibStateTests`가 새 API로 바뀐다. 웹 E2E와 Android 계측 테스트로 복원을 다시 확인한다.
  - 공개 API가 깨지는 변경이므로 `api/` 덤프를 갱신한다.
  - carti-RIBs-KMP의 `RibState`와 이름·동작이 달라진다. KMP를 맞출지는 따로 정한다.
  - 채택되면 ADR-0016의 상태를 `대체됨`으로 바꾼다(`mount`/`RibMount` 부분은 이 ADR이 이어받는다).
- 관련: ADR-0001, ADR-0013, ADR-0016, ADR-0017
