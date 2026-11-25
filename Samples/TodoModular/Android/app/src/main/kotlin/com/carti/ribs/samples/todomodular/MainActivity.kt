package com.carti.ribs.samples.todomodular

import androidx.compose.runtime.Composable
import com.carti.ribs.samples.todomodular.core.RibActivity
import com.carti.ribs.samples.todomodular.core.RibTreeStarter
import com.carti.ribs.samples.todomodular.core.SwiftBridge
import com.carti.ribs.samples.todomodular.feature.loggedin.ui.LOGGED_IN_KIND
import com.carti.ribs.samples.todomodular.feature.loggedin.ui.LoggedInScreen
import com.carti.ribs.samples.todomodular.feature.loggedout.ui.LOGGED_OUT_KIND
import com.carti.ribs.samples.todomodular.feature.loggedout.ui.LoggedOutScreen
import com.carti.ribs.samples.todomodular.feature.tododetail.ui.TODO_DETAIL_KIND
import com.carti.ribs.samples.todomodular.feature.tododetail.ui.TodoDetailScreen
import com.carti.ribs.samples.todomodular.feature.todolist.ui.TODO_LIST_KIND
import com.carti.ribs.samples.todomodular.feature.todolist.ui.TodoListScreen
import org.json.JSONObject

/** 전체 앱. 화면 종류를 피처 UI 모듈의 Composable로 잇는 곳은 여기뿐이다. */
class MainActivity : RibActivity() {
    override val startTree: RibTreeStarter = SwiftBridge::start

    @Composable
    override fun FeatureNode(node: JSONObject) {
        val id = node.getLong("id")
        when (node.getString("kind")) {
            LOGGED_OUT_KIND -> LoggedOutScreen(id)
            LOGGED_IN_KIND -> LoggedInScreen(id) { RibNode(node.optJSONObject("child")) }
            TODO_LIST_KIND -> TodoListScreen(id)
            TODO_DETAIL_KIND -> TodoDetailScreen(id)
            else -> error("Unknown screen kind: ${node.getString("kind")}")
        }
    }
}
