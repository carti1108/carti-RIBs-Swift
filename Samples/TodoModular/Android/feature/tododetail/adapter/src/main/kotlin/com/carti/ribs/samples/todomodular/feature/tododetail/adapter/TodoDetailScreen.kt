package com.carti.ribs.samples.todomodular.feature.tododetail.adapter

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.carti.ribs.samples.todomodular.core.rememberAttachedHandle
import com.carti.ribs.samples.todomodular.feature.tododetail.ui.TodoDetailView
import com.carti.ribs.samples.todomodular.swiftbridge.TodoDetailScreenHandle
import com.carti.ribs.samples.todomodular.swiftbridge.TodoDetailViewBridge

/** Swift `TodoDetailAndroidViewFactory.kind`와 같은 문자열. */
const val TODO_DETAIL_KIND = "todoDetail"

/** Swift `TodoDetailViewBridge`의 구현. */
private class TodoDetailAdapter : TodoDetailViewBridge {
    var title: String by mutableStateOf("")
        private set
    var isDone: Boolean by mutableStateOf(false)
        private set
    var notice: String? by mutableStateOf(null)
        private set

    override fun render(title: String, isDone: Boolean, notice: java.util.Optional<String>) {
        this.title = title
        this.isDone = isDone
        this.notice = notice.orElse(null)
    }
}

@Composable
fun TodoDetailScreen(screenId: Long) {
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
        notice = adapter.notice,
    )
}
