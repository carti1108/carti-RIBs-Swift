package com.carti.ribs.samples.todomodular.feature.loggedin.ui

import androidx.compose.material3.Text
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** 이 모듈의 테스트 APK에는 Swift 라이브러리가 없다. 뷰가 값과 콜백만으로 그려지는지 확인한다(ADR-0027). */
@RunWith(AndroidJUnit4::class)
class LoggedInViewTest {
    @get:Rule
    val compose = createComposeRule()

    @Test
    fun drawsHeaderAndChildSlotAndSendsLogout() {
        var logouts = 0
        compose.setContent {
            LoggedInView(userName = "carti", sessionSeconds = 3, onLogout = { logouts += 1 }) { Text("자식 화면") }
        }

        compose.onNodeWithTag(LoggedInTags.WELCOME_LABEL).assertTextEquals("carti님, 환영합니다")
        compose.onNodeWithTag(LoggedInTags.SESSION_LABEL).assertTextEquals("로그인 3초")
        compose.onNodeWithText("자식 화면").assertExists()
        compose.onNodeWithTag(LoggedInTags.LOGOUT_BUTTON).performClick()

        assertEquals(1, logouts)
    }
}
