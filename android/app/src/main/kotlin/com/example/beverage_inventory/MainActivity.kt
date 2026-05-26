package com.example.beverage_inventory

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val NOTIF_CHANNEL = "com.brian.beverage_inventory/notifications"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIF_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showNotification" -> {
                        val id = call.argument<Int>("id") ?: 999
                        val title = call.argument<String>("title") ?: ""
                        val body = call.argument<String>("body") ?: ""
                        val channelId = call.argument<String>("channelId") ?: "aura_sync_v3"
                        showNativeNotification(id, title, body, channelId)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun showNativeNotification(id: Int, title: String, body: String, channelId: String) {
        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setAutoCancel(true)
            .build()
        NotificationManagerCompat.from(this).notify(id, notification)
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java) ?: return

            if (manager.getNotificationChannel("aura_sync_v3") == null) {
                val channel = NotificationChannel(
                    "aura_sync_v3",
                    "Aura Cloud Sync",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Alerts when your sales are saved to the cloud"
                    enableVibration(true)
                    enableLights(true)
                }
                manager.createNotificationChannel(channel)
            }

            if (manager.getNotificationChannel("aura_alerts") == null) {
                val channel = NotificationChannel(
                    "aura_alerts",
                    "Aura Alerts",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Instant alerts and stock warnings"
                    enableVibration(true)
                }
                manager.createNotificationChannel(channel)
            }
        }
    }
}
