package com.carti.ribs.samples.todomodular.feature.loggedout.ui

import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** 이 모듈의 테스트 APK에는 Swift 라이브러리가 없다. 뷰가 값과 콜백만으로 그려지는지 확인한다(ADR-0027). */
@RunWith(AndroidJUnit4::class)
class LoggedOutViewTest {
    @get:Rule
    val compose = createComposeRule()

    @Test
    fun showsErrorAndSendsTypedName() {
        val logins = mutableListOf<String>()
        compose.setContent { LoggedOutView(errorMessage = "오류", isLoading = false, onLogin = { logins += it }) }

        compose.onNodeWithTag(LoggedOutTags.ERROR_LABEL).assertTextEquals("오류")
        compose.onNodeWithTag(LoggedOutTags.NAME_FIELD).performTextInput("carti")
        compose.onNodeWithTag(LoggedOutTags.LOGIN_BUTTON).performClick()

        assertEquals(listOf("carti"), logins)
    }

    @Test
    fun disablesInputWhileLoading() {
        compose.setContent { LoggedOutView(errorMessage = null, isLoading = true, onLogin = {}) }

        compose.onNodeWithTag(LoggedOutTags.LOADING_INDICATOR).assertExists()
        compose.onNodeWithTag(LoggedOutTags.LOGIN_BUTTON).assertIsNotEnabled()
        compose.onNodeWithTag(LoggedOutTags.ERROR_LABEL).assertDoesNotExist()
    }
}
