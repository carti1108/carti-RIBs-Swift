package com.carti.ribs.samples.todomodular.feature.tododetail.demo

import androidx.compose.runtime.Composable
import com.carti.ribs.samples.todomodular.core.RibActivity
import com.carti.ribs.samples.todomodular.core.RibTreeStarter
import com.carti.ribs.samples.todomodular.core.SwiftBridge
import com.carti.ribs.samples.todomodular.feature.tododetail.ui.TodoDetailScreen
import com.carti.ribs.samples.todomodular.feature.tododetail.ui.TODO_DETAIL_KIND
import org.json.JSONObject

/** TodoDetail 피처만 띄운다. 부모에게 갈 이벤트는 화면 아래에, 자식 피처는 자리표시 화면으로 보인다. */
class DemoActivity : RibActivity() {
    override val startTree: RibTreeStarter = { _, delay, onRender ->
        SwiftBridge.startDemo("todoDetail", delay, onRender)
        false
    }

    @Composable
    override fun FeatureNode(node: JSONObject) {
        when (node.getString("kind")) {
            TODO_DETAIL_KIND -> TodoDetailScreen(node.getLong("id"))
            else -> error("Unknown screen kind in TodoDetail demo: ${node.getString("kind")}")
        }
    }
}
