package com.carti.ribs.samples.swiftandroid.views

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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp

// 순수 뷰(ADR-0027). 값과 콜백만 받아 그린다. 이 패키지는 Swift 브리지 타입(`...bridge.*`)과
// `org.swift.swiftkit`을 import하지 않는다. 그래서 Swift 런타임 없이 미리보기와 테스트가 된다.
// 공유 코드의 계약을 구현하고 이 뷰에 값을 넘기는 일은 `Screens.kt`의 어댑터가 한다.

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

/** 입력 중인 이름은 뷰가 들고 있다가 로그인 때 넘긴다. */
@Composable
fun LoggedOutView(errorMessage: String?, isLoading: Boolean, onLogin: (String) -> Unit) {
    var name by rememberSaveable { mutableStateOf("") }
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
        errorMessage?.let {
            Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.testTag(Tags.ERROR_LABEL))
        }
        if (isLoading) CircularProgressIndicator(modifier = Modifier.testTag(Tags.LOADING_INDICATOR))
        Button(onClick = { onLogin(name) }, enabled = !isLoading, modifier = Modifier.testTag(Tags.LOGIN_BUTTON)) {
            Text("로그인")
        }
    }
}

/** 자식 화면(할 일 목록·상세)은 `child` 슬롯으로 받는다. 무엇이 들어오는지 모른다. */
@Composable
fun LoggedInView(userName: String, sessionSeconds: Long, onLogout: () -> Unit, child: @Composable () -> Unit) {
    Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(
            "${userName}님, 환영합니다",
            style = MaterialTheme.typography.headlineSmall,
            modifier = Modifier.testTag(Tags.WELCOME_LABEL),
        )
        Text("로그인 ${sessionSeconds}초", modifier = Modifier.testTag(Tags.SESSION_LABEL))
        OutlinedButton(onClick = onLogout, modifier = Modifier.testTag(Tags.LOGOUT_BUTTON)) { Text("로그아웃") }
        child()
    }
}

/** 목록 한 줄. 뷰가 정의하고 어댑터가 채운다. */
data class TodoItem(val id: Long, val title: String, val isDone: Boolean)

@Composable
fun TodoListView(todos: List<TodoItem>, onSelect: (Long) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        for (todo in todos) {
            TextButton(onClick = { onSelect(todo.id) }, modifier = Modifier.testTag(Tags.todoRow(todo.id))) {
                Text((if (todo.isDone) "✓ " else "") + todo.title)
            }
        }
    }
}

/** 뒤로 버튼은 닫기를 요청만 한다. */
@Composable
fun TodoDetailView(title: String, isDone: Boolean, onBack: () -> Unit, onToggleDone: () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        TextButton(onClick = onBack, modifier = Modifier.testTag(Tags.BACK_BUTTON)) { Text("← 목록") }
        Text(title, style = MaterialTheme.typography.titleLarge, modifier = Modifier.testTag(Tags.DETAIL_TITLE))
        Button(onClick = onToggleDone, modifier = Modifier.testTag(Tags.TOGGLE_DONE_BUTTON)) {
            Text(if (isDone) "완료 취소" else "완료로 표시")
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun LoggedOutViewPreview() {
    MaterialTheme { LoggedOutView(errorMessage = "이름을 입력하세요", isLoading = false, onLogin = {}) }
}

@Preview(showBackground = true)
@Composable
private fun LoggedInViewPreview() {
    MaterialTheme {
        LoggedInView(userName = "carti", sessionSeconds = 12, onLogout = {}) {
            TodoListView(
                todos = listOf(TodoItem(1, "우유 사기", isDone = true), TodoItem(2, "RIB 문서 읽기", isDone = false)),
                onSelect = {},
            )
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun TodoDetailViewPreview() {
    MaterialTheme { TodoDetailView(title = "우유 사기", isDone = false, onBack = {}, onToggleDone = {}) }
}
