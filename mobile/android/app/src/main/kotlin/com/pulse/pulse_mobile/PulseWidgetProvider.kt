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
                    val scoreStr = widgetData.getString("risk_score", "0.00") ?: "0.00"
                    val score = scoreStr.toFloatOrNull() ?: 0.0f
                    val label = widgetData.getString("risk_label", "NOMINAL") ?: "NOMINAL"
                    val riskCount = widgetData.getString("risk_count", "0") ?: "0"
                    
                    val risk1 = widgetData.getString("risk_1", "Monitoring context...")
                    val risk2 = widgetData.getString("risk_2", "")
                    val risk3 = widgetData.getString("risk_3", "")

                    setTextViewText(R.id.widget_risk_score, scoreStr)
                    setTextViewText(R.id.widget_risk_label, label)
                    setTextViewText(R.id.widget_time, "$riskCount RISKS NEXT 90M")
                    
                    // Color based on risk level
                    val color = when {
                        score >= 0.7f -> Color.parseColor("#E74C3C") // Red
                        score >= 0.4f -> Color.parseColor("#F1C40F") // Yellow
                        else -> Color.parseColor("#2ECC71") // Green
                    }
                    setTextColor(R.id.widget_risk_label, color)

                    setTextViewText(R.id.risk_1, if (risk1?.isNotEmpty() == true) "• $risk1" else "")
                    setTextViewText(R.id.risk_2, if (risk2?.isNotEmpty() == true) "• $risk2" else "")
                    setTextViewText(R.id.risk_3, if (risk3?.isNotEmpty() == true) "• $risk3" else "")
                }
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                // Silent fail
            }
        }
    }
}