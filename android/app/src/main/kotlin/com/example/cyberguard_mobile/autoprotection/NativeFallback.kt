package com.example.cyberguard_mobile.autoprotection

import android.content.Context
import android.util.Log
import java.net.HttpURLConnection
import java.net.URL

/**
 * Last-resort native evaluation used ONLY when the Dart runtime (UI engine
 * or headless background engine) does not acknowledge within the fallback
 * window. A dangerous link must never end in silence.
 *
 * Minimal local check (suspicious patterns / known-bad host fragments) plus
 * an optional Google Safe Browsing lookup when the API key is present. The
 * Dart pipeline (existing RiskEngine/HistoryService/ScanAlertService) remains
 * the primary analyzer — this is a safety net, not a second analyzer.
 */
object NativeFallback {

    private const val TAG = "CyberGuardGatekeeper"

    // Keep in sync with RiskEngine's heuristics — intentionally tiny.
    private val SUSPICIOUS_FRAGMENTS = listOf(
        "login", "verify", "secure", "account", "update", "confirm", "bank", "wallet", "otp"
    )
    private val KNOWN_BAD_HOSTS = listOf(
        "testsafebrowsing.appspot.com", // Google's test-threat host
    )
    private val SHORTENERS = listOf(
        "bit.ly", "tinyurl.com", "t.co", "goo.gl", "cutt.ly", "rb.gy", "is.gd", "rebrand.ly"
    )

    private const val GSB_API_KEY = "AIzaSyCcORbkM9slYc0K-T7BdisM4CMrmQwsUP8"

    fun evaluate(context: Context, url: String, sourcePackage: String) {
        try {
            Log.w(TAG, "NativeFallback evaluating: $url")
            val level: String
            val reason: String

            val host = runCatching { URL(url).host.lowercase() }.getOrDefault("")
            val isTestBad = KNOWN_BAD_HOSTS.any { host == it || host.endsWith(".$it") }
            val hasSuspicious = SUSPICIOUS_FRAGMENTS.any { url.lowercase().contains(it) }
            val isShortener = SHORTENERS.any { host == it || host.endsWith(".$it") }

            val gsbThreat = checkSafeBrowsing(url)

            level = when {
                gsbThreat != null || isTestBad -> "MALICIOUS"
                hasSuspicious || isShortener -> "SUSPICIOUS"
                else -> "SAFE"
            }
            reason = when {
                gsbThreat != null -> "Google Safe Browsing flagged this URL as a $gsbThreat threat."
                isTestBad -> "This URL is a known Google Safe Browsing test threat."
                hasSuspicious -> "The link contains account/security-related keywords typical of phishing."
                isShortener -> "Shortened links hide the real destination — verify before opening."
                else -> "No threats detected by the quick native check (link not fully verified)."
            }

            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val siren = prefs.getBoolean("flutter.auto_protection_siren", true)
            val vibrate = prefs.getBoolean("flutter.auto_protection_vibration", true)

            Log.w(TAG, "NativeFallback verdict=$level reason=$reason siren=$siren vibrate=$vibrate")
            if (level == "SAFE") {
                if (prefs.getBoolean("flutter.auto_protection_notify_safe", false)) {
                    AlertManager.showSafeNotice(context, url, sourcePackage)
                }
            } else {
                AlertManager.alertDanger(context, level, url, sourcePackage, reason, siren, vibrate)
            }
        } catch (e: Exception) {
            Log.w(TAG, "NativeFallback failed: ${e.message}")
        }
    }

    /// Best-effort GSB check with a hard 3s budget; null on any failure.
    private fun checkSafeBrowsing(url: String): String? {
        if (GSB_API_KEY.isBlank()) return null
        return try {
            val conn = URL("https://safebrowsing.googleapis.com/v4/threatMatches:find?key=$GSB_API_KEY")
                .openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.connectTimeout = 2000
            conn.readTimeout = 3000
            conn.doOutput = true
            conn.setRequestProperty("Content-Type", "application/json")
            val body = """
                {"client":{"clientId":"cyberguard_native","clientVersion":"1.0"},
                 "threatInfo":{"threatTypes":["MALWARE","SOCIAL_ENGINEERING","UNWANTED_SOFTWARE"],
                 "platformTypes":["ANY_PLATFORM"],"threatEntryTypes":["URL"],
                 "threatEntries":[{"url":"$url"}]}}
            """.trimIndent()
            conn.outputStream.use { it.write(body.toByteArray()) }
            val code = conn.responseCode
            if (code == 200) {
                val text = conn.inputStream.bufferedReader().readText()
                if (text.contains("\"matches\"")) {
                    if (text.contains("SOCIAL_ENGINEERING")) "SOCIAL_ENGINEERING"
                    else if (text.contains("MALWARE")) "MALWARE"
                    else "THREAT"
                } else null
            } else null
        } catch (e: Exception) {
            Log.i(TAG, "NativeFallback GSB unavailable (${e.message}) — local check only")
            null
        }
    }
}
