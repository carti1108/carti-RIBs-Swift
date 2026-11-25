package com.carti.ribs.samples.todomodular.feature.todolist.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp

// 순수 뷰(ADR-0027). 값과 콜백만 받아 그린다. 이 모듈은 `:bridge`에 의존하지 않아 Swift 런타임 없이 미리보기와 테스트가 된다.

object TodoListTags {
    fun todoRow(id: Long): String = "todoRow-$id"
}

/** 목록 한 줄. 뷰가 정의하고 어댑터가 채운다. */
data class TodoItem(val id: Long, val title: String, val isDone: Boolean)

@Composable
fun TodoListView(todos: List<TodoItem>, onSelect: (Long) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
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
