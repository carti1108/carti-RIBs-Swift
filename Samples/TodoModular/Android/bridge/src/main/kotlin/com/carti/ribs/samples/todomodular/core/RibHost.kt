package com.carti.ribs.samples.todomodular.core

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.core.os.bundleOf
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.createSavedStateHandle
import androidx.lifecycle.viewmodel.CreationExtras
import com.carti.ribs.samples.todomodular.swiftbridge.PlaceholderScreenHandle
import com.carti.ribs.samples.todomodular.swiftbridge.PlaceholderViewBridge
import org.json.JSONObject
import org.swift.swiftkit.core.SwiftArena

/** 트리를 시작하는 방법. 저장값으로 되살렸으면 true. 전체 앱과 단독 실행 앱이 서로 다르게 넘긴다. */
typealias RibTreeStarter = (savedState: String?, loginDelayMillis: Long, onRender: (String) -> Unit) -> Boolean

/**
 * Swift RIB 트리를 소유하는 ViewModel. 화면 회전에도 트리를 유지하고, 화면을 완전히 떠날 때 내린다.
 * Swift가 보낸 화면 트리(JSON, 구조만 담는다)를 Compose 상태로 들고 있다.
 */
class RibTreeViewModel(
    start: RibTreeStarter,
    loginDelayMillis: Long,
    todoBaseUrl: String?,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {
    var tree: JSONObject by mutableStateOf(JSONObject())
        private set

    init {
        val saved = savedStateHandle.get<Bundle>(KEY_RIB_STATE)?.getString(KEY_RIB_STATE)
        todoBaseUrl?.let(SwiftBridge::installHttpTransport)
        start(saved, loginDelayMillis) { tree = JSONObject(it) }
        savedStateHandle.setSavedStateProvider(KEY_RIB_STATE) { bundleOf(KEY_RIB_STATE to SwiftBridge.saveState()) }
    }

    override fun onCleared() {
        SwiftBridge.stop()
    }

    private companion object {
        const val KEY_RIB_STATE = "ribState"
    }
}

/** 시스템 뒤로 가기를 RIB 트리에 먼저 묻고, 처리하지 않으면 기본 동작(Activity 종료)을 따른다. */
private class RibBackPressedCallback(private val activity: ComponentActivity) : OnBackPressedCallback(true) {
    override fun handleOnBackPressed() {
        if (SwiftBridge.handleBackPress()) return
        isEnabled = false
        activity.onBackPressedDispatcher.onBackPressed()
        isEnabled = true
    }
}

/**
 * Swift RIB 트리 하나를 그리는 Activity의 기반. 전체 앱과 피처별 단독 실행 앱이 상속한다.
 * 루트·자리표시 화면은 여기서 그리고, 피처 화면은 [FeatureNode]가 고른다.
 */
abstract class RibActivity : ComponentActivity() {
    protected abstract val startTree: RibTreeStarter

    /** 피처 화면 노드 하나를 그린다. 자식이 있는 화면은 [RibNode]로 자식을 다시 그린다. */
    @Composable
    protected abstract fun FeatureNode(node: JSONObject)

    private val viewModel: RibTreeViewModel by lazy {
        val delay = intent.getLongExtra(EXTRA_LOGIN_DELAY_MILLIS, DEFAULT_LOGIN_DELAY_MILLIS)
        val todoBaseUrl = intent.getStringExtra(EXTRA_TODO_BASE_URL)
        val start = startTree
        ViewModelProvider(
            this,
            object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>, extras: CreationExtras): T =
                    RibTreeViewModel(start, delay, todoBaseUrl, extras.createSavedStateHandle()) as T
            },
        )[RibTreeViewModel::class.java]
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        onBackPressedDispatcher.addCallback(this, RibBackPressedCallback(this))
        setContent {
            MaterialTheme {
                Surface { RibNode(viewModel.tree) }
            }
        }
    }

    /**
     * 화면 트리의 노드 하나를 그린다. 노드마다 `id`로 정체성을 줘서, 같은 종류의 새 RIB 화면이 오면
     * 이전 화면의 `remember` 상태(입력 중인 이름 등)를 버린다.
     */
    @Composable
    fun RibNode(node: JSONObject?) {
        if (node == null || !node.has("kind")) return
        key(node.getLong("id")) {
            when (node.getString("kind")) {
                HostKind.ROOT -> RootNode(node)
                HostKind.PLACEHOLDER -> PlaceholderScreen(node.getLong("id"))
                else -> FeatureNode(node)
            }
        }
    }

    @Composable
    private fun RootNode(node: JSONObject) {
        val event = node.optString("event").takeIf { node.has("event") }
        if (event == null) {
            RibNode(node.optJSONObject("child"))
            return
        }
        Column(Modifier.fillMaxSize()) {
            Column(Modifier.weight(1f)) { RibNode(node.optJSONObject("child")) }
            Text(event, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(16.dp).testTag(HostTags.DEMO_EVENT))
        }
    }

    companion object {
        /** 테스트가 로딩 상태를 확실히 잡도록 응답 지연을 바꾸는 인텐트 값. */
        const val EXTRA_LOGIN_DELAY_MILLIS: String = "loginDelayMillis"

        /** 할 일 API 서버 주소(`http://host:port/api`). 주면 `HttpURLConnection`으로 요청하고, 없으면 앱 안의 샘플 서버를 쓴다. */
        const val EXTRA_TODO_BASE_URL: String = "todoBaseUrl"

        /** 샘플 서버 응답 지연. 로딩 표시를 눈으로 확인할 수 있을 만큼만 둔다. */
        const val DEFAULT_LOGIN_DELAY_MILLIS: Long = 800
    }
}

