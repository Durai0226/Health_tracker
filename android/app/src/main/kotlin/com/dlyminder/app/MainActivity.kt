package com.dlyminder.app

import android.content.Intent
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
    private val healthChannelName = "dlyminder/health_privacy"

    private var healthChannel: MethodChannel? = null

    /**
     * Set when Health Connect launches us to show the rationale, cleared when
     * Dart takes it.
     *
     * Buffered rather than pushed straight to Dart because of the cold-start
     * case: the manifest routes these intents at this activity, so on a cold
     * start the intent is already in hand before Flutter has attached a handler
     * — an invokeMethod at that point goes nowhere. Dart pulls this on its
     * first frame; the warm case (activity already alive) is pushed directly
     * from onNewIntent.
     */
    private var pendingHealthAction: String? = null

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

        healthChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, healthChannelName)
                .apply {
                    setMethodCallHandler { call, result ->
                        when (call.method) {
                            "consumePendingRationale" -> {
                                result.success(pendingHealthAction)
                                pendingHealthAction = null
                            }
                            else -> result.notImplemented()
                        }
                    }
                }

        // Cold start: the launching intent is already available here.
        captureHealthIntent(intent)
    }

    /**
     * Warm delivery. launchMode is singleTop and this is the app's only
     * activity, so Health Connect re-entering the app lands here rather than in
     * onCreate.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (captureHealthIntent(intent)) {
            // Flutter is already running, so hand it over immediately; the
            // buffer is only the cold-start fallback.
            healthChannel?.invokeMethod("showHealthPrivacy", pendingHealthAction)
            pendingHealthAction = null
        }
    }

    /**
     * Both filters are declared in AndroidManifest.xml and, until now, went
     * nowhere: tapping "privacy policy" in the Health Connect consent sheet
     * simply brought the app forward on whatever route it happened to be on.
     * Google reviews that flow when health permissions are declared.
     *
     * - ACTION_SHOW_PERMISSIONS_RATIONALE — from the Health Connect consent
     *   sheet, on the activity itself.
     * - ACTION_VIEW_PERMISSION_USAGE — Android 14+ permission-usage screen, via
     *   the ViewPermissionUsageActivity alias.
     *
     * @return true when this intent was one of ours.
     */
    private fun captureHealthIntent(intent: Intent?): Boolean {
        val action = intent?.action ?: return false
        val isHealthRationale = action == ACTION_SHOW_PERMISSIONS_RATIONALE ||
            action == ACTION_VIEW_PERMISSION_USAGE
        if (isHealthRationale) pendingHealthAction = action
        return isHealthRationale
    }

    companion object {
        /**
         * Spelled out rather than referenced from androidx.health / Intent so
         * these stay readable next to the identical strings in
         * AndroidManifest.xml — and so ACTION_VIEW_PERMISSION_USAGE (API 29+)
         * needs no API-level guard on a minSdk-26 build.
         */
        private const val ACTION_SHOW_PERMISSIONS_RATIONALE =
            "androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE"
        private const val ACTION_VIEW_PERMISSION_USAGE =
            "android.intent.action.VIEW_PERMISSION_USAGE"
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
