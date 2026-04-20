package com.conscience.app

import android.accessibilityservice.AccessibilityServiceInfo
import android.accessibilityservice.AccessibilityManager
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import androidx.core.content.LocalBroadcastManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "conscience/screenTime"
        const val EVENTS = "conscience/avatarEvents"
    }

    private var eventSink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())
    private var avatarReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)

        // MethodChannel for imperative calls
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermissions" -> handleRequestPermissions(result)
                    "openPermissionSettings" -> handleOpenPermissionSettings(result)
                    "configureMonitoring" -> {
                        val args = call.arguments as Map<String, Any>
                        handleConfigureMonitoring(args, result)
                    }
                    "grantExtension" -> {
                        val args = call.arguments as Map<String, Any>
                        handleGrantExtension(args, result)
                    }
                    "resetBlock" -> handleResetBlock(result)
                    "consumePendingDeepLink" -> result.success(null)
                    else -> result.notImplemented()
                }
            }

        // EventChannel for avatar stage stream
        EventChannel(engine.dartExecutor.binaryMessenger, EVENTS)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, eventSink: EventChannel.EventSink?) {
                    this@MainActivity.eventSink = eventSink
                    // Register broadcast receiver for avatar updates
                    avatarReceiver =
                        object : BroadcastReceiver() {
                            override fun onReceive(context: Context, intent: Intent) {
                                val stage =
                                    intent.getStringExtra(ConscienceAccessibilityService.EXTRA_STAGE)
                                        ?: "ZEN"
                                eventSink?.success(stage.lowercase())
                            }
                        }
                    val filter =
                        IntentFilter(ConscienceAccessibilityService.ACTION_AVATAR_UPDATE)
                    LocalBroadcastManager.getInstance(applicationContext)
                        .registerReceiver(avatarReceiver!!, filter)
                }

                override fun onCancel(args: Any?) {
                    if (avatarReceiver != null) {
                        LocalBroadcastManager.getInstance(applicationContext)
                            .unregisterReceiver(avatarReceiver!!)
                        avatarReceiver = null
                    }
                    this@MainActivity.eventSink = null
                }
            })
    }

    private fun handleRequestPermissions(result: MethodChannel.Result) {
        val granted = checkAccessibilityPermission() && checkOverlayPermission()
        val status =
            when {
                granted -> "granted"
                else -> "needsSettings"
            }
        result.success(status)
    }

    private fun checkAccessibilityPermission(): Boolean {
        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val services = am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_GENERIC)
        return services.any { it.id.contains("com.conscience.app") }
    }

    private fun checkOverlayPermission(): Boolean =
        android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.M ||
            Settings.canDrawOverlays(this)

    private fun handleOpenPermissionSettings(result: MethodChannel.Result) {
        // Overlay first, then accessibility
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M &&
            !Settings.canDrawOverlays(this)
        ) {
            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
            intent.data = android.net.Uri.parse("package:$packageName")
            startActivity(intent)
        }

        // Accessibility settings
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        startActivity(intent)
        result.success(null)
    }

    private fun handleConfigureMonitoring(args: Map<String, Any>, result: MethodChannel.Result) {
        @Suppress("UNCHECKED_CAST")
        val packageNames = (args["packageNames"] as? List<String>)?.toSet() ?: emptySet()
        val dailyLimitMinutes = (args["dailyLimitMinutes"] as? Number)?.toLong() ?: 60
        val dailyLimitMs = dailyLimitMinutes * 60 * 1000

        ConscienceAccessibilityService.viceApps = packageNames
        ConscienceAccessibilityService.dailyLimitMs = dailyLimitMs

        Log.d("MainActivity", "Monitoring config: $dailyLimitMinutes min, $packageNames")
        result.success(null)
    }

    private fun handleGrantExtension(args: Map<String, Any>, result: MethodChannel.Result) {
        val durationMinutes = (args["durationMinutes"] as? Number)?.toLong() ?: 10
        val durationMs = durationMinutes * 60 * 1000

        // Signal to accessibility service to lift block temporarily
        val intent = Intent(ConscienceAccessibilityService.ACTION_GRANT_EXT)
        intent.putExtra("durationMs", durationMs)
        LocalBroadcastManager.getInstance(applicationContext).sendBroadcast(intent)

        result.success(null)
    }

    private fun handleResetBlock(result: MethodChannel.Result) {
        // Reset usage counter and dismiss overlay
        val intent = Intent(ConscienceAccessibilityService.ACTION_RESET)
        LocalBroadcastManager.getInstance(applicationContext).sendBroadcast(intent)
        result.success(null)
    }

    override fun onDestroy() {
        if (avatarReceiver != null) {
            LocalBroadcastManager.getInstance(applicationContext).unregisterReceiver(avatarReceiver!!)
            avatarReceiver = null
        }
        super.onDestroy()
    }
}
