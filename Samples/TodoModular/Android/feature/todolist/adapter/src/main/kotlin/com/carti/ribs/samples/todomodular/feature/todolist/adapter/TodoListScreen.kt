package com.carti.ribs.samples.todomodular.feature.todolist.adapter

import androidx.compose.runtime.Composable
import com.carti.ribs.samples.todomodular.core.SwiftBridge
import com.carti.ribs.samples.todomodular.core.rememberChannelState
import com.carti.ribs.samples.todomodular.feature.todolist.ui.TodoItem
import com.carti.ribs.samples.todomodular.feature.todolist.ui.TodoListView
import com.carti.ribs.samples.todomodular.generated.TodoListViewAction
import com.carti.ribs.samples.todomodular.generated.TodoListViewState

/** Swift `TodoListAndroidViewFactory.kind`와 같은 문자열. */
const val TODO_LIST_KIND = "todoList"

@Composable
fun TodoListScreen(screenId: Long) {
    val state = rememberChannelState(
        screenId = screenId,
        kind = TODO_LIST_KIND,
        initial = TodoListViewState(todos = emptyList(), isLoading = false, errorMessage = null, notice = null),
        decode = TodoListViewState::fromJson,
    )
    TodoListView(
        todos = state.todos.map { TodoItem(it.id, it.title, it.isDone) },
        onSelect = { id ->
            SwiftBridge.dispatchAction(
                screenId,
                TODO_LIST_KIND,
                TodoListViewAction.TodoTapped(id = id).toJson().toString(),
            )
        },
        isLoading = state.isLoading,
        errorMessage = state.errorMessage,
        notice = state.notice,
        onRetry = {
            SwiftBridge.dispatchAction(
                screenId,
                TODO_LIST_KIND,
                TodoListViewAction.RetryTapped.toJson().toString(),
            )
        },
    )
}
