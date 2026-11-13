#ifndef CRIBS_ANDROID_H
#define CRIBS_ANDROID_H

#include <stdbool.h>

/// 호출한 스레드의 ALooper에 libdispatch 메인 큐의 eventfd를 등록한다.
/// 이후 메인 큐에 작업이 들어오면 Looper가 깨어나 `_dispatch_main_queue_callback_4CF`로 비운다.
/// Android가 아닌 플랫폼에서는 아무것도 하지 않고 false를 돌려준다.
/// 반드시 Android 메인(UI) 스레드에서 한 번만 부른다. 두 번째 호출은 등록하지 않고 true를 돌려준다.
bool ribs_android_attach_main_queue_to_looper(void);

#endif
