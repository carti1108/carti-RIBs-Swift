package com.carti.ribs.samples.todomodular.feature.todolist.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.carti.ribs.samples.todomodular.core.rememberAttachedHandle
import com.carti.ribs.samples.todomodular.swiftbridge.TodoListScreenHandle
import com.carti.ribs.samples.todomodular.swiftbridge.TodoListViewBridge
import org.swift.swiftkit.core.SwiftArena

/** Swift `TodoListAndroidViewFactory.kind`와 같은 문자열. */
const val TODO_LIST_KIND = "todoList"

object TodoListTags {
    fun todoRow(id: Long): String = "todoRow-$id"
}

private data class TodoItem(val id: Long, val title: String, val isDone: Boolean)

/**
 * Swift `TodoListViewBridge`의 Compose 쪽 구현.
 * 목록은 인자로 오지 않는다. 바뀌었다는 알림을 받으면 핸들에서 읽어 온다(이유는 Swift `TodoListHandle.swift` 주석 참고).
 */
private class TodoListView : TodoListViewBridge {
    var todos: List<TodoItem> by mutableStateOf(emptyList())
        private set
    var handle: TodoListScreenHandle? = null

    /** `TodoListRow`는 Swift 메모리를 가리키므로 값을 복사한 뒤 바로 arena를 닫는다. */
    override fun rowsChanged() {
        val handle = handle ?: return
        todos = SwiftArena.ofConfined().use { arena ->
            handle.rows(arena).map { TodoItem(it.id, it.title, it.isDone) }
        }
    }
}

@Composable
fun TodoListScreen(screenId: Long) {
    val view = remember { TodoListView() }
    val handle = rememberAttachedHandle(
        create = { TodoListScreenHandle.init(screenId, it) },
        attach = {
            view.handle = it
            it.attach(view)
        },
        detach = {
            it.detach()
            view.handle = null
        },
    )
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        for (todo in view.todos) {
            TextButton(onClick = { handle.todoTapped(todo.id) }, modifier = Modifier.testTag(TodoListTags.todoRow(todo.id))) {
                Text((if (todo.isDone) "✓ " else "") + todo.title)
            }
        }
    }
}
