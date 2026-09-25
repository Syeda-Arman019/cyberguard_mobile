package com.example.cyberguard_mobile.autoprotection

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

/**
 * Owns the Auto Protection Dart runtime so URL detection works whether the
 * UI is open, backgrounded, or completely swiped away.
 *
 * Two channels can carry the autoprotection traffic:
 *  - FOREGROUND: MainActivity's FlutterEngine channel (set via [setForegroundChannel]).
 *  - BACKGROUND: a headless FlutterEngine created and owned by
 *    [AutoProtectionForegroundService] (see [ensureBackgroundEngine]).
 *
 * URL delivery ([push]) routes to the first ready channel; when neither is
 * ready, URLs are queued (bounded) and the background engine is started.
 * A native last-resort fallback ([NativeFallback]) fires if Dart does not
 * acknowledge within the timer window, so a dangerous link never ends in
 * silence. Dart acknowledges via the `analysisComplete` method call.
 */
object AutoProtectionEngineHolder {

    private const val TAG = "CyberGuardGatekeeper"
    private const val CHANNEL = "com.example.cyberguard/autoprotection"
    private const val BACKGROUND_ENTRYPOINT = "autoProtectionBackgroundMain"

    /// Max queued URLs while no Dart runtime is ready.
    private const val QUEUE_LIMIT = 32

    /// How long Dart has to acknowledge an analysis before the native
    /// fallback takes over.
    private const val FALLBACK_TIMEOUT_MS = 8_000L

    @Volatile private var dartReady = false
    private var fgChannel: MethodChannel? = null
    private var bgEngine: FlutterEngine? = null
    private var bgChannel: MethodChannel? = null

    private val queue = ArrayDeque<Pair<String, String>>()
    private val handler = Handler(Looper.getMainLooper())
    private var fallbackRunnable: Runnable? = null
    private var pendingUrl: String? = null

    /** MainActivity registers its engine's channel here. */
    fun setForegroundChannel(channel: MethodChannel?) {
        fgChannel = channel
    }

    /** Marks the Dart side (whichever engine) ready and flushes the queue. */
    fun onDartReady() {
        Log.i(TAG, "Engine ready — flushing ${queue.size} queued URL(s)")
        dartReady = true
        flush()
    }

    /** Dart finished analyzing [url] — cancel the native fallback timer. */
    fun onAnalysisComplete(url: String?) {
        if (url == pendingUrl) {
            Log.i(TAG, "Analysis acknowledged by Dart: $url")
            cancelFallback()
        }
    }

    /**
     * Entry point used by the listener bridge. Always called on the main
     * thread; delivers or queues. Never drops a URL.
     */
    fun push(context: Context, url: String, sourcePackage: String) {
        handler.post {
            Log.i(TAG, "URL received: url=$url pkg=$sourcePackage ready=$dartReady queued=${queue.size}")
            val channel = activeChannel()
            if (channel != null && dartReady) {
                deliver(channel, context.applicationContext, url, sourcePackage)
            } else {
                if (queue.size >= QUEUE_LIMIT) queue.removeFirst()
                queue.addLast(url to sourcePackage)
                Log.i(TAG, "Engine unavailable — URL queued (total ${queue.size}), starting engine")
                ensureBackgroundEngine(context.applicationContext)
            }
        }
    }

    private fun activeChannel(): MethodChannel? {
        fgChannel?.let { if (it != null) return fgChannel }
        return bgChannel
    }

    private fun deliver(channel: MethodChannel, context: Context, url: String, sourcePackage: String) {
        pendingUrl = url
        Log.i(TAG, "URL delivered to Dart: url=$url (fallback in ${FALLBACK_TIMEOUT_MS}ms)")
        channel.invokeMethod("onNotificationUrl", mapOf(
            "url" to url,
            "sourcePackage" to sourcePackage,
        ))
        armFallback(context.applicationContext, url, sourcePackage)
    }

    private fun flush() {
        // Deliver on the foreground channel when present (UI open), else the
        // background engine's channel.
        val channel = fgChannel ?: bgChannel ?: return
        val ctx = appContext ?: return
        while (queue.isNotEmpty()) {
            val (url, pkg) = queue.removeFirst()
            deliver(channel, ctx, url, pkg)
        }
    }

    private fun armFallback(context: Context, url: String, sourcePackage: String) {
        cancelFallback()
        fallbackRunnable = Runnable {
        Log.w(TAG, "Dart did not answer within ${FALLBACK_TIMEOUT_MS}ms — NATIVE FALLBACK for $url")
            pendingUrl = null
            Thread { NativeFallback.evaluate(context, url, sourcePackage) }.start()
        }
        handler.postDelayed(fallbackRunnable!!, FALLBACK_TIMEOUT_MS)
    }

    private fun cancelFallback() {
        fallbackRunnable?.let { handler.removeCallbacks(it) }
        fallbackRunnable = null
    }

