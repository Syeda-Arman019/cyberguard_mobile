package com.example.cyberguard_mobile

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SHARE_CHANNEL = "com.example.cyberguard/share"
    private val VIEW_CHANNEL = "com.example.cyberguard/view"
    private val NOTIFY_CHANNEL = "com.example.cyberguard/notifications"
    private val NOTIF_CHANNEL_ID = "cyberguard_danger"
    private val NOTIF_ID = 4242

    private val TAG = "CyberGuardIntent"

    private var shareChannel: MethodChannel? = null
    private var viewChannel: MethodChannel? = null

    // URL from a cold-start ACTION_VIEW intent. The Flutter engine starts
    // executing Dart only after onCreate() returns, so it cannot be pushed
    // yet — Dart pulls it via view_channel.getInitialUrl once ready.
    private var pendingViewUrl: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (intent?.action == Intent.ACTION_VIEW) {
            pendingViewUrl = intent?.dataString
            Log.d(TAG, "VIEW URL RECEIVED (cold start): $pendingViewUrl")
        }
        // Initialize the method channels after Flutter engine is ready
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            shareChannel = MethodChannel(messenger, SHARE_CHANNEL)
            viewChannel = MethodChannel(messenger, VIEW_CHANNEL)
            MethodChannel(messenger, NOTIFY_CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "showDangerNotification" -> {
                        val title = call.argument<String>("title")
                            ?: "CyberGuard — Dangerous URL Detected"
                        val body = call.argument<String>("body") ?: ""
                        result.success(showDangerNotification(title, body))
                    }
                    "cancelDangerNotification" -> {
                        NotificationManagerCompat.from(this).cancel(NOTIF_ID)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        handleSendIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleSendIntent(intent)
        handleViewIntent(intent)
    }

    private fun handleSendIntent(intent: Intent?) {
        if (intent == null) return
        if (Intent.ACTION_SEND == intent.action && "text/plain" == intent.type) {
            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
            Log.d(TAG, "SEND INTENT RECEIVED: hasText=${sharedText != null}")
            if (sharedText != null) {
                shareChannel?.invokeMethod("shareText", sharedText)
            }
        }
    }

    private fun handleViewIntent(intent: Intent?) {
        if (intent == null) return
        if (Intent.ACTION_VIEW == intent.action) {
            val url = intent.dataString
            Log.d(TAG, "VIEW URL RECEIVED (warm start): $url")
            if (url != null && (url.startsWith("http://") || url.startsWith("https://"))) {
                viewChannel?.invokeMethod("viewUrl", url)
            } else {
                Log.d(TAG, "VIEW URL ignored: not http/https")
            }
        }
    }

    /**
     * Shows the persistent danger notification for a risky scan result.
     * Returns false when the user has not granted POST_NOTIFICATIONS (the
     * Dart side then keeps the in-app warning as the only alert).
     */
    private fun showDangerNotification(title: String, body: String): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }
        val manager = NotificationManagerCompat.from(this)
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel(
                    NOTIF_CHANNEL_ID,
                    "Dangerous URL alerts",
                    NotificationManager.IMPORTANCE_HIGH
                )
            )
        }
        // Tapping the notification brings the app's task to the front
        // (singleTask launch mode routes it through onNewIntent).
        val tapIntent = PendingIntent.getActivity(
            this,
            NOTIF_ID,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(this, NOTIF_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(tapIntent)
            .build()
        return try {
            manager.notify(NOTIF_ID, notification)
            true
        } catch (e: SecurityException) {
            false
        }
    }
}
