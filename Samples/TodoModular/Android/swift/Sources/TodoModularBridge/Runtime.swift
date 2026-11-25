import TodoModularAndroid

/// 프로세스에 하나뿐인 RIB 트리. `JNI.swift`의 `nativeStart`·`nativeStartDemo`가 만들고 `nativeStop`이 내린다.
@MainActor var controller: (any RibController)?
