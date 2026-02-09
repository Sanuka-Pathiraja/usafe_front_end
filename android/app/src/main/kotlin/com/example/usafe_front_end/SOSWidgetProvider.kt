package com.example.usafe_front_end

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews

class SOSWidgetProvider : AppWidgetProvider() {

    private val TAG = "SOSWidgetProvider"

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "onUpdate called for ${appWidgetIds.size} widget(s)")

        for (widgetId in appWidgetIds) {
            try {
                val intent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra("SOS_TRIGGERED", true)
                }

                val pendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                val views = RemoteViews(context.packageName, R.layout.sos_widget_layout)
                Log.d(TAG, "RemoteViews created successfully")

                views.setOnClickPendingIntent(R.id.btn_sos, pendingIntent)
                Log.d(TAG, "PendingIntent set successfully")

                appWidgetManager.updateAppWidget(widgetId, views)
                Log.d(TAG, "Widget updated successfully for id $widgetId")
            } catch (e: Exception) {
                Log.e(TAG, "Error updating widget: ${e.message}", e)
            }
        }
    }
}
