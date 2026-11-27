package com.carti.ribs.samples.todomodular.feature.loggedin.adapter

import androidx.compose.runtime.Composable
import com.carti.ribs.samples.todomodular.core.SwiftBridge
import com.carti.ribs.samples.todomodular.core.rememberChannelState
import com.carti.ribs.samples.todomodular.feature.loggedin.ui.LoggedInView
import com.carti.ribs.samples.todomodular.generated.LoggedInViewAction
import com.carti.ribs.samples.todomodular.generated.LoggedInViewState

/** Swift `LoggedInAndroidViewFactory.kind`와 같은 문자열. */
const val LOGGED_IN_KIND = "loggedIn"

/** 자식 화면(목록·상세)은 화면 트리의 `child`에서 온다. 순수 뷰에는 슬롯으로 넘긴다. */
@Composable
fun LoggedInScreen(screenId: Long, child: @Composable () -> Unit) {
    val state = rememberChannelState(
        screenId = screenId,
        kind = LOGGED_IN_KIND,
        initial = LoggedInViewState(userName = "", sessionSeconds = 0),
        decode = LoggedInViewState::fromJson,
    )
    LoggedInView(
        userName = state.userName,
        sessionSeconds = state.sessionSeconds,
        onLogout = {
            SwiftBridge.dispatchAction(
                screenId,
                LOGGED_IN_KIND,
                LoggedInViewAction.LogoutTapped.toJson().toString(),
            )
        },
        child = child,
    )
}
