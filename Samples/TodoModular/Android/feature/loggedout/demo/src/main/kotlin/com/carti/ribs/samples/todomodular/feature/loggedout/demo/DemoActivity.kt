package com.carti.ribs.samples.todomodular.feature.loggedout.demo

import androidx.compose.runtime.Composable
import com.carti.ribs.samples.todomodular.core.RibActivity
import com.carti.ribs.samples.todomodular.core.RibTreeStarter
import com.carti.ribs.samples.todomodular.core.SwiftBridge
import com.carti.ribs.samples.todomodular.feature.loggedout.ui.LoggedOutScreen
import com.carti.ribs.samples.todomodular.feature.loggedout.ui.LOGGED_OUT_KIND
import org.json.JSONObject

/** LoggedOut 피처만 띄운다. 부모에게 갈 이벤트는 화면 아래에, 자식 피처는 자리표시 화면으로 보인다. */
class DemoActivity : RibActivity() {
    override val startTree: RibTreeStarter = { _, delay, onRender ->
        SwiftBridge.startDemo("loggedOut", delay, onRender)
        false
    }

    @Composable
    override fun FeatureNode(node: JSONObject) {
        when (node.getString("kind")) {
            LOGGED_OUT_KIND -> LoggedOutScreen(node.getLong("id"))
            else -> error("Unknown screen kind in LoggedOut demo: ${node.getString("kind")}")
        }
    }
}
