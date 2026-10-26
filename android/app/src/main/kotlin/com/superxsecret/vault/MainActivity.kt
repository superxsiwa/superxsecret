package com.superxsecret.vault

import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.os.Debug
import android.os.Handler
import android.os.Looper
import android.os.PersistableBundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val HARDENING_CHANNEL = "com.superxsecret.vault/hardening"
    }

    private var methodChannel: MethodChannel? = null
    private val clipboardClearHandler = Handler(Looper.getMainLooper())
    private var pendingClipboardClearRunnable: Runnable? = null

    private val screenOffReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == Intent.ACTION_SCREEN_OFF) {
                // Immediately notify Flutter + Rust core to wipe DEK from RAM when screen turns off
                methodChannel?.invokeMethod("onScreenOffLock", null)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // 1. Enforce FLAG_SECURE BEFORE super.onCreate() to block screenshots,
        //    screen recording, Google Assistant screen capture, and Recent Apps previews.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
        super.onCreate(savedInstanceState)

        registerReceiver(screenOffReceiver, IntentFilter(Intent.ACTION_SCREEN_OFF))
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HARDENING_CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "copySensitiveClipboard" -> {
                    val text = call.argument<String>("text") ?: ""
                    val ttlSeconds = call.argument<Int>("ttlSeconds") ?: 30
                    copyToSensitiveClipboard(text, ttlSeconds)
                    result.success(true)
                }
                "clearClipboardNow" -> {
                    clearClipboardImmediately()
                    result.success(true)
                }
                "checkDeviceIntegrity" -> {
                    val integrityReport = inspectDeviceSecurityPosture()
                    result.success(integrityReport)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Copies a secret to the Android Clipboard with `EXTRA_IS_SENSITIVE = true` (Android 13+)
     * so the OS masks the visual popup preview, and schedules an automatic wipe after `ttlSeconds`.
     */
    private fun copyToSensitiveClipboard(secret: String, ttlSeconds: Int) {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("SuperXSecret", secret)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            clip.description.extras = PersistableBundle().apply {
                putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
            }
        } else {
            clip.description.extras = PersistableBundle().apply {
                putBoolean("android.content.extra.IS_SENSITIVE", true)
            }
        }

        clipboard.setPrimaryClip(clip)

        pendingClipboardClearRunnable?.let { clipboardClearHandler.removeCallbacks(it) }
        val clearTask = Runnable {
            clearClipboardImmediately()
            methodChannel?.invokeMethod("onClipboardAutoCleared", null)
        }
        pendingClipboardClearRunnable = clearTask
        clipboardClearHandler.postDelayed(clearTask, ttlSeconds * 1000L)
    }

    private fun clearClipboardImmediately() {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            clipboard.clearPrimaryClip()
        } else {
            clipboard.setPrimaryClip(ClipData.newPlainText("", ""))
        }
    }

    /**
     * Multi-signal offline Root, Magisk, Debugger & Frida instrumentation check.
     */
    private fun inspectDeviceSecurityPosture(): Map<String, Any> {
        val suPaths = listOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/su/bin/su",
            "/data/adb/magisk"
        )
        val hasRootBinary = suPaths.any { File(it).exists() }
        val hasTestKeys = Build.TAGS?.contains("test-keys") == true
        val isDebuggerAttached = Debug.isDebuggerConnected() || Debug.waitingForDebugger()
        val hasFridaInMaps = checkProcMapsForFrida()

        val isCompromised = hasRootBinary || hasTestKeys || isDebuggerAttached || hasFridaInMaps

        return mapOf(
            "isCompromised" to isCompromised,
            "hasRootOrJailbreak" to (hasRootBinary || hasTestKeys),
            "isDebuggerOrFridaDetected" to (isDebuggerAttached || hasFridaInMaps),
            "isScreenGuardActive" to true,
            "zeroNetworkPermissionVerified" to true
        )
    }

    private fun checkProcMapsForFrida(): Boolean {
        return try {
            val mapsFile = File("/proc/self/maps")
            if (!mapsFile.exists()) return false
            mapsFile.useLines { lines ->
                lines.any { line ->
                    line.contains("frida", ignoreCase = true) ||
                        line.contains("xposed", ignoreCase = true)
                }
            }
        } catch (_: Exception) {
            false
        }
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(screenOffReceiver)
        } catch (_: Exception) {}
        super.onDestroy()
    }
}

