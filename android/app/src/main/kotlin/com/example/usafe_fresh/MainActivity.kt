package com.example.usafe_fresh

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.usafe_frontend/sos"
        private const val METHOD_CHANNEL = "usafe/monitor"
        private const val EVENT_CHANNEL = "usafe/monitor_events"
        private const val EXTRA_RESTORE_LISTENING = "restore_listening"
        private const val NOTIFICATION_ID = 100
        private const val NOTIFICATION_CHANNEL_ID = "sos_emergency_channel"
        private const val SOS_SOURCE_KEY = "SOS_SOURCE"
        private const val SOS_TRIGGERED_KEY = "SOS_TRIGGERED"
        private const val ACTION_SOS_NOTIFICATION = "com.usafe_frontend.SOS_NOTIFICATION"
        private const val ACTION_SOS_WIDGET = "com.usafe_frontend.SOS_WIDGET"
        private const val ACTION_SOS_BADGE = "com.usafe_frontend.SOS_BADGE"
        private const val TAG = "USafeSOS"
    }

    private var pendingRestoreRequest = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AppVisibilityTracker.install(application)
        pendingRestoreRequest = intent?.getBooleanExtra(EXTRA_RESTORE_LISTENING, false) == true
        handleSOSIntent(intent)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }

        showPersistentSOSNotification()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra(EXTRA_RESTORE_LISTENING, false)) {
            pendingRestoreRequest = true
        }
        handleSOSIntent(intent)
    }

    private var sosChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        sosChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        sosChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "openNotificationSettings" -> {
                    openNotificationSettings()
                    result.success(null)
                }
                "checkOverlayPermission" -> result.success(hasOverlayPermission())
                "requestOverlayPermission" -> {
                    openOverlaySettings()
                    result.success(null)
                }
                "checkSOSTrigger" -> {
                    val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                    val triggered = prefs.getBoolean("flutter.SOS_TRIGGERED", false)
                    prefs.edit().putBoolean("flutter.SOS_TRIGGERED", false).apply()
                    result.success(triggered)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startMonitoring" -> {
                        SafetyMonitorService.startService(this)
                        result.success(true)
                    }
                    "stopMonitoring" -> {
                        SafetyMonitorService.stopService(this)
                        result.success(true)
                    }
                    "restoreListening" -> {
                        SafetyMonitorService.restoreListeningWhenVisible(this)
                        result.success(true)
                    }
                    "consumeRestoreRequest" -> {
                        val shouldRestore = pendingRestoreRequest
                        if (shouldRestore) {
                            Log.d("MainActivity", "Notification restore request consumed")
                        }
                        pendingRestoreRequest = false
                        result.success(shouldRestore)
                    }
                    "getStatus" -> result.success(SafetyMonitorBridge.latestStatus.toMap())
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    SafetyMonitorBridge.attachSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    SafetyMonitorBridge.attachSink(null)
                }
            })
    }

    private fun handleSOSIntent(intent: Intent?) {
        val extras = intent?.extras?.keySet()?.joinToString(",")
        val trigger = intent?.getBooleanExtra(SOS_TRIGGERED_KEY, false)
        val sourceExtra = intent?.getStringExtra(SOS_SOURCE_KEY)
        Log.d(
            TAG,
            "handleSOSIntent action=${intent?.action} extras=$extras trigger=$trigger sourceExtra=$sourceExtra"
        )
        if (trigger == true) {
            val source = intent.getStringExtra(SOS_SOURCE_KEY)
                ?: when (intent.action) {
                    ACTION_SOS_WIDGET -> "widget"
                    ACTION_SOS_BADGE -> "USafe badge"
                    ACTION_SOS_NOTIFICATION -> "notification"
                    else -> "notification"
                }
            Log.d(TAG, "SOS triggered. resolvedSource=$source")
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            prefs.edit().putBoolean("flutter.SOS_TRIGGERED", true).apply()
            prefs.edit().putLong("flutter.SOS_TRIGGERED_TS", System.currentTimeMillis()).apply()
            prefs.edit().putString("flutter.SOS_TRIGGER_SOURCE", source).apply()
            Log.d(
                TAG,
                "Saved prefs: flutter.SOS_TRIGGERED=true, flutter.SOS_TRIGGER_SOURCE=$source"
            )
            sosChannel?.invokeMethod("sosTriggered", source)
        }
    }

    private fun hasOverlayPermission(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) Settings.canDrawOverlays(this) else true

    private fun openOverlaySettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivity(intent)
        }
    }

    private fun openNotificationSettings() {
        val intent = Intent()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            intent.action = Settings.ACTION_APP_NOTIFICATION_SETTINGS
            intent.putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        } else {
            intent.action = "android.settings.APP_NOTIFICATION_SETTINGS"
            intent.putExtra("app_package", packageName)
            intent.putExtra("app_uid", applicationInfo.uid)
        }
        startActivity(intent)
    }

    private fun showPersistentSOSNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "SOS Protection",
                NotificationManager.IMPORTANCE_HIGH
            )
            manager.createNotificationChannel(channel)
        }

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            action = ACTION_SOS_NOTIFICATION
            putExtra(SOS_TRIGGERED_KEY, true)
            putExtra(SOS_SOURCE_KEY, "notification")
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            1001,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("USafe Protection Active")
            .setContentText("TAP HERE TO TRIGGER SOS")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()

        manager.notify(NOTIFICATION_ID, notification)
    }
}
