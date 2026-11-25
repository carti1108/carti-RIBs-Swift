package com.carti.ribs.samples.todomodular.core

import android.os.Handler
import android.os.Looper
import com.carti.ribs.samples.todomodular.swiftbridge.HTTPTransportHandle
import org.swift.swiftkit.core.SwiftArena

/**
 * Swift 라이브러리(libTodoModularBridge.so)와의 손으로 쓴 JNI 경계(ADR-0021). Swift 쪽 짝은 `swift/Sources/TodoModularBridge/JNI.swift`다.
 * 시작·종료·뒤로 가기·상태 저장·화면 트리(구조)만 맡는다. 화면의 상태와 입력은 swift-java가 만든 화면별 핸들로 오간다.
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
        System.loadLibrary("TodoModularBridge")
        // Swift @MainActor 작업(Task, 타이머)이 메인 Looper에서 돌도록 libdispatch 메인 큐를 붙인다.
        check(nativeAttachMainLooper()) { "Failed to attach the Swift main queue to the main Looper" }
        // 자체검사(ADR-0014): 연결은 libdispatch SPI에 기대므로, Swift가 넣은 확인 Task가 실제로 돌았는지 본다.
        Handler(Looper.getMainLooper()).postDelayed({
            check(nativeIsMainQueueDraining()) {
                "Swift @MainActor work did not run on the main Looper within ${SELF_CHECK_DELAY_MILLIS} ms; " +
                    "the libdispatch main queue SPI no longer drains (see ADR-0014)"
            }
        }, SELF_CHECK_DELAY_MILLIS)
    }

    /** 메인 큐 자체검사까지 기다리는 시간. 첫 Looper 순회는 이보다 훨씬 빨리 끝난다. */
    private const val SELF_CHECK_DELAY_MILLIS = 2_000L

    /** 메인 큐 자체검사 Task가 실행됐는지. 테스트에서도 쓴다. */
    fun isMainQueueDraining(): Boolean = nativeIsMainQueueDraining()

    /** 트리를 시작한다. `onRender`는 화면 트리(JSON)가 바뀔 때마다 메인 스레드에서 불린다. 저장값으로 되살렸으면 true. */
    fun start(savedState: String?, loginDelayMillis: Long, onRender: (String) -> Unit): Boolean {
        renderListener = onRender
        return nativeStart(savedState?.toByteArray(Charsets.UTF_8), loginDelayMillis)
    }

    /**
     * 피처 하나만 띄운다(단독 실행 앱). `feature`는 Swift `DemoFeature`의 원시값이다. 상태는 되살리지 않는다.
     */
    fun startDemo(feature: String, loginDelayMillis: Long, onRender: (String) -> Unit) {
        renderListener = onRender
        nativeStartDemo(feature.toByteArray(Charsets.UTF_8), loginDelayMillis)
    }

    fun handleBackPress(): Boolean = nativeHandleBackPress()

    fun saveState(): String? = nativeSaveState()?.toString(Charsets.UTF_8)

    fun stop() {
        nativeStop()
        renderListener = null
        uninstallHttpTransport()
    }

    /**
     * 할 일 API를 `baseUrl`의 서버에서 가져오게 한다(ADR-0033). [start] 전에 메인 스레드에서 부른다.
     * 부르지 않으면 Swift 쪽 샘플 서버를 쓴다.
     */
    fun installHttpTransport(baseUrl: String) {
        check(httpTransport == null) { "installHttpTransport called twice without stop" }
        val handle = HTTPTransportHandle.init(SwiftArena.ofAuto())
        val transport = HttpUrlConnectionTransport(baseUrl, handle)
        handle.install(transport)
        httpTransport = handle to transport
    }

    private fun uninstallHttpTransport() {
        val (handle, transport) = httpTransport ?: return
        httpTransport = null
        handle.uninstall()
        transport.shutdown()
    }

    private var httpTransport: Pair<HTTPTransportHandle, HttpUrlConnectionTransport>? = null

    /** Swift가 JNI로 부른다. */
    @JvmStatic
    fun onRender(tree: ByteArray) {
        renderListener?.invoke(tree.toString(Charsets.UTF_8))
    }

    private external fun nativeAttachMainLooper(): Boolean
    private external fun nativeIsMainQueueDraining(): Boolean
    private external fun nativeStart(savedState: ByteArray?, loginDelayMillis: Long): Boolean
    private external fun nativeStartDemo(feature: ByteArray, loginDelayMillis: Long): Boolean
    private external fun nativeHandleBackPress(): Boolean
    private external fun nativeSaveState(): ByteArray?
    private external fun nativeStop()
}
