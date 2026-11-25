package com.carti.ribs.samples.todomodular

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.carti.ribs.samples.todomodular.core.HttpUrlConnectionTransport
import com.carti.ribs.samples.todomodular.core.SwiftBridge
import com.carti.ribs.samples.todomodular.swiftbridge.HTTPTransportHandle
import java.net.ServerSocket
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.swift.swiftkit.core.SwiftArena

/** 서버가 받은 요청. 헤더 이름은 소문자로 둔다. */
private data class ReceivedRequest(val method: String, val path: String, val headers: Map<String, String>, val body: String)

/** 요청 줄·헤더·본문(`Content-Length`만큼)을 읽어 두고 `200 {}`로 답하는 테스트 서버. 기기 안에서 돈다. */
private class RecordingServer : AutoCloseable {
    private val socket = ServerSocket(0)
    val received = LinkedBlockingQueue<ReceivedRequest>()
    val baseUrl: String = "http://127.0.0.1:${socket.localPort}/api"

    init {
        thread(isDaemon = true) {
            while (!socket.isClosed) {
                val client = runCatching { socket.accept() }.getOrNull() ?: break
                client.use { received += read(it.getInputStream()).also { _ -> reply(it.getOutputStream()) } }
            }
        }
    }

    private fun read(input: java.io.InputStream): ReceivedRequest {
        val (method, path) = readLine(input).split(" ")
        val headers = generateSequence { readLine(input).takeIf { it.isNotEmpty() } }
            .map { it.split(": ", limit = 2) }
            .associate { (name, value) -> name.lowercase() to value }
        val length = headers["content-length"]?.toInt() ?: 0
        val body = ByteArray(length).also { buffer ->
            var offset = 0
            while (offset < length) offset += input.read(buffer, offset, length - offset)
        }
        return ReceivedRequest(method, path, headers, body.toString(Charsets.UTF_8))
    }

    /** 본문을 바이트 단위로 읽어야 해서 `BufferedReader` 대신 줄을 직접 읽는다. */
    private fun readLine(input: java.io.InputStream): String {
        val bytes = mutableListOf<Byte>()
        while (true) {
            val next = input.read()
            if (next == -1 || next == '\n'.code) break
            if (next != '\r'.code) bytes += next.toByte()
        }
        return bytes.toByteArray().toString(Charsets.UTF_8)
    }

    private fun reply(output: java.io.OutputStream) {
        output.write("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 2\r\nConnection: close\r\n\r\n{}".toByteArray())
        output.flush()
    }

    override fun close() = socket.close()
}

/**
 * `HttpUrlConnectionTransport`가 Swift가 넘긴 메서드·헤더 줄·본문을 그대로 보내는지 확인한다(ADR-0034).
 * 결과는 설치되지 않은 핸들로 가서 버려진다. 결과를 Swift가 받는 경로는 `TodoHttpTransportTest`와 Swift 호스트 테스트가 본다.
 */
@RunWith(AndroidJUnit4::class)
class HttpUrlConnectionTransportTest {
    private val server = RecordingServer()
    private lateinit var transport: HttpUrlConnectionTransport

    init {
        // `SwiftBridge`는 메인 스레드에서 처음 불러야 한다(Swift 라이브러리를 불러오고 메인 Looper에 붙인다).
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            SwiftBridge.hashCode()
            transport = HttpUrlConnectionTransport(server.baseUrl, HTTPTransportHandle.init(SwiftArena.ofAuto()))
        }
    }

    @After
    fun close() {
        transport.shutdown()
        server.close()
    }

    private fun send(method: String, path: String, headers: String, body: String): ReceivedRequest {
        // `start`는 메인 스레드에서 부른다(Swift가 그렇게 부른다).
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            transport.start(1L, method, path, headers, body)
        }
        val received = server.received.poll(TIMEOUT_SECONDS, TimeUnit.SECONDS)
        assertNotNull("server received no request", received)
        return received!!
    }

    @Test
    fun postSendsHeaderLinesAndUtf8Body() {
        val received = send(
            "POST",
            "/todos",
            "Authorization: Bearer abc\nContent-Type: application/json\n",
            """{"title":"운동"}""",
        )

        assertEquals("POST", received.method)
        assertEquals("/api/todos", received.path)
        assertEquals("Bearer abc", received.headers["authorization"])
        assertEquals("application/json", received.headers["content-type"])
        assertEquals("""{"title":"운동"}""", received.body)
    }

    @Test
    fun patchIsSentAsPatch() {
        val received = send("PATCH", "/todos/7", "Content-Type: application/json\n", """{"done":true}""")

        assertEquals("PATCH", received.method)
        assertEquals("/api/todos/7", received.path)
        assertEquals("""{"done":true}""", received.body)
    }

    @Test
    fun deleteWithoutBodySendsNoBody() {
        val received = send("DELETE", "/todos/7", "Authorization: Bearer abc\n", "")

        assertEquals("DELETE", received.method)
        assertEquals("Bearer abc", received.headers["authorization"])
        assertNull(received.headers["content-length"]?.takeIf { it != "0" })
        assertEquals("", received.body)
    }

    @Test
    fun headerValueContainingColonSpaceIsKeptWhole() {
        val received = send("GET", "/todos", "X-Note: a: b\n", "")

        assertEquals("a: b", received.headers["x-note"])
    }

    private companion object {
        const val TIMEOUT_SECONDS = 10L
    }
}
