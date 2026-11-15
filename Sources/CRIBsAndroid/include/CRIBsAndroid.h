#ifndef CRIBS_ANDROID_H
#define CRIBS_ANDROID_H

#include <stdbool.h>

/// `ribs_android_attach_main_queue_to_looper`의 결과(ADR-0014).
typedef enum {
    /// 등록했거나 이미 등록돼 있다.
    RIBS_ANDROID_ATTACH_OK = 0,
    /// Android가 아닌 플랫폼이다.
    RIBS_ANDROID_ATTACH_UNSUPPORTED_PLATFORM = 1,
    /// 호출 스레드에 ALooper가 없다(UI 스레드가 아니다).
    RIBS_ANDROID_ATTACH_NO_LOOPER = 2,
    /// libdispatch SPI `_dispatch_get_main_queue_handle_4CF`가 유효한 파일 디스크립터를 주지 않았다.
    RIBS_ANDROID_ATTACH_INVALID_MAIN_QUEUE_HANDLE = 3,
    /// `ALooper_addFd`가 실패했다.
    RIBS_ANDROID_ATTACH_ADD_FD_FAILED = 4,
} ribs_android_attach_result;

/// 호출한 스레드의 ALooper에 libdispatch 메인 큐의 eventfd를 등록한다.
/// 이후 메인 큐에 작업이 들어오면 Looper가 깨어나 `_dispatch_main_queue_callback_4CF`로 비운다.
/// 반드시 Android 메인(UI) 스레드에서 부른다. 두 번째 호출은 등록하지 않고 OK를 돌려준다.
ribs_android_attach_result ribs_android_attach_main_queue_to_looper(void);

#endif
