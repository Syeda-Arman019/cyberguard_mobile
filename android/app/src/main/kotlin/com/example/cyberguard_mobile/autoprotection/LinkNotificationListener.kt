package com.example.cyberguard_mobile.autoprotection

import android.app.Notification
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.core.app.NotificationCompat
import com.example.cyberguard_mobile.MainActivity

/**
 * Layer 1 of Auto Protection: watches incoming notifications from user-enabled
 * messaging/email apps, extracts any URLs and hands them to the Flutter side
 * (existing RiskEngine + ScanAlertService) over a MethodChannel.
 *
 * Privacy scope (Play-Store disclosure): only TEXT of notifications from
 * user-enabled apps is read; ONLY URLs are extracted and forwarded for
 * analysis. No notification content is stored natively.
 *
 * Does NOT use READ_SMS / RECEIVE_SMS / AccessibilityService.
 */
class LinkNotificationListener : NotificationListenerService() {

    companion object {
        const val TAG = "CyberGuardGatekeeper"

        /// Package allowlist shown by default in Settings; the user can add/remove.
        val DEFAULT_PACKAGES = setOf(
            "com.whatsapp",              // WhatsApp
            "com.whatsapp.w4b",          // WhatsApp Business
            "com.google.android.apps.messaging", // Google Messages
            "com.samsung.android.messaging",     // Samsung Messages
            "com.android.mms",           // AOSP/other SMS
            "com.android.messaging",     // other SMS apps
            "com.google.android.gm",     // Gmail
            "com.microsoft.office.outlook", // Outlook
            "com.microsoft.android.outlook", // Outlook alt id
            "org.telegram.messenger",    // Telegram
            "com.facebook.orca",         // Messenger
            "com.facebook.mlite",        // Messenger Lite
            "com.instagram.android"      // Instagram DMs
        )

        /// Set by MainActivity when the Flutter engine is ready.
        @Volatile
        var bridge: ChannelBridge? = null

        /// User-configured allowlist (pushed from the Settings screen).
        /// Falls back to [DEFAULT_PACKAGES] when the user hasn't customized.
        @Volatile
        var allowedPackages: Set<String> = DEFAULT_PACKAGES

        /// Convenience for Settings UI / status card.
        fun isServiceConnected(): Boolean = bridge != null
    }

    /** Minimal bridge so the listener never depends on Flutter internals. */
    interface ChannelBridge {
        fun pushUrl(url: String, sourcePackage: String)
    }

    /**
     * Routes every discovered URL through the engine holder, which owns the
     * queue + headless-engine startup + native fallback so detection works
     * with the app open, backgrounded, or completely swiped away.
     */
    private fun routeToDart(url: String, pkg: String) {
        val ctx = applicationContext
        AutoProtectionEngineHolder.push(ctx, url, pkg)
    }

    /// Dedup cache: URL -> first-seen timestamp. A small LRU with expiry keeps
    /// memory bounded and prevents re-scanning the same link within minutes.
    private val recentUrls = object : LinkedHashMap<String, Long>(64, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Long>): Boolean =
            size > 128
    }
    private val dedupWindowMs = 5 * 60 * 1000L // "last few minutes"
    private val lock = Any()

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.i(TAG, "Listener connected")
        // Lifecycle recovery: if the process was restarted (Android recreated
        // it, boot, or One UI killed the old one) the foreground service may
        // not be running even though notification access is granted. Revive
        // it so the headless Dart engine is available when the UI is closed.
        // Gated on the persisted Auto Protection master + notification-scan
        // prefs (read natively, same store the Settings screen writes).
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val enabled = prefs.getBoolean("flutter.auto_protection_enabled", false) &&
                prefs.getBoolean("flutter.auto_protection_notification_scan", false)
            if (enabled && !AutoProtectionForegroundService.isRunning) {
                Log.i(TAG, "Listener connected — reviving Auto Protection service")
                AutoProtectionForegroundService.start(this)
            }
        } catch (_: Exception) {
            // Prefs unavailable — never break the listener binding.
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            val pkg = sbn.packageName ?: return

            // Never scan our own notifications (e.g. the danger alert or the
            // persistent "Auto Protection is ON" notice) — recursion guard.
            if (pkg == packageName) return

            // Only user-enabled packages participate.
            if (pkg !in allowedPackages) return

            // Ongoing / group-summary / progress notifications carry no user
            // message text worth scanning.
            val notif = sbn.notification ?: return
            if (notif.flags and Notification.FLAG_ONGOING_EVENT != 0) return
            if (notif.flags and Notification.FLAG_GROUP_SUMMARY != 0) return

            val texts = extractTexts(notif)
            if (texts.isEmpty()) return

            for (text in texts) {
                for (url in UrlExtractor.extract(text)) {
                    if (isDuplicate(url)) continue
                    Log.i(TAG, "URL received from $pkg: $url")
                    val b = bridge
                    if (b != null) b.pushUrl(url, pkg) else routeToDart(url, pkg)
                }
            }
        } catch (e: Exception) {
            // A malformed notification must never crash the listener.
            Log.w(TAG, "onNotificationPosted failed: ${e.message}")
        }
    }

    override fun onListenerDisconnected() {
        // System dropped the binding (memory pressure etc.): ask to rebind.
        Log.w(TAG, "Listener disconnected — requesting rebind")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            requestRebind(android.content.ComponentName(this, LinkNotificationListener::class.java))
        }
        super.onListenerDisconnected()
    }

    /// All user-visible text surfaces of a notification, including
    /// MessagingStyle conversation messages and grouped inbox lines.
    private fun extractTexts(notif: Notification): List<String> {
        val out = LinkedHashSet<String>()
        val extras = notif.extras ?: return emptyList()

        for (key in arrayOf(
            Notification.EXTRA_TITLE,
            Notification.EXTRA_TEXT,
            Notification.EXTRA_BIG_TEXT,
            Notification.EXTRA_SUB_TEXT
        )) {
            (extras.getCharSequence(key))?.let { if (it.isNotBlank()) out.add(it.toString()) }
        }

        // EXTRA_TEXT_LINES: InboxStyle grouped chats.
        (extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES))?.forEach {
            if (!it.isNullOrBlank()) out.add(it.toString())
        }

        // EXTRA_MESSAGES: MessagingStyle (WhatsApp/Telegram/Messenger long chats).
        // Entries are Bundles with keys "text" (and "sender"/"time"). Some
        // OEM builds deliver them as Parcelable messages — only Bundle form is
        // reliably readable, so anything else is skipped.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val messages = extras.getParcelableArray(Notification.EXTRA_MESSAGES)
            messages?.forEach { msg ->
                try {
                    if (msg is Bundle) {
                        val text = msg.getCharSequence("text")
                        if (!text.isNullOrBlank()) out.add(text.toString())
                    }
                } catch (_: Exception) {
                }
            }
        }
        return out.toList()
    }

    /// True when this exact URL was scanned within the dedup window.
    private fun isDuplicate(url: String): Boolean = synchronized(lock) {
        val now = System.currentTimeMillis()
        // Expire old entries opportunistically.
        recentUrls.entries.removeIf { now - it.value > dedupWindowMs }
        val seen = recentUrls[url]
        recentUrls[url] = now
        return seen != null && (now - seen) < dedupWindowMs
    }
}
