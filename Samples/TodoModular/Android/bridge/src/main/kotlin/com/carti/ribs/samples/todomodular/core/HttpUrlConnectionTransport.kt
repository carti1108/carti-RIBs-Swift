package com.carti.ribs.samples.todomodular.core

import android.os.Handler
import android.os.Looper
import com.carti.ribs.samples.todomodular.swiftbridge.HTTPTransportBridge
import com.carti.ribs.samples.todomodular.swiftbridge.HTTPTransportHandle
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.Future

/**
 * Swift `HTTPTransportBridge`의 구현(ADR-0033). 요청을 `HttpURLConnection`으로 보내 플랫폼의 인증서·프록시 설정을 그대로 쓴다.
 * Swift는 메인 스레드에서 `start`를 부른다. 요청은 백그라운드에서 보내고, 결과는 메인 스레드에서 핸들로 돌려준다.
 * 이 플랫폼이 데이터 계층에 대해 구현하는 것은 이것 하나다. 요청 생성과 응답 해석은 Swift 공유 코드가 한다.
 */
class HttpUrlConnectionTransport(
    private val baseUrl: String,
    private val handle: HTTPTransportHandle,
    private val executor: ExecutorService = Executors.newCachedThreadPool(),
) : HTTPTransportBridge {
    private val main = Handler(Looper.getMainLooper())

    /** 진행 중인 요청. 메인 스레드에서만 읽고 쓴다. */
    private val running = mutableMapOf<Long, Future<*>>()

    override fun start(requestID: Long, method: String, path: String) {
        running[requestID] = executor.submit {
            val result = runCatching { send(method, path) }
            main.post {
                // 취소된 요청은 이미 빠져 있다. Swift도 끝난 요청의 결과는 무시한다.
                if (running.remove(requestID) == null) return@post
                result.fold(
                    onSuccess = { (status, body) -> handle.complete(requestID, status, body) },
                    onFailure = { handle.fail(requestID) },
                )
            }
        }
    }

    override fun cancel(requestID: Long) {
        running.remove(requestID)?.cancel(true)
    }

    fun shutdown() {
        running.clear()
        executor.shutdownNow()
    }

    /** 상태 코드가 오류여도 응답으로 돌려준다. 연결하지 못하면 던진다. */
    private fun send(method: String, path: String): Pair<Int, String> {
        val connection = URL(baseUrl + path).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = method
            connection.connectTimeout = TIMEOUT_MILLIS
            connection.readTimeout = TIMEOUT_MILLIS
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val body = stream?.use { it.readBytes().toString(Charsets.UTF_8) } ?: ""
            return status to body
        } finally {
            connection.disconnect()
        }
    }

    private companion object {
        const val TIMEOUT_MILLIS = 10_000
    }
}
