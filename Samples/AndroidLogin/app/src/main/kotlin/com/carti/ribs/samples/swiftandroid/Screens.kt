package com.carti.ribs.samples.swiftandroid

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.carti.ribs.samples.swiftandroid.bridge.LoggedInScreenHandle
import com.carti.ribs.samples.swiftandroid.bridge.LoggedInViewBridge
import com.carti.ribs.samples.swiftandroid.bridge.LoggedOutScreenHandle
import com.carti.ribs.samples.swiftandroid.bridge.LoggedOutViewBridge
import com.carti.ribs.samples.swiftandroid.bridge.TodoDetailScreenHandle
import com.carti.ribs.samples.swiftandroid.bridge.TodoDetailViewBridge
import com.carti.ribs.samples.swiftandroid.bridge.TodoListRow
import com.carti.ribs.samples.swiftandroid.bridge.TodoListScreenHandle
import com.carti.ribs.samples.swiftandroid.bridge.TodoListViewBridge
import java.util.Optional
import org.json.JSONObject
import org.swift.swiftkit.core.SwiftArena

/** 테스트와 화면이 같이 쓰는 태그. iOS·KMP 샘플과 이름을 맞췄다. */
object Tags {
    const val NAME_FIELD = "nameField"
    const val LOGIN_BUTTON = "loginButton"
    const val ERROR_LABEL = "errorLabel"
    const val LOADING_INDICATOR = "loadingIndicator"
    const val WELCOME_LABEL = "welcomeLabel"
    const val LOGOUT_BUTTON = "logoutButton"
    const val SESSION_LABEL = "sessionLabel"
    const val DETAIL_TITLE = "detailTitle"
    const val TOGGLE_DONE_BUTTON = "toggleDoneButton"
    const val BACK_BUTTON = "backButton"
    fun todoRow(id: Long): String = "todoRow-$id"
}

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
 * 화면 핸들을 만들어 뷰를 붙이고, 화면이 컴포지션을 떠날 때 떼고 핸들의 Swift 메모리(arena)를 푼다.
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

/** Swift `LoggedOutViewBridge`(AndroidLogin/LoggedOutBridge.swift)의 Compose 쪽 구현. Swift가 넘긴 값을 Compose 상태로 든다. */
private class LoggedOutView : LoggedOutViewBridge {
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
    var name by rememberSaveable { mutableStateOf("") }
    val view = remember { LoggedOutView() }
    val handle = rememberAttachedHandle(
        create = { LoggedOutScreenHandle.init(screenId, it) },
        attach = { it.attach(view) },
        detach = { it.detach() },
    )
    val isLoading = view.isLoading
    val error = view.errorMessage
    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("로그인", style = MaterialTheme.typography.headlineLarge)
        OutlinedTextField(
            value = name,
            onValueChange = { name = it },
            label = { Text("이름") },
            enabled = !isLoading,
            singleLine = true,
            modifier = Modifier.testTag(Tags.NAME_FIELD),
        )
        error?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.testTag(Tags.ERROR_LABEL)) }
        if (isLoading) CircularProgressIndicator(modifier = Modifier.testTag(Tags.LOADING_INDICATOR))
        Button(onClick = { handle.loginTapped(name) }, enabled = !isLoading, modifier = Modifier.testTag(Tags.LOGIN_BUTTON)) {
            Text("로그인")
        }
    }
}

/** Swift `LoggedInViewBridge`(AndroidLogin/LoggedInBridge.swift)의 Compose 쪽 구현. */
private class LoggedInView : LoggedInViewBridge {
    var userName: String by mutableStateOf("")
        private set
    var sessionSeconds: Long by mutableLongStateOf(0)
        private set

    override fun render(userName: String, sessionSeconds: Long) {
        this.userName = userName
        this.sessionSeconds = sessionSeconds
    }
}

/** 자식 화면(할 일 목록·상세)은 화면 트리의 `child`에서 오므로 `child` 슬롯으로 받는다. */
@Composable
private fun LoggedInScreen(screenId: Long, child: @Composable () -> Unit) {
    val view = remember { LoggedInView() }
    val handle = rememberAttachedHandle(
        create = { LoggedInScreenHandle.init(screenId, it) },
        attach = { it.attach(view) },
        detach = { it.detach() },
    )
    Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(
            "${view.userName}님, 환영합니다",
            style = MaterialTheme.typography.headlineSmall,
            modifier = Modifier.testTag(Tags.WELCOME_LABEL),
        )
        Text("로그인 ${view.sessionSeconds}초", modifier = Modifier.testTag(Tags.SESSION_LABEL))
        OutlinedButton(onClick = { handle.logoutTapped() }, modifier = Modifier.testTag(Tags.LOGOUT_BUTTON)) { Text("로그아웃") }
        child()
    }
}

private data class TodoItem(val id: Long, val title: String, val isDone: Boolean)

/**
 * Swift `TodoListViewBridge`(AndroidLogin/TodoListBridge.swift)의 Compose 쪽 구현.
 * 목록은 인자로 오지 않는다. 바뀌었다는 알림을 받으면 핸들에서 읽어 온다(이유는 Swift 쪽 주석 참고).
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
private fun TodoListScreen(screenId: Long) {
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
            TextButton(onClick = { handle.todoTapped(todo.id) }, modifier = Modifier.testTag(Tags.todoRow(todo.id))) {
                Text((if (todo.isDone) "✓ " else "") + todo.title)
            }
        }
    }
}

/** Swift `TodoDetailViewBridge`(AndroidLogin/TodoDetailBridge.swift)의 Compose 쪽 구현. */
private class TodoDetailView : TodoDetailViewBridge {
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
    val view = remember { TodoDetailView() }
    val handle = rememberAttachedHandle(
        create = { TodoDetailScreenHandle.init(screenId, it) },
        attach = { it.attach(view) },
        detach = { it.detach() },
    )
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        TextButton(onClick = { handle.backTapped() }, modifier = Modifier.testTag(Tags.BACK_BUTTON)) { Text("← 목록") }
        Text(view.title, style = MaterialTheme.typography.titleLarge, modifier = Modifier.testTag(Tags.DETAIL_TITLE))
        Button(onClick = { handle.toggleDoneTapped() }, modifier = Modifier.testTag(Tags.TOGGLE_DONE_BUTTON)) {
            Text(if (view.isDone) "완료 취소" else "완료로 표시")
        }
    }
}
