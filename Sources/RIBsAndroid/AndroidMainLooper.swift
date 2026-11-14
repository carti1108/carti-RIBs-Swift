import CRIBsAndroid

/// Swift `@MainActor` 작업을 Android 메인 Looper에서 돌게 한다(ADR-0010, ADR-0014).
///
/// Android용 Swift 런타임의 메인 실행기는 libdispatch 메인 큐다. Android 앱에는 `dispatch_main()`이나
/// CFRunLoop가 돌지 않으므로, 아무도 비우지 않으면 `Task { @MainActor in }`이 영원히 실행되지 않는다.
/// `attach()`는 메인 큐의 eventfd를 메인 Looper에 등록해, 큐에 작업이 들어오면 Looper가 비우게 한다.
/// 이 등록은 libdispatch SPI에 기대므로(Swift 6.4.2에 공개 대안이 없다) 자체검사를 함께 둔다.
public enum AndroidMainLooper {
    /// 자체검사 Task가 메인 Looper에서 실제로 실행됐으면 true다.
    /// `attach()`가 성공한 뒤 Looper가 한 번 돌고 나면 true가 돼야 한다. 계속 false면 메인 큐 연결이 끊긴 것이다.
    @MainActor public private(set) static var isMainQueueDraining = false

    /// Android UI(메인) 스레드에서 한 번 부른다. 라이브러리 로드와 이 호출 모두 UI 스레드에서 해야 한다:
    /// 등록 대상은 호출 스레드의 Looper이므로 다른 스레드에서 부르면 `@MainActor` 작업이 그 스레드에서 돈다.
    /// 성공하거나 이미 붙어 있으면 true이고, 자체검사 Task를 메인 큐에 넣는다(`isMainQueueDraining`).
    /// Android가 아닌 플랫폼에서는 false다(그곳에선 각 플랫폼 런루프가 메인 큐를 비운다).
    /// 등록에 실패하면 원인을 담은 메시지로 멈춘다.
    @MainActor
    @discardableResult
    public static func attach() -> Bool {
        let result = ribs_android_attach_main_queue_to_looper()
        if result == RIBS_ANDROID_ATTACH_UNSUPPORTED_PLATFORM { return false }
        precondition(result == RIBS_ANDROID_ATTACH_OK, failureMessage(for: result))
        Task { @MainActor in isMainQueueDraining = true }
        return true
    }

    private static func failureMessage(for result: ribs_android_attach_result) -> String {
        switch result {
        case RIBS_ANDROID_ATTACH_NO_LOOPER:
            "AndroidMainLooper.attach: the calling thread has no ALooper; call it on the Android UI thread"
        case RIBS_ANDROID_ATTACH_INVALID_MAIN_QUEUE_HANDLE:
            "AndroidMainLooper.attach: libdispatch SPI _dispatch_get_main_queue_handle_4CF returned no valid fd; "
                + "this Swift runtime's libdispatch changed and @MainActor work cannot run (ADR-0014)"
        case RIBS_ANDROID_ATTACH_ADD_FD_FAILED:
            "AndroidMainLooper.attach: ALooper_addFd failed for the libdispatch main queue handle"
        default:
            "AndroidMainLooper.attach: unexpected result \(result.rawValue)"
        }
    }
}
