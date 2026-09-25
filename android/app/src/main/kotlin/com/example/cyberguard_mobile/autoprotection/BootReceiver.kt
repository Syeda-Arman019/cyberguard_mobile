package com.example.cyberguard_mobile.autoprotection

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Restarts the Auto Protection foreground service after device reboot.
 * The notification-listener binding itself is re-established by the system;
 * the foreground service is what keeps our process alive in between.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.i("CyberGuardGatekeeper", "Boot completed — restarting Auto Protection service")
            AutoProtectionForegroundService.start(context)
        }
    }
}
