### ADR-0013 웹 샘플은 sessionStorage에 RibState를 저장하고 새로고침 때 복원한다
- 상태: 채택
- 날짜: 2026-11-14
- 배경: ADR-0009 시점에는 웹 샘플에 상태 복원을 연결하지 않았다. 새로고침하면 로그인 화면으로 돌아가 iOS(`SceneStorage`)·Android(`Bundle`)와 동작이 달랐다.
- 결정: `WebLogin`이 시작할 때 `sessionStorage`의 `ribs.login.savedState`를 `LoginApp.start(savedState:)`에 넘긴다. 문자열이 깨졌으면 지우고 처음부터 시작한다. 저장은 `pagehide`(새로고침·이동·탭 닫기)와 `visibilitychange`가 `hidden`일 때 `LoginApp.saveState()`로 한다. 화면 전환마다 저장하지 않는다. 라우팅 도중에 트리를 저장하면 반쯤 바뀐 상태가 남을 수 있고, 위 두 이벤트가 페이지를 떠나기 전에 온다.
- 고려했던 대안:
  (1) `localStorage`: 탭을 닫고 다시 열어도 남아 로그인 세션이 의도보다 오래 산다. 플랫폼별 "프로세스 재생성 복원" 의미와 맞는 것은 탭 단위 `sessionStorage`다.
  (2) URL 해시에 상태 인코딩: 공유·북마크로 상태가 새고 길이가 커진다.
  (3) 상태가 바뀔 때마다 저장: 위의 중간 상태 문제와, 매 입력마다 트리 전체를 직렬화하는 비용.
- 결과: 상세 화면에서 새로고침하면 같은 할 일 상세와 완료 상태가 돌아온다(Puppeteer E2E로 확인). 브라우저가 이벤트 없이 강제 종료되면 마지막 상태를 잃는다.
- 관련: ADR-0009
