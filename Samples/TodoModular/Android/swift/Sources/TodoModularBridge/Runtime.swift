import TodoModularAndroid

/// 프로세스에 하나뿐인 RIB 트리. `JNI.swift`의 `nativeStart`·`nativeStartDemo`가 만들고 `nativeStop`이 내린다.
@MainActor var controller: (any RibController)?

/// Kotlin이 넣어 둔 전송 계층. 있으면 `nativeStart`가 할 일 저장소를 이것으로 만든다(ADR-0033).
@MainActor var httpTransport: AndroidHTTPTransport?
