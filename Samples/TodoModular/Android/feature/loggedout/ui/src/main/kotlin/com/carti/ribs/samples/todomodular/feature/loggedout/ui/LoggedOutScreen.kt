package com.carti.ribs.samples.todomodular.feature.loggedout.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.carti.ribs.samples.todomodular.core.rememberAttachedHandle
import com.carti.ribs.samples.todomodular.swiftbridge.LoggedOutScreenHandle
import com.carti.ribs.samples.todomodular.swiftbridge.LoggedOutViewBridge
import java.util.Optional

/** Swift `LoggedOutAndroidViewFactory.kind`와 같은 문자열. */
const val LOGGED_OUT_KIND = "loggedOut"

object LoggedOutTags {
    const val NAME_FIELD = "nameField"
    const val LOGIN_BUTTON = "loginButton"
    const val ERROR_LABEL = "errorLabel"
    const val LOADING_INDICATOR = "loadingIndicator"
}

/** Swift `LoggedOutViewBridge`의 Compose 쪽 구현. Swift가 넘긴 값을 Compose 상태로 든다. */
private class LoggedOutView : LoggedOutViewBridge {
    var errorMessage: String? by mutableStateOf(null)
        private set
    var isLoading: Boolean by mutableStateOf(false)
        private set

    override fun render(errorMessage: Optional<String>, isLoading: Boolean) {
        this.errorMessage = errorMessage.orElse(null)
        this.isLoading = isLoading
    }
}

@Composable
fun LoggedOutScreen(screenId: Long) {
    var name by rememberSaveable { mutableStateOf("") }
    val view = remember { LoggedOutView() }
    val handle = rememberAttachedHandle(
        create = { LoggedOutScreenHandle.init(screenId, it) },
        attach = { it.attach(view) },
        detach = { it.detach() },
    )
    val isLoading = view.isLoading
    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("로그인", style = MaterialTheme.typography.headlineLarge)
        OutlinedTextField(
            value = name,
            onValueChange = { name = it },
            label = { Text("이름") },
            enabled = !isLoading,
            singleLine = true,
            modifier = Modifier.testTag(LoggedOutTags.NAME_FIELD),
        )
        view.errorMessage?.let {
            Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.testTag(LoggedOutTags.ERROR_LABEL))
        }
        if (isLoading) CircularProgressIndicator(modifier = Modifier.testTag(LoggedOutTags.LOADING_INDICATOR))
        Button(
            onClick = { handle.loginTapped(name) },
            enabled = !isLoading,
            modifier = Modifier.testTag(LoggedOutTags.LOGIN_BUTTON),
        ) {
            Text("로그인")
        }
    }
}
