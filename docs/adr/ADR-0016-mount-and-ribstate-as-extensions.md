### ADR-0016 `mount`/`RibMount`와 `RibState`를 RIBs-iOS 밖의 확장으로 유지한다
- 상태: 채택
- 날짜: 2026-11-14
- 배경: 원본으로 삼은 RIBs-iOS(ADR-0001)에는 루트를 내리는 API와 상태 저장·복원이 없다. 루트는 `LaunchRouter.launch(from:)`로 한 번 띄우고 앱이 끝날 때까지 유지한다. Swift 판의 `Router.mount`/`RibMount`와 `RibState`는 RIBs-Android의 `saveInstanceState(Bundle)`와 KMP 판에서 가져왔다.
- 결정: 두 기능을 코어 `RIBs`에 공개 API로 남긴다. RIBs-iOS에 없는 확장임을 README와 이 문서에 밝힌다.
  - `mount`/`unmount`: Android Activity·브라우저 탭처럼 생명주기가 있는 호스트에서 루트를 붙였다 떼고, 테스트에서 window 없이 트리를 띄운다. `LaunchRouter.launch`/`shutdown`도 이것을 쓴다.
  - `RibState`: Android 프로세스 종료, 웹 새로고침, iOS 장면 복원에서 트리 상태를 문자열 하나로 저장·복원한다.
- 고려했던 대안: `mount`를 internal로 숨기고 `RibState`를 별도 모듈로 분리해 코어 공개 API를 RIBs-iOS와 맞춘다. Android·웹 샘플이 둘 다 필요로 하고 모듈 분리 비용에 비해 얻는 것이 적어 택하지 않았다.
- 결과: RIBs-iOS 코드를 옮겨 올 때 이 두 API는 쓰지 않아도 되고, 쓰지 않으면 동작도 RIBs-iOS와 같다.
- 관련: ADR-0001, ADR-0013
