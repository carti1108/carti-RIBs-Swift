package com.carti.ribs.samples.todomodular

import com.carti.ribs.samples.todomodular.core.RibActivity
import com.carti.ribs.samples.todomodular.feature.loggedout.ui.LoggedOutTags
import com.carti.ribs.samples.todomodular.feature.loggedin.ui.LoggedInTags
import com.carti.ribs.samples.todomodular.feature.todolist.ui.TodoListTags
import com.carti.ribs.samples.todomodular.feature.tododetail.ui.TodoDetailTags
import android.content.Intent
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** µFeature로 나눈 Swift RIB 트리(TodoAppRoot)가 JNI를 거쳐 Compose 화면을 실제로 전환하는지 확인한다. iOS `TodoFlowUITests`와 같은 흐름이다. */
@RunWith(AndroidJUnit4::class)
class LoginFlowTest {
    @get:Rule
    val compose = createEmptyComposeRule()

    private lateinit var scenario: ActivityScenario<MainActivity>

    @Before
    fun launch() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val intent = Intent(context, MainActivity::class.java)
            .putExtra(RibActivity.EXTRA_LOGIN_DELAY_MILLIS, LOGIN_DELAY_MILLIS)
        scenario = ActivityScenario.launch(intent)
    }

    @After
    fun close() {
        scenario.close()
    }

    @Test
    fun blankNameShowsError() {
        compose.onNodeWithTag(LoggedOutTags.LOGIN_BUTTON).performClick()

        compose.onNodeWithTag(LoggedOutTags.ERROR_LABEL).assertTextEquals("이름을 입력하세요")
    }

    @Test
    fun loginThenLogoutReturnsToEmptyLoggedOutScreen() {
        compose.onNodeWithTag(LoggedOutTags.NAME_FIELD).performTextInput("  carti ")
        compose.onNodeWithTag(LoggedOutTags.LOGIN_BUTTON).performClick()

        waitForTag(LoggedOutTags.LOADING_INDICATOR)
        compose.onNodeWithTag(LoggedOutTags.LOGIN_BUTTON).assertIsNotEnabled()

        waitForTag(LoggedInTags.WELCOME_LABEL)
        compose.onNodeWithTag(LoggedInTags.WELCOME_LABEL).assertTextEquals("carti님, 환영합니다")

        compose.onNodeWithTag(LoggedInTags.LOGOUT_BUTTON).performClick()

        waitForTag(LoggedOutTags.NAME_FIELD)
        compose.onNodeWithTag(LoggedOutTags.NAME_FIELD).assert(SemanticsMatcher.expectValue(SemanticsProperties.EditableText, AnnotatedString("")))
        compose.onNodeWithTag(LoggedOutTags.ERROR_LABEL).assertDoesNotExist()
    }

    @Test
    fun failedLoginShowsServerErrorAndAllowsRetry() {
        compose.onNodeWithTag(LoggedOutTags.NAME_FIELD).performTextInput("fail")
        compose.onNodeWithTag(LoggedOutTags.LOGIN_BUTTON).performClick()

        waitForTag(LoggedOutTags.ERROR_LABEL)
        compose.onNodeWithTag(LoggedOutTags.ERROR_LABEL).assertTextEquals("로그인에 실패했습니다")
        compose.onNodeWithTag(LoggedOutTags.LOADING_INDICATOR).assertDoesNotExist()
        compose.onNodeWithTag(LoggedOutTags.LOGIN_BUTTON).assertIsEnabled()
    }

    @Test
    fun todoDetailTogglesDoneAndSystemBackReturnsToList() {
        compose.onNodeWithTag(LoggedOutTags.NAME_FIELD).performTextInput("carti")
        compose.onNodeWithTag(LoggedOutTags.LOGIN_BUTTON).performClick()
        waitForTag(TodoListTags.todoRow(1))

        compose.onNodeWithTag(TodoListTags.todoRow(1)).performClick()
        compose.onNodeWithTag(TodoDetailTags.DETAIL_TITLE).assertTextEquals("우유 사기")
        compose.onNodeWithTag(TodoDetailTags.TOGGLE_DONE_BUTTON).performClick()

        // 시스템 뒤로 가기와 같은 경로(OnBackPressedDispatcher → RibBackPressedCallback → Swift handleBackPress)를 탄다.
        // Espresso.pressBack()은 헤드리스 에뮬레이터에서 창 포커스를 기다리다 실패할 수 있어 쓰지 않는다.
        scenario.onActivity { it.onBackPressedDispatcher.onBackPressed() }

        waitForTag(TodoListTags.todoRow(1))
        compose.onNodeWithTag(TodoDetailTags.DETAIL_TITLE).assertDoesNotExist()
        compose.onNodeWithTag(TodoListTags.todoRow(1)).assertTextEquals("✓ 우유 사기")
    }

    @Test
    fun sessionTimerTicksOnMainLooper() {
        // Swift Task(@MainActor)가 libdispatch 메인 큐 → 메인 Looper로 실제로 도는지 확인한다(ADR-0010).
        compose.onNodeWithTag(LoggedOutTags.NAME_FIELD).performTextInput("carti")
        compose.onNodeWithTag(LoggedOutTags.LOGIN_BUTTON).performClick()
        waitForTag(LoggedInTags.SESSION_LABEL)

        compose.waitUntil(TIMEOUT_MILLIS) {
            compose.onAllNodesWithTag(LoggedInTags.SESSION_LABEL).fetchSemanticsNodes().any { node ->
                node.config.getOrNull(SemanticsProperties.Text)?.joinToString() == "로그인 2초"
            }
        }
    }

    private fun waitForTag(tag: String) {
        compose.waitUntil(TIMEOUT_MILLIS) {
            compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty()
        }
    }

    private companion object {
        /** 느린 에뮬레이터에서도 잠깐 보이는 로딩 상태를 확인할 수 있게 응답을 늦춘다. */
        const val LOGIN_DELAY_MILLIS = 3_000L
        const val TIMEOUT_MILLIS = 8_000L
    }
}
