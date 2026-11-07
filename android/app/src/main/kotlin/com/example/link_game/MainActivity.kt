package com.example.link_game

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "linkgame/app_info")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // 增量更新需要读取已安装 APK 的字节做差分基准
                    "getInstalledApkPath" -> {
                        val path = applicationContext.applicationInfo.sourceDir
                        if (path != null) {
                            result.success(path)
                        } else {
                            result.error("NO_PATH", "sourceDir unavailable", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
