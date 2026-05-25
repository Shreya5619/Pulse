package com.pulse.pulse_mobile

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.plugin.common.EventChannel

object NotificationStreamHandler {
    var eventSink: EventChannel.EventSink? = null

    fun send(data: Map<String, Any?>) {
        eventSink?.success(data)
    }
}

class NotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val extras = sbn.notification.extras

        val data = HashMap<String, Any?>()
        data["packageName"] = sbn.packageName
        
        // Try to get the app name
        try {
            val pm = applicationContext.packageManager
            val ai = pm.getApplicationInfo(sbn.packageName, 0)
            data["appName"] = pm.getApplicationLabel(ai).toString()
        } catch (e: Exception) {
            data["appName"] = sbn.packageName
        }

        data["title"] = extras.getCharSequence("android.title")?.toString()
        data["text"] = extras.getCharSequence("android.text")?.toString()
        data["time"] = sbn.postTime
        data["category"] = sbn.notification.category

        NotificationStreamHandler.send(data)
    }
}