    /**
     * Creates (once) the headless FlutterEngine running
     * [BACKGROUND_ENTRYPOINT], registers all Flutter plugins (shared_prefs,
     * http, audioplayers, vibration, path_provider — everything the existing
     * RiskEngine/HistoryService/ScanAlertService need) and wires the channel.
     */
    @Synchronized
    fun ensureBackgroundEngine(context: Context) {
        if (bgEngine != null) return
        Log.i(TAG, "Engine starting")
        try {
            val appCtx = context.applicationContext
            val dartVm = FlutterInjector.instance().flutterLoader()
            dartVm.startInitialization(appCtx)
            dartVm.ensureInitializationComplete(appCtx, emptyArray())
            val engine = FlutterEngine(appCtx)
            bgEngine = engine
            val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            attachChannelHandlers(channel)
            bgChannel = channel
            GeneratedPluginRegistrant.registerWith(engine)
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(
                    dartVm.findAppBundlePath(),
                    BACKGROUND_ENTRYPOINT,
                )
            )
            Log.i(TAG, "Engine ready (background)")
        } catch (t: Throwable) {
            Log.w(TAG, "Engine failed to start: ${t.javaClass.simpleName}: ${t.message}")
            bgEngine = null
            bgChannel = null
        }
    }

    /** Tears the headless engine down (service stopped / protection off). */
    @Synchronized
    fun teardownBackgroundEngine() {
        try {
            bgEngine?.destroy()
        } catch (_: Exception) {
        }
        bgEngine = null
        bgChannel = null
        dartReady = fgChannel != null
        Log.i(TAG, "Headless engine torn down")
    }

    /**
     * Shared native-side handling of Dart→native calls. Registered on BOTH
     * engines' channels so either runtime can control the feature.
     */
    fun attachChannelHandlers(channel: MethodChannel) {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "backgroundReady" -> {
                    onDartReady()
                    result.success(true)
                }
                "analysisComplete" -> {
                    Log.i(TAG, "Analysis completed: ${call.argument<String>("url")}")
                    onAnalysisComplete(call.argument<String>("url"))
                    result.success(true)
                }
                "isListenerConnected" -> result.success(
                    LinkNotificationListener.isServiceConnected()
                )
                "isServiceRunning" -> result.success(AutoProtectionForegroundService.isRunning)
                "setAllowedPackages" -> {
                    val pkgs = call.argument<List<String>>("packages") ?: emptyList()
                    LinkNotificationListener.allowedPackages = pkgs.toSet()
                    result.success(true)
                }
                "startService" -> {
                    AutoProtectionForegroundService.start(context())
                    result.success(true)
                }
                "stopService" -> {
                    AutoProtectionForegroundService.stop(context())
                    result.success(true)
                }
                "openNotificationAccessSettings" -> {
                    try {
                        startSettings(android.provider.Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("unavailable", e.message, null)
                    }
                }
                "openBatteryOptimizationSettings" -> {
                    try {
                        startSettings(android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        result.success(true)
                    } catch (_: Exception) {
                        try {
                            startSettings(android.provider.Settings.ACTION_SETTINGS)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("unavailable", e.message, null)
                        }
                    }
                }
                "isIgnoringBatteryOptimizations" -> {
                    val pm = context().getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                    result.success(pm.isIgnoringBatteryOptimizations(context().packageName))
                }
                "alertDanger" -> {
                    val level = call.argument<String>("level") ?: "MALICIOUS"
                    val url = call.argument<String>("url") ?: ""
                    val sourceApp = call.argument<String>("sourceApp") ?: "unknown app"
                    val reason = call.argument<String>("reason") ?: ""
                    val sound = call.argument<Boolean>("sound") ?: true
                    val vibrate = call.argument<Boolean>("vibrate") ?: true
                    AlertManager.alertDanger(context(), level, url, sourceApp, reason, sound, vibrate)
                    result.success(true)
                }
                "stopAlertSounds" -> {
                    AlertManager.stopSounds(context())
                    // Also cancel the Dart-side persistent danger notification
                    // (4242) so one SILENCE ALERT clears both shade entries.
                    try {
                        androidx.core.app.NotificationManagerCompat.from(context())
                            .cancel(4242)
                    } catch (_: Exception) {
                    }
                    result.success(true)
                }
                "notifySafe" -> {
                    val url = call.argument<String>("url") ?: ""
                    val sourceApp = call.argument<String>("sourceApp") ?: "unknown app"
                    AlertManager.showSafeNotice(context(), url, sourceApp)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    @Volatile private var appContext: Context? = null

    /** The service/MainActivity both report their context for later use. */
    fun provideContext(context: Context) {
        appContext = context.applicationContext
    }

    private fun context(): Context = appContext
        ?: throw IllegalStateException("AutoProtection context not provided yet")

    private fun startSettings(action: String) {
        val intent = android.content.Intent(action)
        intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
        context().startActivity(intent)
    }
}
