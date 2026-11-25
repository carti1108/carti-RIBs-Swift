package com.carti.ribs.samples.todomodular.feature.loggedin.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp

// 순수 뷰(ADR-0027). 값과 콜백만 받아 그린다. 이 모듈은 `:bridge`에 의존하지 않아 Swift 런타임 없이 미리보기와 테스트가 된다.

object LoggedInTags {
    const val WELCOME_LABEL = "welcomeLabel"
    const val SESSION_LABEL = "sessionLabel"
    const val LOGOUT_BUTTON = "logoutButton"
}

/** 자식 화면(목록·상세)은 `child` 슬롯으로 받는다. 무엇이 들어오는지 모르고, 자식 피처 UI 모듈도 모른다. */
@Composable
fun LoggedInView(userName: String, sessionSeconds: Long, onLogout: () -> Unit, child: @Composable () -> Unit) {
    Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(
            "${userName}님, 환영합니다",
            style = MaterialTheme.typography.headlineSmall,
            modifier = Modifier.testTag(LoggedInTags.WELCOME_LABEL),
        )
        Text("로그인 ${sessionSeconds}초", modifier = Modifier.testTag(LoggedInTags.SESSION_LABEL))
        OutlinedButton(onClick = onLogout, modifier = Modifier.testTag(LoggedInTags.LOGOUT_BUTTON)) {
            Text("로그아웃")
        }
        child()
    }
}

@Preview(showBackground = true)
@Composable
private fun LoggedInViewPreview() {
    MaterialTheme { LoggedInView(userName = "carti", sessionSeconds = 12, onLogout = {}) { Text("자식 화면 자리") } }
}
