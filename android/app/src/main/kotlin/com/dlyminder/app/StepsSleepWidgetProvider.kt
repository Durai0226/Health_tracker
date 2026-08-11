package com.dlyminder.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Native half of the Steps + Sleep home-screen widget (Dart half lives in
 * lib/core/services/home_widget_service.dart). Extends the plugin's own
 * [HomeWidgetProvider] (not plain AppWidgetProvider) so [widgetData] below is
 * populated straight from the SharedPreferences that
 * `HomeWidget.saveWidgetData` writes on the Dart side.
 *
 * Periodic refresh is a backstop only (see steps_sleep_widget_info.xml); the
 * real refresh happens when Dart calls `HomeWidget.updateWidget(...)` from
 * `HomeWidgetService.pushSnapshot()`, which triggers this same `onUpdate`.
 */
class StepsSleepWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val steps = widgetData.getInt("steps", 0)
        val stepPct = widgetData.getInt("stepPct", 0).coerceIn(0, 100)
        val sleep = widgetData.getString("sleep", null) ?: "—"
        val sleepScore = widgetData.getInt("sleepScore", 0)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.steps_sleep_widget).apply {
                setTextViewText(R.id.steps_value, "%,d steps".format(steps))
                setProgressBar(R.id.steps_progress, 100, stepPct, false)
                setTextViewText(R.id.steps_pct, "$stepPct%")

                setTextViewText(R.id.sleep_value, "Sleep: $sleep")
                if (sleepScore > 0) {
                    setTextViewText(R.id.sleep_score, "Score $sleepScore")
                    setViewVisibility(R.id.sleep_score, View.VISIBLE)
                } else {
                    setViewVisibility(R.id.sleep_score, View.GONE)
                }

                // Tap the widget to open the app (best-effort; never block the
                // rest of the update if no launch intent is resolvable).
                context.packageManager.getLaunchIntentForPackage(context.packageName)?.let { launch ->
                    launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    val pendingIntent = PendingIntent.getActivity(
                        context,
                        0,
                        launch,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
