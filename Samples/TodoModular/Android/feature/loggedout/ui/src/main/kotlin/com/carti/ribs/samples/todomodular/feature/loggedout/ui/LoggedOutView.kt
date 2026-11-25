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
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp

// 순수 뷰(ADR-0027). 값과 콜백만 받아 그린다. 이 모듈은 `:bridge`에 의존하지 않아 Swift 런타임 없이 미리보기와 테스트가 된다.

object LoggedOutTags {
    const val NAME_FIELD = "nameField"
    const val LOGIN_BUTTON = "loginButton"
    const val ERROR_LABEL = "errorLabel"
    const val LOADING_INDICATOR = "loadingIndicator"
}

/** 입력 중인 이름은 뷰가 들고 있다가 로그인 때 넘긴다. */
@Composable
fun LoggedOutView(errorMessage: String?, isLoading: Boolean, onLogin: (String) -> Unit) {
    var name by rememberSaveable { mutableStateOf("") }
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
        errorMessage?.let {
            Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.testTag(LoggedOutTags.ERROR_LABEL))
        }
        if (isLoading) CircularProgressIndicator(modifier = Modifier.testTag(LoggedOutTags.LOADING_INDICATOR))
        Button(
            onClick = { onLogin(name) },
            enabled = !isLoading,
            modifier = Modifier.testTag(LoggedOutTags.LOGIN_BUTTON),
        ) {
            Text("로그인")
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun LoggedOutViewPreview() {
    MaterialTheme { LoggedOutView(errorMessage = "이름을 입력하세요", isLoading = false, onLogin = {}) }
}
