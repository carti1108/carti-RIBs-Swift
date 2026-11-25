package com.carti.ribs.samples.todomodular.feature.loggedin.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.carti.ribs.samples.todomodular.core.rememberAttachedHandle
import com.carti.ribs.samples.todomodular.swiftbridge.LoggedInScreenHandle
import com.carti.ribs.samples.todomodular.swiftbridge.LoggedInViewBridge

/** Swift `LoggedInAndroidViewFactory.kind`와 같은 문자열. */
const val LOGGED_IN_KIND = "loggedIn"

object LoggedInTags {
    const val WELCOME_LABEL = "welcomeLabel"
    const val SESSION_LABEL = "sessionLabel"
    const val LOGOUT_BUTTON = "logoutButton"
}

/** Swift `LoggedInViewBridge`의 Compose 쪽 구현. */
private class LoggedInView : LoggedInViewBridge {
    var userName: String by mutableStateOf("")
        private set
    var sessionSeconds: Long by mutableLongStateOf(0)
        private set

    override fun render(userName: String, sessionSeconds: Long) {
        this.userName = userName
        this.sessionSeconds = sessionSeconds
    }
}

/** 자식 화면(목록·상세)은 화면 트리의 `child`에서 오므로 슬롯으로 받는다. 자식 피처 UI 모듈을 모른다. */
@Composable
fun LoggedInScreen(screenId: Long, child: @Composable () -> Unit) {
    val view = remember { LoggedInView() }
    val handle = rememberAttachedHandle(
        create = { LoggedInScreenHandle.init(screenId, it) },
        attach = { it.attach(view) },
        detach = { it.detach() },
    )
    Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(
            "${view.userName}님, 환영합니다",
            style = MaterialTheme.typography.headlineSmall,
            modifier = Modifier.testTag(LoggedInTags.WELCOME_LABEL),
        )
        Text("로그인 ${view.sessionSeconds}초", modifier = Modifier.testTag(LoggedInTags.SESSION_LABEL))
        OutlinedButton(onClick = { handle.logoutTapped() }, modifier = Modifier.testTag(LoggedInTags.LOGOUT_BUTTON)) {
            Text("로그아웃")
        }
        child()
    }
}
