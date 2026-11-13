package com.carti.ribs.samples.swiftandroid

import android.os.Looper

/**
 * Swift 라이브러리(libAndroidLogin.so)와의 JNI 경계(ADR-0010). Swift 쪽 짝은 `Sources/AndroidLogin/JNI.swift`다.
 *
 * - 라이브러리 로드와 메인 Looper 연결을 포함해 모든 호출은 UI(메인) 스레드에서 한다. `init`이 이를 확인한다.
 * - Swift는 `MainActor.assumeIsolated`로 이를 확인한다.
 * - 문자열은 UTF-8 `ByteArray`로 주고받는다.
 * - Swift RIB 트리는 프로세스에 하나다. `start` 뒤 `stop` 전에는 다시 `start`할 수 없다.
 */
object SwiftBridge {
    private var renderListener: ((String) -> Unit)? = null

    init {
        // 메인 큐를 붙이는 Looper는 호출 스레드의 Looper다. UI 스레드가 아니면 Swift @MainActor 작업이 엉뚱한 스레드에서 돈다.
        check(Looper.myLooper() == Looper.getMainLooper()) {
            "SwiftBridge must be loaded and attached on the Android UI (main) thread, " +
                "but was initialized on '${Thread.currentThread().name}'"
        }
        System.loadLibrary("c++_shared")
        System.loadLibrary("AndroidLogin")
        // Swift @MainActor 작업(Task, 타이머)이 메인 Looper에서 돌도록 libdispatch 메인 큐를 붙인다.
        check(nativeAttachMainLooper()) { "Failed to attach the Swift main queue to the main Looper" }
    }

    /** 트리를 시작한다. `onRender`는 화면 트리(JSON)가 바뀔 때마다 메인 스레드에서 불린다. 저장값으로 되살렸으면 true. */
    fun start(savedState: String?, loginDelayMillis: Long, onRender: (String) -> Unit): Boolean {
        renderListener = onRender
        return nativeStart(savedState?.toByteArray(Charsets.UTF_8), loginDelayMillis)
    }

    fun dispatch(screenId: Long, action: String, argument: String = ""): Boolean =
        nativeDispatch(screenId, action.toByteArray(Charsets.UTF_8), argument.toByteArray(Charsets.UTF_8))

    fun handleBackPress(): Boolean = nativeHandleBackPress()

    fun saveState(): String? = nativeSaveState()?.toString(Charsets.UTF_8)

    fun stop() {
        nativeStop()
        renderListener = null
    }

    /** Swift가 JNI로 부른다. */
    @JvmStatic
    fun onRender(tree: ByteArray) {
        renderListener?.invoke(tree.toString(Charsets.UTF_8))
    }

    private external fun nativeAttachMainLooper(): Boolean
    private external fun nativeStart(savedState: ByteArray?, loginDelayMillis: Long): Boolean
    private external fun nativeDispatch(screenId: Long, action: ByteArray, argument: ByteArray): Boolean
    private external fun nativeHandleBackPress(): Boolean
    private external fun nativeSaveState(): ByteArray?
    private external fun nativeStop()
}
