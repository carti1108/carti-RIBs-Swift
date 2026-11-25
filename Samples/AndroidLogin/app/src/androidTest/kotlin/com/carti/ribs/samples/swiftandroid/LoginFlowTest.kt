package com.carti.ribs.samples.swiftandroid

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
import com.carti.ribs.samples.swiftandroid.views.Tags
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** Swift LoginShared RIB 트리가 JNI를 거쳐 Compose 화면을 실제로 전환하는지 확인한다. iOS·KMP `LoginFlow` 테스트와 같은 흐름이다. */
@RunWith(AndroidJUnit4::class)
class LoginFlowTest {
    @get:Rule
    val compose = createEmptyComposeRule()

    private lateinit var scenario: ActivityScenario<MainActivity>

    @Before
    fun launch() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val intent = Intent(context, MainActivity::class.java)
            .putExtra(MainActivity.EXTRA_LOGIN_DELAY_MILLIS, LOGIN_DELAY_MILLIS)
        scenario = ActivityScenario.launch(intent)
    }

    @After
    fun close() {
        scenario.close()
    }

    @Test
    fun blankNameShowsError() {
        compose.onNodeWithTag(Tags.LOGIN_BUTTON).performClick()

        compose.onNodeWithTag(Tags.ERROR_LABEL).assertTextEquals("이름을 입력하세요")
    }

    @Test
    fun loginThenLogoutReturnsToEmptyLoggedOutScreen() {
        compose.onNodeWithTag(Tags.NAME_FIELD).performTextInput("  carti ")
        compose.onNodeWithTag(Tags.LOGIN_BUTTON).performClick()

        waitForTag(Tags.LOADING_INDICATOR)
        compose.onNodeWithTag(Tags.LOGIN_BUTTON).assertIsNotEnabled()

        waitForTag(Tags.WELCOME_LABEL)
        compose.onNodeWithTag(Tags.WELCOME_LABEL).assertTextEquals("carti님, 환영합니다")

        compose.onNodeWithTag(Tags.LOGOUT_BUTTON).performClick()

        waitForTag(Tags.NAME_FIELD)
        compose.onNodeWithTag(Tags.NAME_FIELD).assert(SemanticsMatcher.expectValue(SemanticsProperties.EditableText, AnnotatedString("")))
        compose.onNodeWithTag(Tags.ERROR_LABEL).assertDoesNotExist()
    }

    @Test
    fun failedLoginShowsServerErrorAndAllowsRetry() {
        compose.onNodeWithTag(Tags.NAME_FIELD).performTextInput("fail")
        compose.onNodeWithTag(Tags.LOGIN_BUTTON).performClick()

        waitForTag(Tags.ERROR_LABEL)
        compose.onNodeWithTag(Tags.ERROR_LABEL).assertTextEquals("로그인에 실패했습니다")
        compose.onNodeWithTag(Tags.LOADING_INDICATOR).assertDoesNotExist()
        compose.onNodeWithTag(Tags.LOGIN_BUTTON).assertIsEnabled()
    }

    @Test
    fun todoDetailTogglesDoneAndSystemBackReturnsToList() {
        compose.onNodeWithTag(Tags.NAME_FIELD).performTextInput("carti")
        compose.onNodeWithTag(Tags.LOGIN_BUTTON).performClick()
        waitForTag(Tags.todoRow(1))

        compose.onNodeWithTag(Tags.todoRow(1)).performClick()
        compose.onNodeWithTag(Tags.DETAIL_TITLE).assertTextEquals("우유 사기")
        compose.onNodeWithTag(Tags.TOGGLE_DONE_BUTTON).performClick()

        // 시스템 뒤로 가기와 같은 경로(OnBackPressedDispatcher → RibBackPressedCallback → Swift handleBackPress)를 탄다.
        // Espresso.pressBack()은 헤드리스 에뮬레이터에서 창 포커스를 기다리다 실패할 수 있어 쓰지 않는다.
        scenario.onActivity { it.onBackPressedDispatcher.onBackPressed() }

        waitForTag(Tags.todoRow(1))
        compose.onNodeWithTag(Tags.DETAIL_TITLE).assertDoesNotExist()
        compose.onNodeWithTag(Tags.todoRow(1)).assertTextEquals("✓ 우유 사기")
    }

    @Test
    fun sessionTimerTicksOnMainLooper() {
        // Swift Task(@MainActor)가 libdispatch 메인 큐 → 메인 Looper로 실제로 도는지 확인한다(ADR-0010).
        compose.onNodeWithTag(Tags.NAME_FIELD).performTextInput("carti")
        compose.onNodeWithTag(Tags.LOGIN_BUTTON).performClick()
        waitForTag(Tags.SESSION_LABEL)

        compose.waitUntil(TIMEOUT_MILLIS) {
            compose.onAllNodesWithTag(Tags.SESSION_LABEL).fetchSemanticsNodes().any { node ->
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
