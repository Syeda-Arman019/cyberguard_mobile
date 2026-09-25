package com.example.cyberguard_mobile.autoprotection

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import com.example.cyberguard_mobile.MainActivity
import com.example.cyberguard_mobile.R

/**
 * Native alert path for Auto Protection detections that happen while the
 * Flutter UI is NOT in the foreground (screen off, app swiped away).
 *
 * This does NOT replace the existing Dart alert system (ScanAlertService +
 * SirenService): when the app is open, alerts go through the EXISTING Dart
 * flow exactly as before. This native manager is only the fallback that makes
 * background detections audible/visible, and it reuses the same design:
 * bounded alarm sound, bounded vibration, one stable notification id.
 */
object AlertManager {

    private const val TAG = "CyberGuardGatekeeper"
    private const val CHANNEL_ID = "cyberguard_autoprotection"
    private const val NOTIF_ID = 4243 // distinct from the Dart-side 4242 danger id

    /// Intent extra carrying the alerted URL. Same key as MainActivity's
    /// danger-notification extra so ONE tap handler routes both notifications
    /// (4242 Dart-side and 4243 native) to the existing warning screen.
    const val DANGER_URL_EXTRA = "cyberguard_danger_url"

    @Volatile private var siren: MediaPlayer? = null

    /// Shows the heads-up danger notification and starts the bounded
    /// siren + vibration (when [sound]/[vibrate] allow). Called only for
    /// SUSPICIOUS/MALICIOUS results.
    fun alertDanger(
        context: Context,
        level: String,
        url: String,
        sourceApp: String,
        reason: String,
        sound: Boolean = true,
        vibrate: Boolean = true,
    ) {
        try {
            showHeadsUp(context, level, url, sourceApp, reason)
            if (sound) playSirenBounded(context)
            if (vibrate) vibrateBounded(context)
        } catch (e: Exception) {
            Log.w(TAG, "alertDanger failed: ${e.message}")
        }
    }

    /// Optional "safe link verified" notice (default OFF in settings).
    fun showSafeNotice(context: Context, url: String, sourceApp: String) {
        try {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= 26) {
                manager.createNotificationChannel(
                    NotificationChannel(
                        "cyberguard_safe",
                        "Safe link confirmations",
                        NotificationManager.IMPORTANCE_LOW
                    )
                )
            }
            val notification = NotificationCompat.Builder(context, "cyberguard_safe")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("🟢 Link verified safe")
                .setContentText("$sourceApp — $url")
                .setAutoCancel(true)
                .build()
            manager.notify(NOTIF_ID + 10, notification)
        } catch (e: Exception) {
            Log.w(TAG, "showSafeNotice failed: ${e.message}")
        }
    }

    /// Stops siren + vibration and cancels the native heads-up (4243).
    /// Called from Dart (SILENCE ALERT / GO BACK / OPEN ANYWAY) and before
    /// any new playback. The Dart-side 4242 notification is cancelled
    /// separately by ScanAlertService.cancelDangerNotification.
    fun stopSounds(context: Context? = null) {
        try {
            siren?.let { if (it.isPlaying) it.stop(); it.release() }
        } catch (_: Exception) {
        }
        siren = null
        vibrateCancel()
        // Cancel the native 4243 heads-up so SILENCE ALERT fully clears the
        // shade (the notification is autoCancel only when TAPPED, not when
        // silenced in-app).
        context?.let {
            try {
                (it.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                    .cancel(NOTIF_ID)
            } catch (_: Exception) {
            }
        }
    }

    private fun showHeadsUp(context: Context, level: String, url: String, sourceApp: String, reason: String) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Auto Protection alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Dangerous links detected automatically in your notifications"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 400, 200, 400, 200, 400)
                val attrs = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM) // alarm stream per spec
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                setSound(Settings.System.DEFAULT_NOTIFICATION_URI, attrs)
            }
            manager.createNotificationChannel(channel)
        }

        // Tapping the native heads-up must open the EXISTING warning screen
        // for this URL (SILENCE ALERT / GO BACK / OPEN ANYWAY) — never the
        // bare dashboard. Single-task launch routes through onNewIntent.
        val tapIntent = PendingIntent.getActivity(
            context, NOTIF_ID,
            Intent(context, MainActivity::class.java).apply {
                putExtra(DANGER_URL_EXTRA, url)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val title = if (level == "MALICIOUS") "🚨 Malicious link detected (Auto Protection)"
                    else "⚠️ Suspicious link detected (Auto Protection)"
        val text = "From $sourceApp — do not open: $url"

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText("$text\n$reason"))
            .setPriority(NotificationCompat.PRIORITY_HIGH) // heads-up; no fullscreen intent
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(tapIntent)
            .build()
        manager.notify(NOTIF_ID, notification)
    }

    /// Bounded: the bundled siren asset (res/raw, same file as the Flutter
    /// asset) plays at most twice, then stops.
    private fun playSirenBounded(context: Context) {
        stopSounds()
        try {
            val player = MediaPlayer()
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            player.setDataSource(context, android.net.Uri.parse("android.resource://${context.packageName}/${R.raw.siren_alert}"))
            player.isLooping = false
            var plays = 0
            player.setOnCompletionListener {
                plays++
                if (plays < 2) {
                    try { player.seekTo(0); player.start() } catch (_: Exception) {}
                } else {
                    try { player.release() } catch (_: Exception) {}
                    siren = null
                }
            }
            player.prepare()
            player.start()
            siren = player
        } catch (e: Exception) {
            Log.w(TAG, "siren playback unavailable: ${e.message}")
        }
    }

    private fun vibrateBounded(context: Context) {
        try {
            val vibrator = getVibrator(context) ?: return
            val effect = VibrationEffect.createWaveform(longArrayOf(0, 400, 200, 400, 200, 400), -1)
            vibrator.vibrate(effect)
        } catch (_: Exception) {
        }
    }

    private fun vibrateCancel() {
        try {
            getVibrator(null)?.cancel()
        } catch (_: Exception) {
        }
    }

    private fun getVibrator(context: Context?): Vibrator? {
        if (context == null) return null
        return if (Build.VERSION.SDK_INT >= 31) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }
}
