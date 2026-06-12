package com.follow.DreamCloud

import com.follow.DreamCloud.plugins.AppPlugin
import com.follow.DreamCloud.plugins.ServicePlugin
import com.follow.DreamCloud.plugins.TilePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(AppPlugin())
        flutterEngine.plugins.add(ServicePlugin)
        flutterEngine.plugins.add(TilePlugin())
        GlobalState.flutterEngine = flutterEngine
    }

    override fun onDestroy() {
        GlobalState.flutterEngine = null
        GlobalState.runState.value = RunState.STOP
        super.onDestroy()
    }
}