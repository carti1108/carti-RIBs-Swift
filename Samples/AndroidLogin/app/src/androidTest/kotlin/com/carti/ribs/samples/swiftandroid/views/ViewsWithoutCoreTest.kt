package com.carti.ribs.samples.swiftandroid.views

import androidx.compose.material3.Text
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 순수 뷰는 값과 콜백만으로 그려진다. `MainActivity`를 띄우지 않으므로 Swift RIB 트리도 화면 핸들도 없다(ADR-0027).
 */
@RunWith(AndroidJUnit4::class)
class ViewsWithoutCoreTest {
    @get:Rule
    val compose = createComposeRule()

    @Test
    fun loggedOutShowsErrorAndSendsTypedName() {
        val logins = mutableListOf<String>()
        compose.setContent { LoggedOutView(errorMessage = "오류", isLoading = false, onLogin = { logins += it }) }

        compose.onNodeWithTag(Tags.ERROR_LABEL).assertTextEquals("오류")
        compose.onNodeWithTag(Tags.NAME_FIELD).performTextInput("carti")
        compose.onNodeWithTag(Tags.LOGIN_BUTTON).performClick()

        assertEquals(listOf("carti"), logins)
    }

    @Test
    fun loggedOutDisablesInputWhileLoading() {
        compose.setContent { LoggedOutView(errorMessage = null, isLoading = true, onLogin = {}) }

        compose.onNodeWithTag(Tags.LOADING_INDICATOR).assertExists()
        compose.onNodeWithTag(Tags.LOGIN_BUTTON).assertIsNotEnabled()
        compose.onNodeWithTag(Tags.ERROR_LABEL).assertDoesNotExist()
    }

    @Test
    fun loggedInDrawsHeaderAndChildSlot() {
        var logouts = 0
        compose.setContent {
            LoggedInView(userName = "carti", sessionSeconds = 3, onLogout = { logouts += 1 }) { Text("자식 화면") }
        }

        compose.onNodeWithTag(Tags.WELCOME_LABEL).assertTextEquals("carti님, 환영합니다")
        compose.onNodeWithTag(Tags.SESSION_LABEL).assertTextEquals("로그인 3초")
        compose.onNodeWithText("자식 화면").assertExists()
        compose.onNodeWithTag(Tags.LOGOUT_BUTTON).performClick()

        assertEquals(1, logouts)
    }

    @Test
    fun todoListMarksDoneRowsAndSendsSelectedId() {
        val selected = mutableListOf<Long>()
        val todos = listOf(TodoItem(1, "우유 사기", isDone = true), TodoItem(2, "운동하기", isDone = false))
        compose.setContent { TodoListView(todos = todos, onSelect = { selected += it }) }

        compose.onNodeWithTag(Tags.todoRow(1)).assertTextEquals("✓ 우유 사기")
        compose.onNodeWithTag(Tags.todoRow(2)).performClick()

        assertEquals(listOf(2L), selected)
    }

    @Test
    fun todoDetailShowsToggleLabelAndSendsInputs() {
        val events = mutableListOf<String>()
        compose.setContent {
            TodoDetailView(title = "우유 사기", isDone = true, onBack = { events += "back" }, onToggleDone = { events += "toggle" })
        }

        compose.onNodeWithTag(Tags.DETAIL_TITLE).assertTextEquals("우유 사기")
        compose.onNodeWithTag(Tags.TOGGLE_DONE_BUTTON).assertTextEquals("완료 취소")
        compose.onNodeWithTag(Tags.TOGGLE_DONE_BUTTON).performClick()
        compose.onNodeWithTag(Tags.BACK_BUTTON).performClick()

        assertEquals(listOf("toggle", "back"), events)
    }
}
