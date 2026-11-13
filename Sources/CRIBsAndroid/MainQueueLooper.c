#include "CRIBsAndroid.h"

#ifdef __ANDROID__
#include <android/looper.h>
#include <errno.h>
#include <stdint.h>
#include <unistd.h>

// libdispatch가 CoreFoundation 런루프용으로 내보내는 SPI. Linux/Android에서 핸들은 eventfd다.
// swift-corelibs-libdispatch src/queue.c, private/queue_private.h 참고.
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

bool ribs_android_attach_main_queue_to_looper(void) {
    if (attached) return true;
    ALooper *looper = ALooper_forThread();
    if (looper == 0) return false;
    int fd = _dispatch_get_main_queue_handle_4CF();
    if (fd < 0) return false;
    if (ALooper_addFd(looper, fd, ALOOPER_POLL_CALLBACK, ALOOPER_EVENT_INPUT, drain_main_queue, 0) != 1) return false;
    attached = true;
    return true;
}
#else
bool ribs_android_attach_main_queue_to_looper(void) { return false; }
#endif
