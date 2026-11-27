package com.carti.ribs.samples.todomodular.feature.todolist.adapter

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.carti.ribs.samples.todomodular.core.rememberAttachedHandle
import com.carti.ribs.samples.todomodular.feature.todolist.ui.TodoItem
import com.carti.ribs.samples.todomodular.feature.todolist.ui.TodoListView
import com.carti.ribs.samples.todomodular.swiftbridge.TodoListScreenHandle
import com.carti.ribs.samples.todomodular.swiftbridge.TodoListViewBridge
import org.swift.swiftkit.core.SwiftArena

/** Swift `TodoListAndroidViewFactory.kind`와 같은 문자열. */
const val TODO_LIST_KIND = "todoList"

/**
 * Swift `TodoListViewBridge`의 구현.
 * 목록은 인자로 오지 않는다. 바뀌었다는 알림을 받으면 핸들에서 읽어 온다(이유는 Swift `TodoListHandle.swift` 주석 참고).
 * 순수 뷰는 이 사정을 모르고 `List<TodoItem>`만 받는다.
 */
private class TodoListAdapter : TodoListViewBridge {
    var todos: List<TodoItem> by mutableStateOf(emptyList())
        private set
    var isLoading: Boolean by mutableStateOf(false)
        private set
    var errorMessage: String? by mutableStateOf(null)
        private set
    var notice: String? by mutableStateOf(null)
        private set
    var handle: TodoListScreenHandle? = null

    override fun render(
        isLoading: Boolean,
        errorMessage: java.util.Optional<String>,
        notice: java.util.Optional<String>,
    ) {
        this.isLoading = isLoading
        this.errorMessage = errorMessage.orElse(null)
        this.notice = notice.orElse(null)
    }

    /** `TodoListTodo`는 Swift 메모리를 가리키므로 값을 복사한 뒤 바로 arena를 닫는다. */
    override fun todosChanged() {
        val handle = handle ?: return
        todos = SwiftArena.ofConfined().use { arena ->
            handle.todos(arena).map { TodoItem(it.id, it.title, it.isDone) }
        }
    }
}

@Composable
fun TodoListScreen(screenId: Long) {
    val adapter = remember { TodoListAdapter() }
    val handle = rememberAttachedHandle(
        create = { TodoListScreenHandle.init(screenId, it) },
        attach = {
            adapter.handle = it
            it.attach(adapter)
        },
        detach = {
            it.detach()
            adapter.handle = null
        },
    )
    TodoListView(
        todos = adapter.todos,
        onSelect = handle::todoTapped,
        isLoading = adapter.isLoading,
        errorMessage = adapter.errorMessage,
        notice = adapter.notice,
        onRetry = handle::retryTapped,
    )
}
