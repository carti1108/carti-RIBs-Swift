### ADR-0035 클립보드·파일 같은 플랫폼 입력은 뷰가 다루고, 결과 하나만 `ViewAction`으로 넘긴다
- 상태: 채택
- 날짜: 2026-11-25
- 배경:
  - 그렙 클라이언트는 클립보드 복사와 파일 끌어다 놓기·선택이 필요하다(#31 2번). 지금 샘플의 뷰 계약(ADR-0025)은 버튼 누름만 액션으로 넘긴다.
  - 클립보드와 파일은 플랫폼마다 API, 권한, 실패 방식이 다르다. 웹은 `navigator.clipboard.writeText`(보안 컨텍스트와 권한이 필요하고 거절할 수 있다), `DataTransfer`, `<input type="file">`이다. iOS는 `UIPasteboard`·`fileImporter`, Android는 `ClipboardManager`·`ActivityResultContracts`다.
  - 공유 코드는 Foundation 없이 둔다(ADR-0004, ADR-0032).
- 결정:
  - 뷰가 플랫폼 API를 부르고, 공유 코드에는 결과 하나를 `ViewAction`으로 넘긴다. 공유 코드는 결과에 따라 상태를 바꿔 `render`한다.
    - 클립보드: `TodoDetailViewAction.titleCopied(succeeded: Bool)`. 뷰가 상태의 제목을 클립보드에 쓰고 성공 여부만 알린다. Interactor는 `TodoDetailViewState.notice`에 결과 문구를 넣는다. 문구는 다음 동작으로 다시 그릴 때 지운다.
    - 파일: `TodoListViewAction.fileReceived(name: String, text: String)`. 끌어다 놓기와 파일 선택은 같은 액션 하나로 간다. Interactor가 줄마다 앞뒤 공백을 지우고 빈 줄을 건너뛰어 할 일로 더하고, 결과 문구를 `TodoListViewState.notice`에 넣는다.
  - 외부 입력의 크기는 두 곳에서 막는다. 뷰는 파일에서 처음 64KB만 읽는다. 큰 파일을 통째로 브리지에 넘기지 않기 위해서다. 공유 코드는 한 번에 100개(`TodoListInteractor.maxImportedTodos`)까지만 더하고 넘긴 줄 수를 알린다.
  - 목록을 불러오기 전에는 파일에서 더하지 않는다. 뒤이어 불러온 목록이 덮어쓰기 때문이다.
  - 더한 할 일은 `TodoStore.add(titles:)`로 저장소에만 넣는다. 서버에 보내지 않고, 상태 저장 대상(완료 표시)이 아니라 앱을 다시 열면 사라진다.
  - 이번에는 웹 뷰만 버튼과 파일 받는 자리를 둔다. 계약 변경은 기본값이 있는 필드와 새 액션 케이스뿐이라 iOS·Android 뷰는 고치지 않아도 빌드된다. 그 플랫폼 뷰는 새 액션을 보내지 않는다.
  - 순수 뷰(ADR-0027)가 클립보드와 파일을 직접 다룬다. 둘 다 브라우저 전역 API라 React 밖 import가 없고, 어댑터는 결과를 핸들로 옮기기만 한다.
- 고려했던 대안:
  (1) 공유 코드가 `ClipboardWriting` 같은 프로토콜을 Dependency로 받아 직접 부르기: Interactor 테스트에서 가짜로 바꾸기 쉽다. 하지만 권한 요청, 사용자 제스처 안에서만 되는 제약(웹), 포커스 같은 뷰의 사정이 공유 코드로 새고, 플랫폼마다 프로토콜 구현과 브리지 층이 하나씩 는다. 결과만 받으면 공유 코드는 성공·실패 두 경우만 안다. 기각했다.
  (2) 파일 내용을 `[UInt8]`로 넘기기: 바이너리 파일도 받을 수 있다. 이 예시는 줄 단위 텍스트라 디코딩을 뷰(`File.text()`)에 두는 편이 단순하고, Android·Web 경계가 문자열만 넘긴다는 ADR-0034의 제약과도 맞다. 바이너리 업로드는 ADR-0034가 열어 둔 대로 서명된 URL 쪽에서 정한다. 기각했다.
  (3) 끌어다 놓기와 파일 선택을 다른 액션으로 두기: 공유 코드가 할 일은 같다. 받는 방법은 뷰의 사정이라 액션 하나로 합쳤다.
  (4) 별도 스파이크 페이지에 두기(ADR-0034 방식): 피처를 건드리지 않는다. 하지만 이 결정이 보여 줄 것은 `ViewAction → Interactor → render` 흐름이라 실제 피처에 두었다.
- 결과:
  - Shared 테스트 8개를 더했다(저장소 2, 목록 4, 상세 2). Windows에서 Shared `swift test` 80개 통과.
  - Web e2e 4개를 더했다(`e2e/input-bridge.test.js`). 클립보드는 `navigator.clipboard`를 바꿔 끼워 성공·거절 두 결과를 만든다. 실제 OS 클립보드에 쓰이는지는 브라우저 권한과 포커스에 따라 달라 e2e로 확인하지 않는다. 파일은 `DataTransfer`로 input `change`와 `drop`을 만든다. WSL Ubuntu에서 e2e 28개 통과.
  - TodoModular Android Swift 호스트 테스트 13개 통과(WSL). iOS는 빌드하지 않았다(Mac 필요). iOS 어댑터는 상태의 기본 이니셜라이저만 쓰고 액션을 `switch`하지 않아 영향이 없다고 본다.
  - iOS·Android에서 같은 입력을 붙이는 방법(`UIPasteboard`, `ClipboardManager`, 파일 선택 창)은 다루지 않았다. 계약은 그대로 쓸 수 있다.
- 관련: ADR-0025, ADR-0027, ADR-0032, ADR-0034, #31
