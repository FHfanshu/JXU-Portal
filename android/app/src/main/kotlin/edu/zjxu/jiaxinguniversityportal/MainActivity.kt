package edu.zjxu.jiaxinguniversityportal

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "edu.zjxu.jiaxinguniversityportal/wechat",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openUrlInWeChat" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrBlank()) {
                        result.error("invalid_args", "url is required", null)
                        return@setMethodCallHandler
                    }

                    result.success(openUrlInWeChat(url))
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun openUrlInWeChat(url: String): Boolean {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
            addCategory(Intent.CATEGORY_BROWSABLE)
            setPackage("com.tencent.mm")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        return try {
            startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }
}
