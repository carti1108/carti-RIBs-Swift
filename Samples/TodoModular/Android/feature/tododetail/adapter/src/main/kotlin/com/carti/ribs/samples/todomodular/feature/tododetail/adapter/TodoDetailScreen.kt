package com.carti.ribs.samples.todomodular.feature.tododetail.adapter

import androidx.compose.runtime.Composable
import com.carti.ribs.samples.todomodular.core.SwiftBridge
import com.carti.ribs.samples.todomodular.core.rememberChannelState
import com.carti.ribs.samples.todomodular.feature.tododetail.ui.TodoDetailView
import com.carti.ribs.samples.todomodular.generated.TodoDetailViewAction
import com.carti.ribs.samples.todomodular.generated.TodoDetailViewState

/** Swift `TodoDetailAndroidViewFactory.kind`와 같은 문자열. */
const val TODO_DETAIL_KIND = "todoDetail"

@Composable
fun TodoDetailScreen(screenId: Long) {
    val state = rememberChannelState(
        screenId = screenId,
        kind = TODO_DETAIL_KIND,
        initial = TodoDetailViewState(title = "", isDone = false, notice = null),
        decode = TodoDetailViewState::fromJson,
    )
    TodoDetailView(
        title = state.title,
        isDone = state.isDone,
        notice = state.notice,
        onBack = {
            SwiftBridge.dispatchAction(
                screenId,
                TODO_DETAIL_KIND,
                TodoDetailViewAction.BackTapped.toJson().toString(),
            )
        },
        onToggleDone = {
            SwiftBridge.dispatchAction(
                screenId,
                TODO_DETAIL_KIND,
                TodoDetailViewAction.ToggleDoneTapped.toJson().toString(),
            )
        },
    )
}
