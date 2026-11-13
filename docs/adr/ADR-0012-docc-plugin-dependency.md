### ADR-0012 문서는 swift-docc-plugin과 RIBs.docc 카탈로그로 만든다
- 상태: 채택
- 날짜: 2026-11-14
- 배경: 공개 API 문서와 생명주기·라우팅·상태 저장 설명을 한곳에서 읽을 수 있어야 한다. 루트 패키지는 지금까지 외부 의존이 없었고, Wasm·Android SDK 빌드도 의존 없이 돌았다.
- 결정: 루트 `Package.swift`에 `swift-docc-plugin`(1.4.0 이상)을 의존으로 넣고, `Sources/RIBs/RIBs.docc`에 한국어 랜딩 문서를 둔다. 어떤 타깃도 이 패키지의 product에 의존하지 않으므로 라이브러리 산출물에는 들어가지 않는다. CI(macOS)는 `swift package generate-documentation --target RIBs --warnings-as-errors`로 깨진 심볼 링크를 막는다.
- 고려했던 대안:
  (1) 별도 문서 패키지에서 루트를 경로 의존으로 받아 생성: 루트 의존은 0개로 남지만 `generate-documentation --target RIBs`를 루트에서 쓸 수 없고, 카탈로그와 소스가 떨어진다.
  (2) `xcodebuild docbuild`: macOS·Xcode에서만 돈다.
- 결과: 패키지를 해석할 때 swift-docc-plugin(및 그 의존)을 받는다. 이 패키지를 쓰는 앱도 해석 단계에서 받게 된다. Wasm·Android SDK 빌드는 영향이 없음을 확인했다.
- 관련: ADR-0004, ADR-0011
