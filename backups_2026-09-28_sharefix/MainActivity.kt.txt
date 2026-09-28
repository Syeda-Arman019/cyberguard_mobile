package com.example.cyberguard_mobile

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import com.example.cyberguard_mobile.autoprotection.AutoProtectionForegroundService
import com.example.cyberguard_mobile.autoprotection.LinkNotificationListener

class MainActivity : FlutterActivity() {
    private val SHARE_CHANNEL = "com.example.cyberguard/share"
    private val VIEW_CHANNEL = "com.example.cyberguard/view"
    private val NOTIFY_CHANNEL = "com.example.cyberguard/notifications"
    private val AUTO_PROTECT_CHANNEL = "com.example.cyberguard/autoprotection"
    private val NOTIF_CHANNEL_ID = "cyberguard_danger"
    private val NOTIF_ID = 4242

    private val TAG = "CyberGuardIntent"

    /// Intent extra carrying the alerted URL on the danger-notification tap.
    private val DANGER_URL_EXTRA = "cyberguard_danger_url"

    private var shareChannel: MethodChannel? = null
    private var viewChannel: MethodChannel? = null

    // URL from a cold-start ACTION_VIEW intent. The Flutter engine starts
    // executing Dart only after onCreate() returns, so it cannot be pushed
    // yet — Dart pulls it via view_channel.getInitialUrl once ready.
    private var pendingViewUrl: String? = null

    // URL of the currently active danger notification. Tapping the
    // notification routes the user to the warning screen for THIS URL;
    // it never changes any Protection Mode setting.
    private var pendingDangerUrl: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (intent?.action == Intent.ACTION_VIEW) {
            pendingViewUrl = intent?.dataString
            Log.d(TAG, "VIEW URL RECEIVED (cold start): $pendingViewUrl")
        }
        // Initialize the method channels after Flutter engine is ready
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            shareChannel = MethodChannel(messenger, SHARE_CHANNEL)
            viewChannel = MethodChannel(messenger, VIEW_CHANNEL).apply {
                // Dart pulls the cold-start URL here once the navigator is
                // ready. Without this handler the pull throws
                // MissingPluginException and a tapped link is silently lost.
                setMethodCallHandler { call, result ->
                    when (call.method) {
                        "getInitialUrl" -> result.success(pendingViewUrl.also {
                            if (it != null) {
                                pendingViewUrl = null
                                Log.d(TAG, "VIEW URL handed to Flutter (cold start): $it")
                            }
                        })
                        else -> result.notImplemented()
                    }
                }
            }
            MethodChannel(messenger, NOTIFY_CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "showDangerNotification" -> {
                        val title = call.argument<String>("title")
                            ?: "⚠️ CyberGuard Security Alert"
                        val body = call.argument<String>("body") ?: ""
                        val detail = call.argument<String>("detail")
                        // Remember the URL this alert is about so tapping the
                        // notification opens the existing warning screen for
                        // THAT result (never the bare dashboard).
                        pendingDangerUrl = call.argument<String>("url")
                        result.success(showDangerNotification(title, body, detail, pendingDangerUrl))
                    }
                    "cancelDangerNotification" -> {
                        NotificationManagerCompat.from(this).cancel(NOTIF_ID)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

            // Auto Protection: the shared engine holder owns this channel's
            // native handlers so the UI engine and the headless background
            // engine expose identical behavior.
            val apChannel = MethodChannel(messenger, AUTO_PROTECT_CHANNEL)
            com.example.cyberguard_mobile.autoprotection.AutoProtectionEngineHolder
                .provideContext(this)
            com.example.cyberguard_mobile.autoprotection.AutoProtectionEngineHolder
                .attachChannelHandlers(apChannel)
            com.example.cyberguard_mobile.autoprotection.AutoProtectionEngineHolder
                .setForegroundChannel(apChannel)

            // Bridge for the listener when the UI engine is alive.
            LinkNotificationListener.bridge = object : LinkNotificationListener.ChannelBridge {
                override fun pushUrl(url: String, sourcePackage: String) {
                    com.example.cyberguard_mobile.autoprotection.AutoProtectionEngineHolder
                        .push(this@MainActivity, url, sourcePackage)
                }
            }
        }
        handleSendIntent(intent)
        handleDangerTap(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleSendIntent(intent)
        handleViewIntent(intent)
        handleDangerTap(intent)
    }

    /// Danger-notification tap: opens the existing Auto Protection warning
    /// screen for the alerted URL. Deliberately does NOT touch Protection
    /// Mode, Auto Protection settings or any alert acknowledgement — only
    /// the in-app SILENCE ALERT button acknowledges the alert.
    private fun handleDangerTap(intent: Intent?) {
        val url = intent?.getStringExtra(DANGER_URL_EXTRA) ?: return
        if (url.isBlank()) return
        Log.d(TAG, "DANGER NOTIFICATION TAP: routing to warning screen for $url")
        val channel = viewChannel
        if (channel != null) {
            channel.invokeMethod("viewUrl", url)
        } else {
            // Cold start: Dart pulls it via getInitialUrl once ready.
            pendingViewUrl = url
        }
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

    /// Whether the user granted Notification access for this app.
    private fun isNotificationListenerEnabled(): Boolean {
        val flat = android.provider.Settings.Secure.getString(
            contentResolver, "enabled_notification_listeners"
        ) ?: return false
        return flat.split(":").any { it.contains(packageName, ignoreCase = true) }
    }

    /**
     * Shows the persistent danger notification for a risky scan result.
     * The short [body] is the collapsed content; [detail] (risk level,
     * domain, score, reason) is shown when expanded. The notification is
     * ongoing (no swipe dismiss) and never auto-cancels: it stays in the
     * shade across backgrounding, the siren ending, and screen changes, and
     * is removed ONLY by the explicit in-app acknowledgement (or a later
     * safe result) cancelling this stable id. Returns false when the user
     * has not granted POST_NOTIFICATIONS (the Dart side then keeps the
     * in-app warning as the only alert).
     */
    private fun showDangerNotification(title: String, body: String, detail: String?, url: String?): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }
        val manager = NotificationManagerCompat.from(this)
        if (Build.VERSION.SDK_INT >= 26) {
            // Security-warning channel: explicitly audible + vibrating (never
            // silent), high importance so it presents as a heads-up. Reused,
            // not duplicated — the id "cyberguard_danger" is the app's only
            // notification channel.
            val channel = NotificationChannel(
                NOTIF_CHANNEL_ID,
                "Dangerous URL alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description =
                    "Alerts for dangerous or suspicious URLs detected by CyberGuard"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 400, 200, 400, 200, 400)
                val soundAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                // Local, always-present system notification sound (short
                // warning tone). No network resource is used.
                setSound(Settings.System.DEFAULT_NOTIFICATION_URI, soundAttributes)
            }
            manager.createNotificationChannel(channel)
        }
        // Tapping the notification brings the app's task to the front
        // (singleTask launch mode routes it through onNewIntent) and carries
        // the alerted URL so the existing warning screen opens for it.
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        if (!url.isNullOrBlank()) launchIntent?.putExtra(DANGER_URL_EXTRA, url)
        val tapIntent = PendingIntent.getActivity(
            this,
            NOTIF_ID,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(this, NOTIF_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText(detail?.takeIf { it.isNotBlank() } ?: body)
            )
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
