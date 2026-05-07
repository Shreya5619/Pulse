package com.pulse.pulse_mobile

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import com.pulse.pulse_mobile.R

class PulseWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val packageName = context.packageName
        
        for (appWidgetId in appWidgetIds) {
            try {
                val views = RemoteViews(packageName, R.layout.pulse_widget).apply {
                    val scoreStr = "0.82"
                    val label = "CRITICAL"
                    val riskCount = "3"
                    
                    val risk1 = "Lateness: Client Demo (95% probability)"
                    val risk2 = "Battery: Predicted < 5% by 6:00 PM"
                    val risk3 = "Overload: 4 back-to-back meetings"

                    setTextViewText(R.id.widget_risk_score, scoreStr)
                    setTextViewText(R.id.widget_risk_label, label)
                    setTextViewText(R.id.widget_time, "$riskCount RISKS NEXT 90M")
                    
                    // Color based on risk level
                    setTextColor(R.id.widget_risk_label, Color.parseColor("#E74C3C"))

                    setTextViewText(R.id.risk_1, "• $risk1")
                    setTextViewText(R.id.risk_2, "• $risk2")
                    setTextViewText(R.id.risk_3, "• $risk3")
                }
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                // Silent fail
            }
        }
    }
}