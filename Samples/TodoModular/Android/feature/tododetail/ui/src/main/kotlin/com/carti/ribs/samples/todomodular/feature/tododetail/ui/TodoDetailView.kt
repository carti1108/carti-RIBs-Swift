package com.carti.ribs.samples.todomodular.feature.tododetail.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp

// 순수 뷰(ADR-0027). 값과 콜백만 받아 그린다. 이 모듈은 `:bridge`에 의존하지 않아 Swift 런타임 없이 미리보기와 테스트가 된다.

object TodoDetailTags {
    const val DETAIL_TITLE = "detailTitle"
    const val TOGGLE_DONE_BUTTON = "toggleDoneButton"
    const val BACK_BUTTON = "backButton"
}

/** 뒤로 버튼은 닫기를 요청만 한다. */
@Composable
fun TodoDetailView(title: String, isDone: Boolean, onBack: () -> Unit, onToggleDone: () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        TextButton(onClick = onBack, modifier = Modifier.testTag(TodoDetailTags.BACK_BUTTON)) { Text("← 목록") }
        Text(title, style = MaterialTheme.typography.titleLarge, modifier = Modifier.testTag(TodoDetailTags.DETAIL_TITLE))
        Button(onClick = onToggleDone, modifier = Modifier.testTag(TodoDetailTags.TOGGLE_DONE_BUTTON)) {
            Text(if (isDone) "완료 취소" else "완료로 표시")
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun TodoDetailViewPreview() {
    MaterialTheme { TodoDetailView(title = "우유 사기", isDone = false, onBack = {}, onToggleDone = {}) }
}
