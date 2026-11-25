package com.carti.ribs.samples.todomodular.feature.tododetail.ui

import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** 이 모듈의 테스트 APK에는 Swift 라이브러리가 없다. 뷰가 값과 콜백만으로 그려지는지 확인한다(ADR-0027). */
@RunWith(AndroidJUnit4::class)
class TodoDetailViewTest {
    @get:Rule
    val compose = createComposeRule()

    @Test
    fun showsToggleLabelAndSendsInputs() {
        val events = mutableListOf<String>()
        compose.setContent {
            TodoDetailView(title = "우유 사기", isDone = true, onBack = { events += "back" }, onToggleDone = { events += "toggle" })
        }

        compose.onNodeWithTag(TodoDetailTags.DETAIL_TITLE).assertTextEquals("우유 사기")
        compose.onNodeWithTag(TodoDetailTags.TOGGLE_DONE_BUTTON).assertTextEquals("완료 취소")
        compose.onNodeWithTag(TodoDetailTags.TOGGLE_DONE_BUTTON).performClick()
        compose.onNodeWithTag(TodoDetailTags.BACK_BUTTON).performClick()

        assertEquals(listOf("toggle", "back"), events)
    }
}
