package com.carti.ribs.samples.todomodular.feature.todolist.ui

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
class TodoListViewTest {
    @get:Rule
    val compose = createComposeRule()

    @Test
    fun marksDoneRowsAndSendsSelectedId() {
        val selected = mutableListOf<Long>()
        val todos = listOf(TodoItem(1, "우유 사기", isDone = true), TodoItem(2, "운동하기", isDone = false))
        compose.setContent { TodoListView(todos = todos, onSelect = { selected += it }) }

        compose.onNodeWithTag(TodoListTags.todoRow(1)).assertTextEquals("✓ 우유 사기")
        compose.onNodeWithTag(TodoListTags.todoRow(2)).performClick()

        assertEquals(listOf(2L), selected)
    }

    @Test
    fun showsErrorWithRetryAndSendsRetry() {
        var retries = 0
        compose.setContent {
            TodoListView(todos = emptyList(), errorMessage = "할 일을 불러오지 못했습니다", onSelect = {}, onRetry = { retries += 1 })
        }

        compose.onNodeWithTag(TodoListTags.ERROR).assertTextEquals("할 일을 불러오지 못했습니다")
        compose.onNodeWithTag(TodoListTags.LOADING).assertDoesNotExist()
        compose.onNodeWithTag(TodoListTags.RETRY).performClick()

        assertEquals(1, retries)
    }

    @Test
    fun showsLoadingIndicatorWhileLoading() {
        compose.setContent { TodoListView(todos = emptyList(), isLoading = true, onSelect = {}) }

        compose.onNodeWithTag(TodoListTags.LOADING).assertExists()
        compose.onNodeWithTag(TodoListTags.ERROR).assertDoesNotExist()
        compose.onNodeWithTag(TodoListTags.NOTICE).assertDoesNotExist()
    }

    @Test
    fun showsNoticeWhenPresent() {
        compose.setContent {
            TodoListView(todos = emptyList(), notice = "2건을 가져왔습니다", onSelect = {})
        }

        compose.onNodeWithTag(TodoListTags.NOTICE).assertTextEquals("2건을 가져왔습니다")
    }
}
