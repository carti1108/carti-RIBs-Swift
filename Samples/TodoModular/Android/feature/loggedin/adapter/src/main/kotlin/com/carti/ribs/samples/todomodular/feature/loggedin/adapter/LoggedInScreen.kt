package com.carti.ribs.samples.todomodular.feature.loggedin.adapter

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.carti.ribs.samples.todomodular.core.rememberAttachedHandle
import com.carti.ribs.samples.todomodular.feature.loggedin.ui.LoggedInView
import com.carti.ribs.samples.todomodular.swiftbridge.LoggedInScreenHandle
import com.carti.ribs.samples.todomodular.swiftbridge.LoggedInViewBridge

/** Swift `LoggedInAndroidViewFactory.kind`와 같은 문자열. */
const val LOGGED_IN_KIND = "loggedIn"

/** Swift `LoggedInViewBridge`의 구현. */
private class LoggedInAdapter : LoggedInViewBridge {
    var userName: String by mutableStateOf("")
        private set
    var sessionSeconds: Long by mutableLongStateOf(0)
        private set

    override fun render(userName: String, sessionSeconds: Long) {
        this.userName = userName
        this.sessionSeconds = sessionSeconds
    }
}

/** 자식 화면(목록·상세)은 화면 트리의 `child`에서 온다. 순수 뷰에는 슬롯으로 넘긴다. */
@Composable
fun LoggedInScreen(screenId: Long, child: @Composable () -> Unit) {
    val adapter = remember { LoggedInAdapter() }
    val handle = rememberAttachedHandle(
        create = { LoggedInScreenHandle.init(screenId, it) },
        attach = { it.attach(adapter) },
        detach = { it.detach() },
    )
    LoggedInView(
        userName = adapter.userName,
        sessionSeconds = adapter.sessionSeconds,
        onLogout = handle::logoutTapped,
        child = child,
    )
}
