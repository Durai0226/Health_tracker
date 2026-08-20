package com.dlyminder.app

import android.content.Context
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.HealthConnectFeatures
import androidx.health.connect.client.ExperimentalMindfulnessSessionApi
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.MindfulnessSessionRecord
import androidx.health.connect.client.records.metadata.Device
import androidx.health.connect.client.records.metadata.Metadata
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.Instant
import java.time.ZoneId
import java.time.ZoneOffset

/**
 * Writes completed mindfulness practice to Health Connect.
 *
 * ## Why this exists at all
 *
 * `package:health` 13.3.2 declares `HealthDataType.MINDFULNESS` only in
 * `dataTypeKeysIOS`, and there is no mindfulness code anywhere in the plugin's
 * Android sources. HealthKit works through the plugin; Health Connect does not.
 * This is the smallest amount of native code that closes that gap.
 *
 * ## What it deliberately does NOT write
 *
 * Only breathing exercises, meditation activities and timed relaxation
 * listening. A work sprint is **not** a mindfulness session, and Forest writing
 * every focus session to Apple Health as Mindful Minutes is wrong rather than
 * ambitious: `MindfulnessSessionRecord` means mindfulness practice, so putting a
 * fifty-minute coding block there pollutes a permanent health record with a
 * false claim. The Dart side owns that mapping through an exhaustive switch; this
 * class only ever receives sessions that already qualify.
 *
 * ## Availability is not optional
 *
 * `MindfulnessSessionRecord` is `@ExperimentalMindfulnessSessionApi` and arrives
 * via a Google Play System Update, so a large share of devices will answer
 * "unavailable". That matters more than it looks: Health Connect refuses the
 * WHOLE permission sheet if any requested type is unsupported — the same failure
 * `HealthDataService.isSkinTemperatureSupported()` already guards against. So
 * `isAvailable` must be checked before the permission is ever requested, and the
 * settings row hidden rather than shown-and-broken.
 */
@OptIn(ExperimentalMindfulnessSessionApi::class)
class MindfulnessChannel(private val context: Context) {

    companion object {
        const val CHANNEL = "dlyminder/mindfulness"

        /** Matches the Dart-side enum ordinals in `MindfulnessKind`. */
        private const val KIND_BREATHING = 0
        private const val KIND_MEDITATION = 1
        private const val KIND_MUSIC = 2
    }

    private val scope = CoroutineScope(Dispatchers.Main)

    private val client: HealthConnectClient?
        get() = try {
            if (HealthConnectClient.getSdkStatus(context) ==
                HealthConnectClient.SDK_AVAILABLE
            ) {
                HealthConnectClient.getOrCreate(context)
            } else {
                null
            }
        } catch (e: Throwable) {
            null
        }

    private val writePermission =
        HealthPermission.getWritePermission(MindfulnessSessionRecord::class)

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> scope.launch { result.success(isAvailable()) }
            "hasPermission" -> scope.launch { result.success(hasPermission()) }
            "writeSession" -> {
                val startMs = call.argument<Long>("startMs")
                val endMs = call.argument<Long>("endMs")
                val kind = call.argument<Int>("kind") ?: KIND_MEDITATION
                val title = call.argument<String>("title")
                val clientId = call.argument<String>("clientId")
                if (startMs == null || endMs == null || endMs <= startMs) {
                    // A zero-or-negative-length session is not a rejection worth
                    // an exception — it is nothing to write.
                    result.success(false)
                    return
                }
                scope.launch {
                    result.success(
                        writeSession(startMs, endMs, kind, title, clientId)
                    )
                }
            }
            else -> result.notImplemented()
        }
    }

    private suspend fun isAvailable(): Boolean = withContext(Dispatchers.IO) {
        try {
            val c = client ?: return@withContext false
            c.features.getFeatureStatus(
                HealthConnectFeatures.FEATURE_MINDFULNESS_SESSION
            ) == HealthConnectFeatures.FEATURE_STATUS_AVAILABLE
        } catch (e: Throwable) {
            false
        }
    }

    private suspend fun hasPermission(): Boolean = withContext(Dispatchers.IO) {
        try {
            val c = client ?: return@withContext false
            c.permissionController.getGrantedPermissions().contains(writePermission)
        } catch (e: Throwable) {
            false
        }
    }

    /**
     * Insert one session. Returns false rather than throwing on every failure
     * path — a health write must never be able to take down the save that
     * triggered it.
     */
    private suspend fun writeSession(
        startMs: Long,
        endMs: Long,
        kind: Int,
        title: String?,
        clientId: String?
    ): Boolean = withContext(Dispatchers.IO) {
        try {
            if (!isAvailable() || !hasPermission()) return@withContext false
            val c = client ?: return@withContext false

            val start = Instant.ofEpochMilli(startMs)
            val end = Instant.ofEpochMilli(endMs)
            val zone = ZoneId.systemDefault()

            val record = MindfulnessSessionRecord(
                startTime = start,
                // The device's real offset at that instant, not ZoneOffset.UTC.
                // A hardcoded UTC offset makes every session display at the wrong
                // local time for anyone not on UTC, which is most people.
                startZoneOffset = zone.rules.getOffset(start) ?: ZoneOffset.UTC,
                endTime = end,
                endZoneOffset = zone.rules.getOffset(end) ?: ZoneOffset.UTC,
                mindfulnessSessionType = when (kind) {
                    KIND_BREATHING ->
                        MindfulnessSessionRecord.MINDFULNESS_SESSION_TYPE_BREATHING
                    KIND_MUSIC ->
                        MindfulnessSessionRecord.MINDFULNESS_SESSION_TYPE_MUSIC
                    else ->
                        MindfulnessSessionRecord.MINDFULNESS_SESSION_TYPE_MEDITATION
                },
                title = title,
                // `clientRecordId` is the de-duplication mechanism Health Connect
                // itself honours, so a retry after a crash cannot double-write.
                // The Dart side ALSO keeps a synced flag, because that half has to
                // work on iOS where there is no clientRecordId.
                // One call shape, always with a clientRecordId. Branching on a
                // null id would depend on an overload existing, and the id is
                // never actually absent — Dart passes the session id, and the
                // fallback below is derived rather than omitted.
                metadata = Metadata.activelyRecorded(
                    clientRecordId = clientId ?: "focus_$startMs",
                    device = Device(type = Device.TYPE_PHONE)
                )
            )
            c.insertRecords(listOf(record))
            true
        } catch (e: Throwable) {
            false
        }
    }
}
