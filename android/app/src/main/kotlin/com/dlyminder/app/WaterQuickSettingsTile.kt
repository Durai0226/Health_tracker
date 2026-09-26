package com.dlyminder.app

import android.net.Uri
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Quick Settings tile that logs a glass of water from the notification shade.
 *
 * The lowest-friction logging surface Android offers without a watch: pull down,
 * tap, done — no app launch, no unlock on most devices. Android's own docs are
 * explicit that a tile may act without launching the app, which is the whole
 * point here.
 *
 * Reuses the same background hand-off as the home-screen widget button and the
 * notification action: this process has no Drift, so the tap only enqueues the
 * drink (via HomeWidgetBackgroundReceiver -> a Flutter background isolate ->
 * WaterActionQueue) and `AppShell` turns it into a real log on next resume.
 * Three entry points, one code path, one confirmation with Undo.
 *
 * `TileService` was added in API 24 and the whole class is gated on it; the
 * manifest entry carries the matching `android:minSdkVersion` guard on the
 * intent filter so nothing is advertised on older devices.
 */
@RequiresApi(Build.VERSION_CODES.N)
class WaterQuickSettingsTile : TileService() {

    /** True when the user has set a fluid ceiling (dialysis, heart failure). */
    private fun isFluidRestricted(): Boolean = try {
        HomeWidgetPlugin.getData(applicationContext)
            .getBoolean("waterRestricted", false)
    } catch (e: Exception) {
        // Never let a preferences read break the shade; default to allowing
        // the tile, which is the behaviour everyone without a limit expects.
        android.util.Log.w("WaterQSTile", "restriction read failed", e)
        false
    }

    override fun onStartListening() {
        super.onStartListening()
        // A stateless action, not a toggle — INACTIVE is the resting look for
        // "tap me to do a thing". Using ACTIVE would imply the tile holds state
        // that it does not.
        //
        // Under a fluid restriction the daily number is a CEILING, so a
        // one-tap "+250 ml" from the shade is a shortcut to breaching a
        // clinical limit — with no dial, no total and no warning in sight. The
        // tile goes UNAVAILABLE and says why; logging is still possible in the
        // app, where the intake is shown against the limit.
        val restricted = isFluidRestricted()
        qsTile?.apply {
            state = if (restricted) Tile.STATE_UNAVAILABLE else Tile.STATE_INACTIVE
            label = if (restricted) "Fluid limit set" else "Log 250 ml"
            updateTile()
        }
    }

    override fun onClick() {
        super.onClick()
        // STATE_UNAVAILABLE should already swallow the tap, but the tile can be
        // stale if the limit was set while the shade was open.
        if (isFluidRestricted()) return
        try {
            HomeWidgetBackgroundIntent.getBroadcast(
                applicationContext,
                Uri.parse("dlyminder://water/log?ml=250")
            ).send()
        } catch (e: Exception) {
            // A dead tile is a bad experience but must never crash the shade.
            android.util.Log.w("WaterQSTile", "log failed", e)
        }
    }
}
