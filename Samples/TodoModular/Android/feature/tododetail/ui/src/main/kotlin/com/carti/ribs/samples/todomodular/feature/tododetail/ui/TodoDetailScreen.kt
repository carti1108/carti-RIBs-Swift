package com.carti.ribs.samples.todomodular.feature.tododetail.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
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
import com.carti.ribs.samples.todomodular.swiftbridge.TodoDetailScreenHandle
import com.carti.ribs.samples.todomodular.swiftbridge.TodoDetailViewBridge

/** Swift `TodoDetailAndroidViewFactory.kind`와 같은 문자열. */
const val TODO_DETAIL_KIND = "todoDetail"

object TodoDetailTags {
    const val DETAIL_TITLE = "detailTitle"
    const val TOGGLE_DONE_BUTTON = "toggleDoneButton"
    const val BACK_BUTTON = "backButton"
}

/** Swift `TodoDetailViewBridge`의 Compose 쪽 구현. */
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

/** 뒤로 버튼은 닫기를 요청만 하고, 닫는 일은 부모 RIB이 한다. */
@Composable
fun TodoDetailScreen(screenId: Long) {
    val view = remember { TodoDetailView() }
    val handle = rememberAttachedHandle(
        create = { TodoDetailScreenHandle.init(screenId, it) },
        attach = { it.attach(view) },
        detach = { it.detach() },
    )
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        TextButton(onClick = { handle.backTapped() }, modifier = Modifier.testTag(TodoDetailTags.BACK_BUTTON)) { Text("← 목록") }
        Text(view.title, style = MaterialTheme.typography.titleLarge, modifier = Modifier.testTag(TodoDetailTags.DETAIL_TITLE))
        Button(onClick = { handle.toggleDoneTapped() }, modifier = Modifier.testTag(TodoDetailTags.TOGGLE_DONE_BUTTON)) {
            Text(if (view.isDone) "완료 취소" else "완료로 표시")
        }
    }
}