/** Swift `HostScreenKind`(TodoAndroidSupport/HostScreens.swift)과 같은 문자열. */
object HostKind {
    const val ROOT = "root"
    const val PLACEHOLDER = "placeholder"
}

object HostTags {
    const val DEMO_EVENT = "demoEvent"
    const val PLACEHOLDER_ACTION = "placeholderAction"
}

/**
 * 단일 채널로 화면 상태를 구독하고 컴포지션을 떠날 때 뗀다.
 */
@Composable
fun <State> rememberChannelState(
    screenId: Long,
    kind: String,
    initial: State,
    decode: (JSONObject) -> State,
): State {
    var state by remember(screenId, kind) { mutableStateOf(initial) }
    DisposableEffect(screenId, kind) {
        SwiftBridge.attachScreen(screenId, kind) { json ->
            state = decode(JSONObject(json))
        }
        onDispose {
            SwiftBridge.detachScreen(screenId, kind)
        }
    }
    return state
}

/**
 * 화면 핸들을 만들어 뷰를 붙이고, 화면이 컴포지션을 떠날 때 떼고 핸들의 Swift 메모리(arena)를 푼다.
 * 핸들 타입마다 `init`·`attach`·`detach`가 따로 생성되므로 함수로 받는다. 피처 어댑터 모듈이 쓴다.
 */
@Composable
fun <Handle> rememberAttachedHandle(
    create: (SwiftArena) -> Handle,
    attach: (Handle) -> Unit,
    detach: (Handle) -> Unit,
): Handle {
    val arena = remember { SwiftArena.ofConfined() }
    val handle = remember { create(arena) }
    DisposableEffect(handle) {
        attach(handle)
        onDispose {
            detach(handle)
            arena.close()
        }
    }
    return handle
}

/** Swift `PlaceholderViewBridge`의 Compose 쪽 구현. */
private class PlaceholderView : PlaceholderViewBridge {
    var title: String by mutableStateOf("")
        private set
    var actionTitle: String by mutableStateOf("")
        private set

    override fun render(title: String, actionTitle: String) {
        this.title = title
        this.actionTitle = actionTitle
    }
}

/** 단독 실행 앱에서 자식 피처 대신 붙는 화면. */
@Composable
private fun PlaceholderScreen(screenId: Long) {
    val view = remember { PlaceholderView() }
    val handle = rememberAttachedHandle(
        create = { PlaceholderScreenHandle.init(screenId, it) },
        attach = { it.attach(view) },
        detach = { it.detach() },
    )
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(view.title, color = MaterialTheme.colorScheme.onSurfaceVariant)
        TextButton(onClick = { handle.actionTapped() }, modifier = Modifier.testTag(HostTags.PLACEHOLDER_ACTION)) {
            Text(view.actionTitle)
        }
    }
}
