package com.carti.ribs.samples.swiftandroid

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.carti.ribs.samples.swiftandroid.bridge.LoggedInScreenHandle
import com.carti.ribs.samples.swiftandroid.bridge.LoggedInViewBridge
import com.carti.ribs.samples.swiftandroid.bridge.LoggedOutScreenHandle
import com.carti.ribs.samples.swiftandroid.bridge.LoggedOutViewBridge
import com.carti.ribs.samples.swiftandroid.bridge.TodoDetailScreenHandle
import com.carti.ribs.samples.swiftandroid.bridge.TodoDetailViewBridge
import com.carti.ribs.samples.swiftandroid.bridge.TodoListScreenHandle
import com.carti.ribs.samples.swiftandroid.bridge.TodoListViewBridge
import com.carti.ribs.samples.swiftandroid.views.LoggedInView
import com.carti.ribs.samples.swiftandroid.views.LoggedOutView
import com.carti.ribs.samples.swiftandroid.views.TodoDetailView
import com.carti.ribs.samples.swiftandroid.views.TodoItem
import com.carti.ribs.samples.swiftandroid.views.TodoListView
import java.util.Optional
import org.json.JSONObject
import org.swift.swiftkit.core.SwiftArena

// 어댑터(ADR-0027). 화면마다 둘이다.
//   XxxAdapter: Swift `XxxViewBridge`를 구현해 Swift가 넘긴 값을 Compose 상태로 든다.
//   XxxScreen : 화면 핸들을 만들어 어댑터를 붙이고, 값과 콜백을 순수 뷰(`views/Views.kt`)에 넘긴다.
// 순수 뷰는 이 파일과 브리지 타입을 모른다.

/** Swift `ScreenKind`(AndroidLoginUI/Screens.swift)과 같은 문자열. */
private object Kind {
    const val ROOT = "root"
    const val LOGGED_OUT = "loggedOut"
    const val LOGGED_IN = "loggedIn"
    const val TODO_LIST = "todoList"
    const val TODO_DETAIL = "todoDetail"
}

/**
 * Swift 화면 트리의 노드 하나를 Compose로 그린다. 트리는 구조(`kind`, `id`, `child`)만 싣고,
 * 화면의 상태와 입력은 swift-java가 만든 화면별 핸들로 오간다.
 * 노드마다 `id`로 정체성을 줘서, 같은 종류의 새 RIB 화면이 오면 이전 화면의 `remember` 상태(입력 중인 이름 등)를 버린다.
 */
@Composable
fun RibNode(node: JSONObject?) {
    if (node == null || !node.has("kind")) return
    val id = node.getLong("id")
    key(id) {
        when (node.getString("kind")) {
            Kind.ROOT -> RibNode(node.optJSONObject("child"))
            Kind.LOGGED_OUT -> LoggedOutScreen(id)
            Kind.LOGGED_IN -> LoggedInScreen(id) { RibNode(node.optJSONObject("child")) }
            Kind.TODO_LIST -> TodoListScreen(id)
            Kind.TODO_DETAIL -> TodoDetailScreen(id)
            else -> error("Unknown screen kind: ${node.getString("kind")}")
        }
    }
}

/**
 * 화면 핸들을 만들어 어댑터를 붙이고, 화면이 컴포지션을 떠날 때 떼고 핸들의 Swift 메모리(arena)를 푼다.
 * 핸들 타입마다 `init`·`attach`·`detach`가 따로 생성되므로 함수로 받는다.
 */
@Composable
private fun <Handle> rememberAttachedHandle(
    create: (SwiftArena) -> Handle,
    attach: (Handle) -> Unit,
    detach: (Handle) -> Unit,
): Handle {
    val arena = remember { SwiftArena.ofConfined() }
    val handle = remember { create(arena) }
    DisposableEffect(handle) {
        attach(handle)
        onDispose {
            detach(handle)
            arena.close()
        }
    }
    return handle
}

/** Swift `LoggedOutViewBridge`(AndroidLogin/LoggedOutBridge.swift)의 구현. */
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

@Composable
private fun LoggedOutScreen(screenId: Long) {
    val adapter = remember { LoggedOutAdapter() }
    val handle = rememberAttachedHandle(
        create = { LoggedOutScreenHandle.init(screenId, it) },
        attach = { it.attach(adapter) },
        detach = { it.detach() },
    )
    LoggedOutView(errorMessage = adapter.errorMessage, isLoading = adapter.isLoading, onLogin = handle::loginTapped)
}

/** Swift `LoggedInViewBridge`(AndroidLogin/LoggedInBridge.swift)의 구현. */
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

/** 자식 화면(할 일 목록·상세)은 화면 트리의 `child`에서 온다. 순수 뷰에는 슬롯으로 넘긴다. */
@Composable
private fun LoggedInScreen(screenId: Long, child: @Composable () -> Unit) {
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

/**
 * Swift `TodoListViewBridge`(AndroidLogin/TodoListBridge.swift)의 구현.
 * 목록은 인자로 오지 않는다. 바뀌었다는 알림을 받으면 핸들에서 읽어 온다(이유는 Swift 쪽 주석 참고).
 * 순수 뷰는 이 사정을 모르고 `List<TodoItem>`만 받는다.
 */
private class TodoListAdapter : TodoListViewBridge {
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
private fun TodoListScreen(screenId: Long) {
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
    TodoListView(todos = adapter.todos, onSelect = handle::todoTapped)
}

/** Swift `TodoDetailViewBridge`(AndroidLogin/TodoDetailBridge.swift)의 구현. */
private class TodoDetailAdapter : TodoDetailViewBridge {
    var title: String by mutableStateOf("")
        private set
    var isDone: Boolean by mutableStateOf(false)
        private set

    override fun render(title: String, isDone: Boolean) {
        this.title = title
        this.isDone = isDone
    }
}

@Composable
private fun TodoDetailScreen(screenId: Long) {
    val adapter = remember { TodoDetailAdapter() }
    val handle = rememberAttachedHandle(
        create = { TodoDetailScreenHandle.init(screenId, it) },
        attach = { it.attach(adapter) },
        detach = { it.detach() },
    )
    TodoDetailView(
        title = adapter.title,
        isDone = adapter.isDone,
        onBack = handle::backTapped,
        onToggleDone = handle::toggleDoneTapped,
    )
}
