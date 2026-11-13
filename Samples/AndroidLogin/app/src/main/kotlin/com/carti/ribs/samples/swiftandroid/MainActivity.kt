package com.carti.ribs.samples.swiftandroid

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.os.bundleOf
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.createSavedStateHandle
import androidx.lifecycle.viewmodel.CreationExtras
import org.json.JSONObject

/**
 * Swift RIB 트리를 소유하는 ViewModel. 화면 회전에도 트리를 유지하고, 화면을 완전히 떠날 때 내린다.
 * Swift가 보낸 화면 트리(JSON)를 Compose 상태로 들고 있다.
 */
class LoginViewModel(loginDelayMillis: Long, savedStateHandle: SavedStateHandle) : ViewModel() {
    var tree: JSONObject by mutableStateOf(JSONObject())
        private set

    init {
        val saved = savedStateHandle.get<Bundle>(KEY_RIB_STATE)?.getString(KEY_RIB_STATE)
        SwiftBridge.start(saved, loginDelayMillis) { tree = JSONObject(it) }
        savedStateHandle.setSavedStateProvider(KEY_RIB_STATE) { bundleOf(KEY_RIB_STATE to SwiftBridge.saveState()) }
    }

    fun send(screenId: Long, action: String, argument: String = "") {
        SwiftBridge.dispatch(screenId, action, argument)
    }

    override fun onCleared() {
        SwiftBridge.stop()
    }

    private companion object {
        const val KEY_RIB_STATE = "ribState"
    }
}

/** 시스템 뒤로 가기를 RIB 트리에 먼저 묻고, 처리하지 않으면 기본 동작(Activity 종료)을 따른다. KMP `RibBackPressedCallback`과 같다. */
private class RibBackPressedCallback(private val activity: ComponentActivity) : OnBackPressedCallback(true) {
    override fun handleOnBackPressed() {
        if (SwiftBridge.handleBackPress()) return
        isEnabled = false
        activity.onBackPressedDispatcher.onBackPressed()
        isEnabled = true
    }
}

class MainActivity : ComponentActivity() {
    private val viewModel: LoginViewModel by lazy {
        val delay = intent.getLongExtra(EXTRA_LOGIN_DELAY_MILLIS, DEFAULT_LOGIN_DELAY_MILLIS)
        ViewModelProvider(
            this,
            object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>, extras: CreationExtras): T =
                    LoginViewModel(delay, extras.createSavedStateHandle()) as T
            },
        )[LoginViewModel::class.java]
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        onBackPressedDispatcher.addCallback(this, RibBackPressedCallback(this))
        setContent {
            MaterialTheme {
                Surface { RibNode(viewModel.tree, viewModel::send) }
            }
        }
    }

    companion object {
        /** 테스트가 로딩 상태를 확실히 잡도록 응답 지연을 바꾸는 인텐트 값. */
        const val EXTRA_LOGIN_DELAY_MILLIS: String = "loginDelayMillis"

        /** 샘플 서버 응답 지연. 로딩 표시를 눈으로 확인할 수 있을 만큼만 둔다. */
        const val DEFAULT_LOGIN_DELAY_MILLIS: Long = 800
    }
}
