package com.carti.ribs.samples.todomodular.feature.todolist.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp

// 순수 뷰(ADR-0027). 값과 콜백만 받아 그린다. 이 모듈은 `:bridge`에 의존하지 않아 Swift 런타임 없이 미리보기와 테스트가 된다.

object TodoListTags {
    const val LOADING: String = "todoLoadingIndicator"
    const val ERROR: String = "todoErrorLabel"
    const val RETRY: String = "todoRetryButton"
    const val NOTICE: String = "todoNoticeLabel"

    fun todoRow(id: Long): String = "todoRow-$id"
}

/** 목록 한 줄. 뷰가 정의하고 어댑터가 채운다. */
data class TodoItem(val id: Long, val title: String, val isDone: Boolean)

@Composable
fun TodoListView(
    todos: List<TodoItem>,
    onSelect: (Long) -> Unit,
    isLoading: Boolean = false,
    errorMessage: String? = null,
    notice: String? = null,
    onRetry: () -> Unit = {},
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        if (isLoading) {
            CircularProgressIndicator(modifier = Modifier.testTag(TodoListTags.LOADING))
        }
        if (errorMessage != null) {
            Text(errorMessage, color = MaterialTheme.colorScheme.error, modifier = Modifier.testTag(TodoListTags.ERROR))
            OutlinedButton(onClick = onRetry, modifier = Modifier.testTag(TodoListTags.RETRY)) { Text("다시 시도") }
        }
        if (notice != null) {
            Text(
                notice,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.secondary,
                modifier = Modifier.testTag(TodoListTags.NOTICE),
            )
        }
        for (todo in todos) {
            TextButton(onClick = { onSelect(todo.id) }, modifier = Modifier.testTag(TodoListTags.todoRow(todo.id))) {
                Text((if (todo.isDone) "✓ " else "") + todo.title)
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun TodoListViewPreview() {
    MaterialTheme {
        TodoListView(
            todos = listOf(TodoItem(1, "우유 사기", isDone = true), TodoItem(2, "RIB 문서 읽기", isDone = false)),
            onSelect = {},
        )
    }
}
