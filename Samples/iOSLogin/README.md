# iOS 샘플

`LoginShared`의 RIB 트리(로그인 → 할 일 목록 → 상세)를 SwiftUI로 띄우는 Tuist 앱입니다. XCUITest로 흐름을 확인합니다.

```sh
swift test --filter LoginSharedTests        # 공유 로직(저장소 루트에서)
cd Samples/iOSLogin && tuist generate --no-open
xcodebuild test -workspace LoginSample.xcworkspace -scheme LoginSample \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```
