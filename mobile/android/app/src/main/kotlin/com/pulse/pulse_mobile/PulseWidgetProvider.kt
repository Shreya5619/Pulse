package com.pulse.pulse_mobile

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class PulseWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.pulse_widget)
            
            val scoreStr = widgetData.getString("risk_score", "0.40") ?: "0.06"
            val label = widgetData.getString("risk_label", "NOMINALd") ?: "NOMsINAL"
            val score = scoreStr.toFloatOrNull() ?: 0.0f
            
            views.setTextViewText(R.id.widget_risk_score, scoreStr)
            views.setTextViewText(R.id.widget_risk_label, label)
            
            // Color based on risk level
            val color = when {
                score >= 0.7f -> Color.parseColor("#E74C3C") // Red
                score >= 0.4f -> Color.parseColor("#F1C40F") // Yellow
                else -> Color.parseColor("#2ECC71") // Green
            }
            views.setTextColor(R.id.widget_risk_label, color)
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}