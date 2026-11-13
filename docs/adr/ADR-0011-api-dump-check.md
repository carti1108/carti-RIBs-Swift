### ADR-0011 공개 API를 swift-api-digester 덤프로 체크인하고 CI에서 비교한다
- 상태: 채택
- 날짜: 2026-11-14
- 배경: 공개 라이브러리 타깃(`RIBs`, `RIBsSwiftUI`, `RIBsUIKit`, `RIBsWeb`, `RIBsAndroid`)의 API가 의도치 않게 바뀌는 것을 리뷰에서 잡아야 한다. KMP 구현은 `checkKotlinAbi`/`updateKotlinAbi`로 체크인된 덤프와 비교한다. SwiftPM에는 `swift package diagnose-api-breaking-changes <treeish>`가 있지만 git 기준점(태그·커밋)을 체크아웃해 다시 빌드하는 방식이다. 지금 저장소에는 패키지가 들어간 커밋이 없어 `HEAD`를 기준으로 실행하면 `Package.swift`를 찾지 못하고 실패한다.
- 결정:
  - `scripts/check-api.sh`가 패키지를 빌드하고 `xcrun swift-api-digester -dump-sdk -swift-only -avoid-location -avoid-tool-args`로 모듈별 JSON을 만들어 `api/<모듈>.json`과 바이트 단위로 비교한다. 다르면 같은 digester의 `-diagnose-sdk -baseline-path`로 깨지는 변경(삭제·시그니처 변경)을 사람이 읽는 문장으로 출력하고, 덤프 diff를 붙여 1로 끝난다. 추가만 있어도 실패한다(KMP와 같음).
  - `--update`가 덤프를 갱신한다(`updateKotlinAbi`). 의도한 변경이면 `api/`를 소스와 함께 커밋한다.
  - `RIBs`, `RIBsSwiftUI`, `RIBsWeb`, `RIBsAndroid`는 macOS 빌드에서, `RIBsUIKit`은 `#if canImport(UIKit)`라 iOS 시뮬레이터 빌드(`--triple arm64-apple-ios17.0-simulator`)에서 덤프한다. `RIBsAndroid`의 Android 전용 부분은 C 타깃에만 있고 Swift 공개 API는 호스트와 같으므로 macOS 덤프로 충분하다.
  - CI는 macOS 작업에서만 실행한다. 태그가 생기면 `--baseline <태그>`로 SwiftPM `diagnose-api-breaking-changes`도 함께 돌린다.
- 고려했던 대안:
  (1) `swift package diagnose-api-breaking-changes`만 사용: 공식 도구지만 기준 커밋이 필요하고, 기준점을 매번 다시 빌드한다. 덤프 파일이 없어 리뷰에서 API 변화를 diff로 볼 수 없다. 기준점이 생긴 뒤 보조 수단으로만 쓴다.
  (2) `swift symbolgraph-extract` 출력 체크인: 문서 주석·소스 위치·정렬되지 않은 관계 목록이 들어 있어 주석만 고쳐도 diff가 생긴다. 깨지는 변경을 요약하는 비교 도구도 따로 없다.
  (3) `-abi` 덤프와 라이브러리 진화 모드: ABI 안정성을 약속하지 않는 소스 배포 패키지라 필요 없고, 모든 타깃에 `-enable-library-evolution`을 켜야 한다.
- 결과: API 변경이 PR diff에 `api/*.json`으로 드러난다. 덤프는 Xcode의 Swift 버전에 따라 표현이 달라질 수 있어, CI의 Xcode가 바뀌어 내용 없는 차이가 생기면 `--update`로 다시 맞춘다. Linux·Windows에서는 실행하지 않는다.
- 관련: ADR-0001, ADR-0012
