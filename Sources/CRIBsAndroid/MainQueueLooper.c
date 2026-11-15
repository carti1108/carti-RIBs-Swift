#include "CRIBsAndroid.h"

#ifdef __ANDROID__
#include <android/looper.h>
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <unistd.h>

// libdispatch가 CoreFoundation 런루프용으로 내보내는 SPI. Linux/Android에서 핸들은 eventfd다.
// swift-corelibs-libdispatch src/queue.c, private/queue_private.h 참고.
// Swift 6.4.2에는 이를 대신할 공개 API가 없다(ADR-0014).
extern int _dispatch_get_main_queue_handle_4CF(void);
extern void _dispatch_main_queue_callback_4CF(void *msg);

static bool attached = false;

static int drain_main_queue(int fd, int events, void *data) {
    (void)events;
    (void)data;
    // eventfd를 비워 두지 않으면 Looper가 계속 깨어난다. 이미 비어 있으면 EAGAIN이다(논블로킹).
    uint64_t counter;
    while (read(fd, &counter, sizeof counter) < 0 && errno == EINTR) {}
    _dispatch_main_queue_callback_4CF(0);
    return 1; // 콜백을 계속 유지한다.
}

ribs_android_attach_result ribs_android_attach_main_queue_to_looper(void) {
    if (attached) return RIBS_ANDROID_ATTACH_OK;
    ALooper *looper = ALooper_forThread();
    if (looper == 0) return RIBS_ANDROID_ATTACH_NO_LOOPER;
    int fd = _dispatch_get_main_queue_handle_4CF();
    // SPI 계약 자체검사: 핸들은 열린 fd여야 한다. libdispatch가 바뀌어 다른 값을 주면 여기서 멈춘다.
    if (fd < 0 || fcntl(fd, F_GETFD) == -1) return RIBS_ANDROID_ATTACH_INVALID_MAIN_QUEUE_HANDLE;
    if (ALooper_addFd(looper, fd, ALOOPER_POLL_CALLBACK, ALOOPER_EVENT_INPUT, drain_main_queue, 0) != 1) {
        return RIBS_ANDROID_ATTACH_ADD_FD_FAILED;
    }
    attached = true;
    return RIBS_ANDROID_ATTACH_OK;
}
#else
ribs_android_attach_result ribs_android_attach_main_queue_to_looper(void) {
    return RIBS_ANDROID_ATTACH_UNSUPPORTED_PLATFORM;
}
#endif
