package com.carti.ribs.samples.todomodular.feature.loggedin.demo

import androidx.compose.runtime.Composable
import com.carti.ribs.samples.todomodular.core.RibActivity
import com.carti.ribs.samples.todomodular.core.RibTreeStarter
import com.carti.ribs.samples.todomodular.core.SwiftBridge
import com.carti.ribs.samples.todomodular.feature.loggedin.adapter.LoggedInScreen
import com.carti.ribs.samples.todomodular.feature.loggedin.adapter.LOGGED_IN_KIND
import org.json.JSONObject

/** LoggedIn 피처만 띄운다. 부모에게 갈 이벤트는 화면 아래에, 자식 피처는 자리표시 화면으로 보인다. */
class DemoActivity : RibActivity() {
    override val startTree: RibTreeStarter = { _, delay, onRender ->
        SwiftBridge.startDemo("loggedIn", delay, onRender)
        false
    }

    @Composable
    override fun FeatureNode(node: JSONObject) {
        when (node.getString("kind")) {
            LOGGED_IN_KIND -> LoggedInScreen(node.getLong("id")) { RibNode(node.optJSONObject("child")) }
            else -> error("Unknown screen kind in LoggedIn demo: ${node.getString("kind")}")
        }
    }
}
