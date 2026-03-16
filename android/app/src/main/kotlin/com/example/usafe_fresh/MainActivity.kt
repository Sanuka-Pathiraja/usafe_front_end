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
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.usafe_frontend/sos"
    private val NOTIFICATION_ID = 100
    private val NOTIFICATION_CHANNEL_ID = "sos_emergency_channel"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
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
        handleSOSIntent(intent)
    }

    private var sosChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        sosChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        sosChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
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
    }

    private fun handleSOSIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("SOS_TRIGGERED", false) == true) {
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            prefs.edit().putBoolean("flutter.SOS_TRIGGERED", true).apply()
            prefs.edit().putLong("flutter.SOS_TRIGGERED_TS", System.currentTimeMillis()).apply()
            sosChannel?.invokeMethod("sosTriggered", null)
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
            putExtra("SOS_TRIGGERED", true)
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
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
