# TodoModular Android 앱 (Compose)

µFeature 샘플([개요](../README.md))의 Android 앱입니다. 공유 패키지(`../Shared`)를 Android용 `.so`로 교차 빌드하고, 화면은 피처별 Compose 모듈이 그립니다. 화면 구조는 JSON 트리로, 화면 상태와 입력은 swift-java가 만든 화면별 브리지로 오갑니다(ADR-0020, ADR-0021, ADR-0023).

## 구조

| 위치 | 내용 |
|---|---|
| `swift/Sources/FeatureXxxAndroid` | 피처의 Android 화면(뷰 계약 구현)과 뷰 팩토리 |
| `swift/Sources/TodoAndroidSupport` | 화면 기반 클래스, 루트 화면, 데모용 자리표시 화면 |
| `swift/Sources/TodoModularAndroid` | 앱 컨트롤러, 전체 앱과 피처별 데모 조립 |
| `swift/Sources/TodoModularBridge` | JNI 진입점(`@_cdecl`)과 swift-java 내보내기 |
| `bridge` | Kotlin 쪽 브리지(`SwiftBridge`, `RibActivity`), `HttpUrlConnectionTransport`. Swift 교차 빌드를 Gradle에 잇습니다 |
| `feature/<피처>/ui` | 순수 Compose 뷰. 값과 콜백만 받습니다(ADR-0027) |
| `feature/<피처>/adapter` | 브리지를 구현하고 값을 순수 뷰에 넘기는 화면 |
| `feature/<피처>/demo` | 그 피처만 띄우는 데모 앱. 부모에게 갈 이벤트는 화면 아래에, 자식 피처는 자리표시 화면으로 보입니다 |
| `app` | 전체 앱(`MainActivity`)과 계측 테스트 |

앱에서 화면 종류를 피처 어댑터에 잇는 곳은 `MainActivity` 하나뿐입니다. Swift 메인 큐는 메인 Looper에 붙습니다(ADR-0010).

## 요구 사항

swift.org 툴체인 6.4.2, Swift SDK `swift-6.4.2-RELEASE_android`(NDK r30에 연결), Android SDK(API 37), JDK 21. 준비 방법은 [AndroidLogin README](../../AndroidLogin/README.md#요구-사항)와 같습니다. macOS나 Linux에서 빌드합니다. Windows 호스트에서는 swift-java 플러그인 때문에 빌드되지 않습니다([이유](../../../docs/building.md#swift-java를-쓰는-android-샘플은-windows-호스트에서-빌드되지-않는다)).

## 빌드와 실행

```sh
export ANDROID_NDK_HOME=~/Library/Android/android-ndk-r30
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
cd Samples/TodoModular/Android
(cd swift && swift test --disable-sandbox)                       # 화면 객체와 앱 컨트롤러(호스트)
./gradlew :app:assembleDebug                                     # Swift .so(arm64-v8a)를 넣은 APK
./gradlew connectedDebugAndroidTest -PswiftAbis=x86_64           # x86_64 에뮬레이터에서 계측 테스트
./gradlew :feature:todolist:demo:installDebug                    # 피처 데모 앱 설치
```

- Gradle 설정(`SWIFT_CLI`, `SWIFT_ANDROID_API`, `-PswiftAbis`)은 AndroidLogin과 같습니다([설명](../../AndroidLogin/README.md#gradle-설정)).
- 계측 테스트는 로그인 흐름, 회전과 프로세스 종료 뒤 상태 복원, `HttpURLConnection` 전송(로컬 서버)을 확인합니다. 피처 `ui` 모듈에는 순수 뷰 테스트가 있습니다.

## 인텐트 값

| 키 | 동작 |
|---|---|
| `todoBaseUrl` | 할 일 API 서버 주소(`http://host:port/api`). 주면 `HttpURLConnection`으로 요청하고, 없으면 앱 안의 샘플 서버를 씁니다(ADR-0033) |
| `loginDelayMillis` | 로그인 응답 지연. 기본 800ms. 이름을 `fail`로 넣으면 로그인이 실패합니다 |

```sh
adb shell am start -n com.carti.ribs.samples.todomodular/.MainActivity --es todoBaseUrl http://10.0.2.2:8080/api
```

에뮬레이터에서 `10.0.2.2`는 호스트 컴퓨터입니다. 평문 HTTP는 디버그 빌드에서만 허용합니다(`app/src/debug/AndroidManifest.xml`). 릴리스 빌드는 `https` 주소를 씁니다.
