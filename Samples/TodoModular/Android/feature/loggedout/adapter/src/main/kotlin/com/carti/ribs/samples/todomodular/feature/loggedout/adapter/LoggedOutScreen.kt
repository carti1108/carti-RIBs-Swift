package com.carti.ribs.samples.todomodular.feature.loggedout.adapter

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.carti.ribs.samples.todomodular.core.rememberAttachedHandle
import com.carti.ribs.samples.todomodular.feature.loggedout.ui.LoggedOutView
import com.carti.ribs.samples.todomodular.swiftbridge.LoggedOutScreenHandle
import com.carti.ribs.samples.todomodular.swiftbridge.LoggedOutViewBridge
import java.util.Optional

/** Swift `LoggedOutAndroidViewFactory.kind`와 같은 문자열. */
const val LOGGED_OUT_KIND = "loggedOut"

/** Swift `LoggedOutViewBridge`의 구현. Swift가 넘긴 값을 Compose 상태로 든다. */
private class LoggedOutAdapter : LoggedOutViewBridge {
    var errorMessage: String? by mutableStateOf(null)
        private set
    var isLoading: Boolean by mutableStateOf(false)
        private set

    override fun render(errorMessage: Optional<String>, isLoading: Boolean) {
        this.errorMessage = errorMessage.orElse(null)
        this.isLoading = isLoading
    }
}

/** 화면 핸들에 어댑터를 붙이고, 값과 콜백을 순수 뷰(`:feature:loggedout:ui`)에 넘긴다. */
@Composable
fun LoggedOutScreen(screenId: Long) {
    val adapter = remember { LoggedOutAdapter() }
    val handle = rememberAttachedHandle(
        create = { LoggedOutScreenHandle.init(screenId, it) },
        attach = { it.attach(adapter) },
        detach = { it.detach() },
    )
    LoggedOutView(errorMessage = adapter.errorMessage, isLoading = adapter.isLoading, onLogin = handle::loginTapped)
}
