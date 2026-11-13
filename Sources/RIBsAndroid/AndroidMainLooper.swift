import CRIBsAndroid

/// Swift `@MainActor` 작업을 Android 메인 Looper에서 돌게 한다(ADR-0010).
///
/// Android용 Swift 런타임의 메인 실행기는 libdispatch 메인 큐다. Android 앱에는 `dispatch_main()`이나
/// CFRunLoop가 돌지 않으므로, 아무도 비우지 않으면 `Task { @MainActor in }`이 영원히 실행되지 않는다.
/// `attach()`는 메인 큐의 eventfd를 메인 Looper에 등록해, 큐에 작업이 들어오면 Looper가 비우게 한다.
public enum AndroidMainLooper {
    /// Android UI(메인) 스레드에서 한 번 부른다. 라이브러리 로드와 이 호출 모두 UI 스레드에서 해야 한다:
    /// 등록 대상은 호출 스레드의 Looper이므로 다른 스레드에서 부르면 `@MainActor` 작업이 그 스레드에서 돈다.
    /// 호출 측(Kotlin)이 `Looper.myLooper() == Looper.getMainLooper()`를 먼저 확인한다. 성공하거나 이미 붙어 있으면 true.
    /// Android가 아닌 플랫폼에서는 false다(그곳에선 각 플랫폼 런루프가 메인 큐를 비운다).
    @MainActor
    @discardableResult
    public static func attach() -> Bool {
        ribs_android_attach_main_queue_to_looper()
    }
}
