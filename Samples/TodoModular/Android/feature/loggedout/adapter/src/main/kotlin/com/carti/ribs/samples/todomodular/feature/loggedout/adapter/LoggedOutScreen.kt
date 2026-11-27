package com.carti.ribs.samples.todomodular.feature.loggedout.adapter

import androidx.compose.runtime.Composable
import com.carti.ribs.samples.todomodular.core.SwiftBridge
import com.carti.ribs.samples.todomodular.core.rememberChannelState
import com.carti.ribs.samples.todomodular.feature.loggedout.ui.LoggedOutView
import com.carti.ribs.samples.todomodular.generated.LoggedOutViewAction
import com.carti.ribs.samples.todomodular.generated.LoggedOutViewState

/** Swift `LoggedOutAndroidViewFactory.kind`와 같은 문자열. */
const val LOGGED_OUT_KIND = "loggedOut"

/** 단일 채널로 상태를 구독하고 액션을 전송해 순수 뷰(`:feature:loggedout:ui`)에 넘긴다. */
@Composable
fun LoggedOutScreen(screenId: Long) {
    val state = rememberChannelState(
        screenId = screenId,
        kind = LOGGED_OUT_KIND,
        initial = LoggedOutViewState(errorMessage = null, isLoading = false),
        decode = LoggedOutViewState::fromJson,
    )
    LoggedOutView(
        errorMessage = state.errorMessage,
        isLoading = state.isLoading,
        onLogin = { rawName ->
            SwiftBridge.dispatchAction(
                screenId,
                LOGGED_OUT_KIND,
                LoggedOutViewAction.LoginTapped(rawName = rawName).toJson().toString(),
            )
        },
    )
}
