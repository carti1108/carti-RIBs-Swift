package com.carti.ribs.samples.todomodular

import android.content.Intent
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.carti.ribs.samples.todomodular.core.RibActivity
import com.carti.ribs.samples.todomodular.feature.loggedout.ui.LoggedOutTags
import com.carti.ribs.samples.todomodular.feature.todolist.ui.TodoListTags
import java.net.ServerSocket
import java.util.concurrent.atomic.AtomicInteger
import kotlin.concurrent.thread
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** 요청 줄만 읽고 정해 둔 응답을 돌려주는 테스트 서버. 기기 안에서 돈다. */
private class TodoTestServer : AutoCloseable {
    private val socket = ServerSocket(0)
    val requests = mutableListOf<String>()
    val remainingFailures = AtomicInteger(0)
    val baseUrl: String = "http://127.0.0.1:${socket.localPort}/api"

    init {
        thread(isDaemon = true) {
            while (!socket.isClosed) {
                val client = runCatching { socket.accept() }.getOrNull() ?: break
                client.use {
                    val reader = it.getInputStream().bufferedReader()
                    val requestLine = reader.readLine() ?: return@use
                    while (!reader.readLine().isNullOrEmpty()) Unit
                    synchronized(requests) { requests += requestLine }
                    val failed = remainingFailures.getAndUpdate { n -> maxOf(0, n - 1) } > 0
                    val body = if (failed) "" else TODOS_JSON
                    val status = if (failed) "503 Service Unavailable" else "200 OK"
                    val bytes = body.toByteArray(Charsets.UTF_8)
                    it.getOutputStream().apply {
                        write("HTTP/1.1 $status\r\nContent-Type: application/json\r\nContent-Length: ${bytes.size}\r\nConnection: close\r\n\r\n".toByteArray())
                        write(bytes)
                        flush()
                    }
                }
            }
        }
    }

    fun requestLines(): List<String> = synchronized(requests) { requests.toList() }

    override fun close() = socket.close()

    private companion object {
        const val TODOS_JSON = """[{"id": 7, "title": "서버에서 온 할 일", "done": true}]"""
    }
}

/** 할 일 목록이 실제 HTTP 요청으로 오는지 확인한다(ADR-0033). Kotlin이 보내고 Swift 공유 코드가 해석한다. */
@RunWith(AndroidJUnit4::class)
class TodoHttpTransportTest {
    @get:Rule
    val compose = createEmptyComposeRule()

    private val server = TodoTestServer()
    private lateinit var scenario: ActivityScenario<MainActivity>

    @Before
    fun launch() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val intent = Intent(context, MainActivity::class.java)
            .putExtra(RibActivity.EXTRA_LOGIN_DELAY_MILLIS, 1L)
            .putExtra(RibActivity.EXTRA_TODO_BASE_URL, server.baseUrl)
        scenario = ActivityScenario.launch(intent)
    }

    @After
    fun close() {
        scenario.close()
        server.close()
    }

    private fun login() {
        compose.onNodeWithTag(LoggedOutTags.NAME_FIELD).performTextInput("carti")
        compose.onNodeWithTag(LoggedOutTags.LOGIN_BUTTON).performClick()
    }

    private fun waitForTag(tag: String) {
        compose.waitUntil(TIMEOUT_MILLIS) { compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty() }
    }

    @Test
    fun listComesFromTheServer() {
        login()

        waitForTag(TodoListTags.todoRow(7))
        compose.onNodeWithTag(TodoListTags.todoRow(7)).assertTextEquals("✓ 서버에서 온 할 일")
        assertEquals(listOf("GET /api/todos HTTP/1.1"), server.requestLines())
    }

    @Test
    fun serverErrorShowsRetryAndRetryLoadsTheList() {
        server.remainingFailures.set(1)
        login()

        waitForTag(TodoListTags.ERROR)
        compose.onNodeWithTag(TodoListTags.ERROR).assertTextEquals("할 일을 불러오지 못했습니다")
        compose.onNodeWithTag(TodoListTags.RETRY).performClick()

        waitForTag(TodoListTags.todoRow(7))
        assertEquals(2, server.requestLines().size)
    }

    private companion object {
        const val TIMEOUT_MILLIS = 10_000L
    }
}
