package com.carti.ribs.samples.swiftandroid

import android.content.Intent
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.lifecycle.Lifecycle
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** 구성 변경과 프로세스 종료 뒤 복원이 같은 화면(할 일 상세)을 되살리는지 기기에서 확인한다. */
@RunWith(AndroidJUnit4::class)
class LifecycleRestoreTest {
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
    fun mainQueueSelfCheckPasses() {
        compose.waitUntil(TIMEOUT_MILLIS) {
            var draining = false
            scenario.onActivity { draining = SwiftBridge.isMainQueueDraining() }
            draining
        }
    }

    @Test
    fun configurationChangeKeepsTodoDetailAndTree() {
        openDoneTodoDetail()

        // 회전과 같은 구성 변경: Activity만 새로 만들고 ViewModel(Swift 트리)은 그대로다.
        scenario.recreate()

        waitForTag(Tags.DETAIL_TITLE)
        compose.onNodeWithTag(Tags.DETAIL_TITLE).assertTextEquals("우유 사기")
        compose.onNodeWithTag(Tags.TOGGLE_DONE_BUTTON).assertTextEquals("완료 취소")
    }

    @Test
    fun processDeathRestoresTodoDetailFromSavedState() {
        openDoneTodoDetail()

        // 1) 백그라운드로 보내 onSaveInstanceState가 Swift 상태를 Bundle에 쓰게 한다(API 28+는 onStop에서 저장).
        scenario.moveToState(Lifecycle.State.CREATED)
        // 2) 프로세스 종료처럼 메모리 상태를 버린다: ViewModel을 지우면 onCleared → SwiftBridge.stop()으로 Swift 트리가 사라진다.
        scenario.onActivity { it.viewModelStore.clear() }
        // 3) 시스템이 저장된 Bundle로 Activity를 다시 만드는 경로. 새 ViewModel이 SavedStateHandle의 값으로 트리를 되살린다.
        scenario.recreate()
        scenario.moveToState(Lifecycle.State.RESUMED)

        waitForTag(Tags.DETAIL_TITLE)
        compose.onNodeWithTag(Tags.DETAIL_TITLE).assertTextEquals("우유 사기")
        compose.onNodeWithTag(Tags.TOGGLE_DONE_BUTTON).assertTextEquals("완료 취소")

        // 되살린 트리도 살아 있다: 뒤로 가면 완료 표시가 남은 목록이 나온다.
        scenario.onActivity { it.onBackPressedDispatcher.onBackPressed() }
        waitForTag(Tags.todoRow(1))
        compose.onNodeWithTag(Tags.todoRow(1)).assertTextEquals("✓ 우유 사기")
        var draining = false
        scenario.onActivity { draining = SwiftBridge.isMainQueueDraining() }
        assertTrue(draining)
    }

    private fun openDoneTodoDetail() {
        compose.onNodeWithTag(Tags.NAME_FIELD).performTextInput("carti")
        compose.onNodeWithTag(Tags.LOGIN_BUTTON).performClick()
        waitForTag(Tags.todoRow(1))
        compose.onNodeWithTag(Tags.todoRow(1)).performClick()
        waitForTag(Tags.DETAIL_TITLE)
        compose.onNodeWithTag(Tags.TOGGLE_DONE_BUTTON).performClick()
        compose.onNodeWithTag(Tags.TOGGLE_DONE_BUTTON).assertTextEquals("완료 취소")
    }

    private fun waitForTag(tag: String) {
        compose.waitUntil(TIMEOUT_MILLIS) {
            compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty()
        }
    }

    private companion object {
        const val LOGIN_DELAY_MILLIS = 300L
        const val TIMEOUT_MILLIS = 8_000L
    }
}
