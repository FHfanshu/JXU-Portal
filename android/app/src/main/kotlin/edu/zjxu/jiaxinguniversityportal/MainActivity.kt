package edu.zjxu.jiaxinguniversityportal

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val WECHAT_CHANNEL = "edu.zjxu.jiaxinguniversityportal/wechat"
        private const val SHORTCUT_CHANNEL = "edu.zjxu.jiaxinguniversityportal/shortcut"
        private const val EXTRA_SHORTCUT_ACTION = "shortcut_action"
        private const val SHORTCUT_SCHEME = "jiaxinguniversityportal"
        private const val SHORTCUT_HOST = "shortcut"
        private const val CAMPUS_CARD_PAYMENT_ACTION = "campus-card-payment"
        private const val CAMPUS_CARD_PAYMENT_SHORTCUT_ID = "campus_card_payment_pinned"
    }

    private var pendingShortcutAction: String? = null
    private var shortcutChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingShortcutAction = extractShortcutAction(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WECHAT_CHANNEL,
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

        shortcutChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SHORTCUT_CHANNEL,
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumeInitialShortcutAction" -> {
                        val action = pendingShortcutAction
                        pendingShortcutAction = null
                        result.success(action)
                    }

                    "requestCampusCardPaymentShortcut" -> {
                        result.success(requestCampusCardPaymentShortcut())
                    }

                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val action = extractShortcutAction(intent) ?: return
        val channel = shortcutChannel
        if (channel == null) {
            pendingShortcutAction = action
            return
        }

        channel.invokeMethod("onShortcutAction", action)
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

    private fun requestCampusCardPaymentShortcut(): Boolean {
        val shortcutIntent = createCampusCardPaymentIntent()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
            val shortcutManager = getSystemService(ShortcutManager::class.java) ?: return false
            val shortcut = buildCampusCardPaymentShortcutInfo(shortcutIntent)

            // Some launchers only fully recognize pinned shortcuts after the same
            // shortcutId has been published as a dynamic shortcut first.
            shortcutManager.removeDynamicShortcuts(listOf(CAMPUS_CARD_PAYMENT_SHORTCUT_ID))
            shortcutManager.addDynamicShortcuts(listOf(shortcut))

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                if (!shortcutManager.isRequestPinShortcutSupported) return false
                return shortcutManager.requestPinShortcut(shortcut, null)
            }

            return true
        }

        @Suppress("DEPRECATION")
        sendBroadcast(
            Intent("com.android.launcher.action.INSTALL_SHORTCUT").apply {
                putExtra(Intent.EXTRA_SHORTCUT_INTENT, shortcutIntent)
                putExtra(
                    Intent.EXTRA_SHORTCUT_NAME,
                    getString(R.string.shortcut_campus_card_payment_short_label),
                )
                putExtra(
                    Intent.EXTRA_SHORTCUT_ICON_RESOURCE,
                    Intent.ShortcutIconResource.fromContext(this@MainActivity, R.mipmap.ic_launcher),
                )
                putExtra("duplicate", false)
            },
        )
        return true
    }

    private fun buildCampusCardPaymentShortcutInfo(shortcutIntent: Intent): ShortcutInfo {
        return ShortcutInfo.Builder(this, CAMPUS_CARD_PAYMENT_SHORTCUT_ID)
            .setShortLabel(getString(R.string.shortcut_campus_card_payment_short_label))
            .setLongLabel(getString(R.string.shortcut_campus_card_payment_long_label))
            .setIcon(Icon.createWithResource(this, R.mipmap.ic_launcher))
            .setIntent(shortcutIntent)
            .build()
    }

    private fun createCampusCardPaymentIntent(): Intent {
        return Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("$SHORTCUT_SCHEME://$SHORTCUT_HOST/$CAMPUS_CARD_PAYMENT_ACTION")
            putExtra(EXTRA_SHORTCUT_ACTION, CAMPUS_CARD_PAYMENT_ACTION)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
    }

    private fun extractShortcutAction(intent: Intent?): String? {
        if (intent == null) return null

        val extraAction = intent.getStringExtra(EXTRA_SHORTCUT_ACTION)?.trim()
        if (!extraAction.isNullOrEmpty()) {
            return extraAction
        }

        val data = intent.data ?: return null
        if (data.scheme != SHORTCUT_SCHEME || data.host != SHORTCUT_HOST) {
            return null
        }

        return data.lastPathSegment?.trim()?.takeIf { it.isNotEmpty() }
    }
}
