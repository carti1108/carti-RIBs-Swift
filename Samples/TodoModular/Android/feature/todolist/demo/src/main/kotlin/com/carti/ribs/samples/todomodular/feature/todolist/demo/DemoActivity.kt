package com.carti.ribs.samples.todomodular.feature.todolist.demo

import androidx.compose.runtime.Composable
import com.carti.ribs.samples.todomodular.core.RibActivity
import com.carti.ribs.samples.todomodular.core.RibTreeStarter
import com.carti.ribs.samples.todomodular.core.SwiftBridge
import com.carti.ribs.samples.todomodular.feature.todolist.adapter.TodoListScreen
import com.carti.ribs.samples.todomodular.feature.todolist.adapter.TODO_LIST_KIND
import org.json.JSONObject

/** TodoList 피처만 띄운다. 부모에게 갈 이벤트는 화면 아래에, 자식 피처는 자리표시 화면으로 보인다. */
class DemoActivity : RibActivity() {
    override val startTree: RibTreeStarter = { _, delay, onRender ->
        SwiftBridge.startDemo("todoList", delay, onRender)
        false
    }

    @Composable
    override fun FeatureNode(node: JSONObject) {
        when (node.getString("kind")) {
            TODO_LIST_KIND -> TodoListScreen(node.getLong("id"))
            else -> error("Unknown screen kind in TodoList demo: ${node.getString("kind")}")
        }
    }
}
