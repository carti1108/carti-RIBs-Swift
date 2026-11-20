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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.carti.ribs.samples.swiftandroid.bridge.LoggedOutScreenHandle
import com.carti.ribs.samples.swiftandroid.bridge.LoggedOutViewBridge
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

/** Swift `ScreenKind`·`ScreenAction`(AndroidLoginUI/Screens.swift)과 같은 문자열. */
private object Kind {
    const val ROOT = "root"
    const val LOGGED_OUT = "loggedOut"
    const val LOGGED_IN = "loggedIn"
    const val TODO_LIST = "todoList"
    const val TODO_DETAIL = "todoDetail"
}

private object Action {
    const val LOGOUT = "logout"
    const val SELECT_TODO = "selectTodo"
    const val TOGGLE_DONE = "toggleDone"
    const val BACK = "back"
}

typealias Send = (screenId: Long, action: String, argument: String) -> Unit

/**
 * Swift가 그린 화면 노드 하나를 Compose로 그린다. 노드마다 `id`로 정체성을 줘서,
 * 같은 종류의 새 RIB 화면이 오면 이전 화면의 `remember` 상태(입력 중인 이름 등)를 버린다.
 */
@Composable
fun RibNode(node: JSONObject?, send: Send) {
    if (node == null || !node.has("kind")) return
    val id = node.getLong("id")
    key(id) {
        when (node.getString("kind")) {
            Kind.ROOT -> RibNode(node.optJSONObject("child"), send)
            Kind.LOGGED_OUT -> LoggedOutScreen(id)
            Kind.LOGGED_IN -> LoggedInScreen(node, send) { send(id, Action.LOGOUT, "") }
            Kind.TODO_LIST -> TodoListScreen(node) { send(id, Action.SELECT_TODO, it.toString()) }
            Kind.TODO_DETAIL -> TodoDetailScreen(
                node,
                onToggle = { send(id, Action.TOGGLE_DONE, "") },
                onBack = { send(id, Action.BACK, "") },
            )
            else -> error("Unknown screen kind: ${node.getString("kind")}")
        }
    }
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

/**
 * 화면 트리에서는 `id`만 받는다. 상태와 입력은 swift-java가 만든 `LoggedOutScreenHandle`로 오간다.
 * 핸들의 Swift 메모리는 화면이 컴포지션을 떠날 때 arena를 닫아 푼다.
 */
@Composable
private fun LoggedOutScreen(screenId: Long) {
    var name by rememberSaveable { mutableStateOf("") }
    val view = remember { LoggedOutView() }
    val arena = remember { SwiftArena.ofConfined() }
    val handle = remember { LoggedOutScreenHandle.init(screenId, arena) }
    DisposableEffect(handle) {
        handle.attach(view)
        onDispose {
            handle.detach()
            arena.close()
        }
    }
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

@Composable
private fun LoggedInScreen(node: JSONObject, send: Send, onLogout: () -> Unit) {
    Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(
            "${node.getString("userName")}님, 환영합니다",
            style = MaterialTheme.typography.headlineSmall,
            modifier = Modifier.testTag(Tags.WELCOME_LABEL),
        )
        Text("로그인 ${node.getLong("sessionSeconds")}초", modifier = Modifier.testTag(Tags.SESSION_LABEL))
        OutlinedButton(onClick = onLogout, modifier = Modifier.testTag(Tags.LOGOUT_BUTTON)) { Text("로그아웃") }
        RibNode(node.optJSONObject("child"), send)
    }
}

@Composable
private fun TodoListScreen(node: JSONObject, onSelect: (Long) -> Unit) {
    val todos = node.getJSONArray("todos")
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        for (index in 0 until todos.length()) {
            val todo = todos.getJSONObject(index)
            val todoId = todo.getLong("id")
            TextButton(onClick = { onSelect(todoId) }, modifier = Modifier.testTag(Tags.todoRow(todoId))) {
                Text((if (todo.getBoolean("isDone")) "✓ " else "") + todo.getString("title"))
            }
        }
    }
}

@Composable
private fun TodoDetailScreen(node: JSONObject, onToggle: () -> Unit, onBack: () -> Unit) {
    val isDone = node.getBoolean("isDone")
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        TextButton(onClick = onBack, modifier = Modifier.testTag(Tags.BACK_BUTTON)) { Text("← 목록") }
        Text(node.getString("title"), style = MaterialTheme.typography.titleLarge, modifier = Modifier.testTag(Tags.DETAIL_TITLE))
        Button(onClick = onToggle, modifier = Modifier.testTag(Tags.TOGGLE_DONE_BUTTON)) {
            Text(if (isDone) "완료 취소" else "완료로 표시")
        }
    }
}
