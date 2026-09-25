package com.example.cyberguard_mobile.autoprotection

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.example.cyberguard_mobile.MainActivity

/**
 * Lightweight foreground service that keeps the NotificationListenerService
 * binding alive ("Auto Protection is ON" persistent, low-importance notice).
 * Started/stopped from Dart via the auto-protection channel; restarted on
 * boot by BootReceiver.
 */
class AutoProtectionForegroundService : android.app.Service() {

    companion object {
        const val TAG = "CyberGuardGatekeeper"
        const val CHANNEL_ID = "cyberguard_service"
        const val NOTIF_ID = 4244

        @Volatile var isRunning = false

        fun start(context: Context) {
            if (isRunning) return
            try {
                if (Build.VERSION.SDK_INT >= 26) {
                    context.startForegroundService(Intent(context, AutoProtectionForegroundService::class.java))
                } else {
                    context.startService(Intent(context, AutoProtectionForegroundService::class.java))
                }
            } catch (e: Exception) {
                Log.w(TAG, "start service failed: ${e.message}")
            }
        }

        fun stop(context: Context) {
            try { context.stopService(Intent(context, AutoProtectionForegroundService::class.java)) } catch (_: Exception) {}
        }
    }

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        startForeground(NOTIF_ID, buildNotification())
        // Own the Dart runtime for this process so URL detection works even
        // when the UI is closed: create the headless background engine.
        AutoProtectionEngineHolder.provideContext(this)
        AutoProtectionEngineHolder.ensureBackgroundEngine(this)
        Log.i(TAG, "Service created — foreground notice shown, engine starting")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onDestroy() {
        isRunning = false
        AutoProtectionEngineHolder.teardownBackgroundEngine()
        Log.i(TAG, "Service destroyed — background engine torn down")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?) = null

    private fun buildNotification(): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Auto Protection status",
                    NotificationManager.IMPORTANCE_LOW // silent, persistent
                ).apply { description = "Keeps Auto Protection listening in the background" }
            )
        }
        val tapIntent = PendingIntent.getActivity(
            this, NOTIF_ID, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Auto Protection is ON")
            .setContentText("CyberGuard is checking links in your messages.")
            .setOngoing(true)
            .setContentIntent(tapIntent)
            .build()
    }
}
