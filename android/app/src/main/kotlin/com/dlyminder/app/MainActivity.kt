package com.dlyminder.app

import android.os.Build
import androidx.annotation.NonNull
// FlutterFragmentActivity (not FlutterActivity) is required by the `health`
// plugin's Health Connect permission flow, which uses registerForActivityResult.
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Host activity.
 *
 * ## Why the lock-screen flags are set here and not in the manifest
 *
 * `showWhenLocked` / `turnScreenOn` / `showOnLockScreen` used to be manifest
 * attributes on this activity. This is the ONLY activity in the app — `/alarm`
 * is a Flutter route inside it — so those attributes meant the entire app
 * displayed over the device lock screen, permanently.
 *
 * The consequence: when a full-screen medicine alarm fired on a locked phone,
 * the user could dismiss it and then navigate freely into medicines, vitals,
 * the diary and period data without ever entering the device PIN. The in-app
 * lock did not help — it is off by default, and it is deliberately suppressed
 * on the alarm route so the alarm can actually be answered.
 *
 * Setting them at runtime instead means the window is only lock-screen-visible
 * for as long as an alarm is actually on screen. Everything else is behind the
 * device's own keyguard again.
 */
class MainActivity : FlutterFragmentActivity() {

    private val channelName = "dlyminder/lockscreen"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setShowWhenLocked" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        applyLockScreenFlags(enabled)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * `setShowWhenLocked` / `setTurnScreenOn` are API 27+. minSdk is 26, so on
     * API 26 the alarm simply behaves as a normal high-priority notification —
     * which is the safe direction to fail.
     */
    private fun applyLockScreenFlags(enabled: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(enabled)
            setTurnScreenOn(enabled)
        }
    }
}
