package com.pulse.pulse_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Intent
import android.provider.Settings
import android.net.Uri
import android.os.PowerManager
import android.content.Context
import java.util.Calendar

class MainActivity : FlutterActivity() {
    private val EVENT_CHANNEL = "notifications_stream"
    private val BATTERY_CHANNEL = "battery_optimization"
    private val USAGE_CHANNEL = "com.pulse.app/usage_stats"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NotificationStreamHandler.eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    NotificationStreamHandler.eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestDisable" -> {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                            intent.data = Uri.parse("package:$packageName")
                            startActivity(intent); result.success(true)
                        } catch (e: Exception) {
                            try { startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)); result.success(true) }
                            catch (e2: Exception) { result.error("UNAVAILABLE", "Cannot open battery settings.", null) }
                        }
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "openNotificationSettings" -> {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)); result.success(true)
                        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        intent.putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        startActivity(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Usage Stats MethodChannel ──────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, USAGE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getTodayUsage" -> {
                        if (!hasUsagePermission()) {
                            // Prompt user to grant permission
                            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                            result.error("PERMISSION_DENIED", "Usage access not granted", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
                            val cal = Calendar.getInstance()
                            val endTime = cal.timeInMillis
                            cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0); cal.set(Calendar.SECOND, 0)
                            val startTime = cal.timeInMillis

                            val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startTime, endTime)
                            val pm = packageManager

                            val out = stats
                                .filter { it.totalTimeInForeground > 60_000 }
                                .sortedByDescending { it.totalTimeInForeground }
                                .take(10)
                                .map { stat ->
                                    val appName = try {
                                        pm.getApplicationLabel(pm.getApplicationInfo(stat.packageName, 0)).toString()
                                    } catch (_: Exception) { stat.packageName.split(".").last() }
                                    mapOf("appName" to appName, "totalMinutes" to (stat.totalTimeInForeground / 60_000).toInt())
                                }
                            result.success(out)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    "getHourlyUsageForDay" -> {
                        if (!hasUsagePermission()) {
                            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                            result.error("PERMISSION_DENIED", "Usage access not granted", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val dayStartMs = (call.arguments as? Map<*, *>)?.get("dayStartMs") as? Long
                                ?: Calendar.getInstance().apply {
                                    set(Calendar.HOUR_OF_DAY, 0)
                                    set(Calendar.MINUTE, 0)
                                    set(Calendar.SECOND, 0)
                                    set(Calendar.MILLISECOND, 0)
                                }.timeInMillis
                            val calEnd = Calendar.getInstance().apply { timeInMillis = dayStartMs }
                            calEnd.add(Calendar.DAY_OF_MONTH, 1)
                            val dayEndMs = calEnd.timeInMillis
                            val nowMs = System.currentTimeMillis()
                            val queryEnd = minOf(dayEndMs, nowMs)

                            val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
                            val usageEvents = usm.queryEvents(dayStartMs, queryEnd)
                            val pm = packageManager

                            // package -> hour (0-23) -> milliseconds foreground
                            val buckets = mutableMapOf<String, MutableMap<Int, Long>>()
                            val lastResume = mutableMapOf<String, Long>()

                            fun labelFor(pkg: String): String = try {
                                pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
                            } catch (_: Exception) {
                                pkg.split(".").last()
                            }

                            val ev = UsageEvents.Event()
                            while (usageEvents.hasNextEvent()) {
                                usageEvents.getNextEvent(ev)
                                val pkg = ev.packageName ?: continue
                                when (ev.eventType) {
                                    UsageEvents.Event.ACTIVITY_RESUMED, 1 -> {
                                        lastResume[pkg] = ev.timeStamp
                                    }
                                    UsageEvents.Event.ACTIVITY_PAUSED, 2 -> {
                                        val start = lastResume.remove(pkg) ?: continue
                                        val dur = (ev.timeStamp - start).coerceAtLeast(0L)
                                        if (dur < 5_000L) continue
                                        var t = start
                                        while (t < ev.timeStamp) {
                                            val calH = Calendar.getInstance().apply { timeInMillis = t }
                                            val hour = calH.get(Calendar.HOUR_OF_DAY)
                                            val endOfHour = Calendar.getInstance().apply {
                                                timeInMillis = t
                                                set(Calendar.MINUTE, 0)
                                                set(Calendar.SECOND, 0)
                                                set(Calendar.MILLISECOND, 0)
                                                add(Calendar.HOUR_OF_DAY, 1)
                                            }.timeInMillis
                                            val sliceEnd = minOf(endOfHour, ev.timeStamp)
                                            val slice = (sliceEnd - t).coerceAtLeast(0L)
                                            val inner = buckets.getOrPut(pkg) { mutableMapOf() }
                                            inner[hour] = (inner[hour] ?: 0L) + slice
                                            t = sliceEnd
                                        }
                                    }
                                }
                            }
                            // Close open foreground sessions up to queryEnd
                            for ((pkg, start) in lastResume) {
                                val dur = (queryEnd - start).coerceAtLeast(0L)
                                if (dur < 5_000L) continue
                                var t = start
                                while (t < queryEnd) {
                                    val calH = Calendar.getInstance().apply { timeInMillis = t }
                                    val hour = calH.get(Calendar.HOUR_OF_DAY)
                                    val endOfHour = Calendar.getInstance().apply {
                                        timeInMillis = t
                                        set(Calendar.MINUTE, 0)
                                        set(Calendar.SECOND, 0)
                                        set(Calendar.MILLISECOND, 0)
                                        add(Calendar.HOUR_OF_DAY, 1)
                                    }.timeInMillis
                                    val sliceEnd = minOf(endOfHour, queryEnd)
                                    val slice = (sliceEnd - t).coerceAtLeast(0L)
                                    val inner = buckets.getOrPut(pkg) { mutableMapOf() }
                                    inner[hour] = (inner[hour] ?: 0L) + slice
                                    t = sliceEnd
                                }
                            }

                            val totals = buckets.mapValues { (_, hmap) -> hmap.values.sum() / 60_000.0 }
                            val topPkgs = totals.entries.sortedByDescending { it.value }.take(8).map { it.key }

                            val out = topPkgs.map { pkg ->
                                val hmap = buckets[pkg] ?: emptyMap()
                                val segments = hmap.entries
                                    .sortedBy { it.key }
                                    .map { (hour, ms) ->
                                        mapOf(
                                            "hour" to hour,
                                            "minutes" to (ms / 60_000.0)
                                        )
                                    }
                                mapOf(
                                    "appName" to labelFor(pkg),
                                    "totalMinutes" to (totals[pkg] ?: 0.0).toInt(),
                                    "hourlySegments" to segments
                                )
                            }
                            result.success(out)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    "hasPermission" -> result.success(hasUsagePermission())
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasUsagePermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
        return mode == AppOpsManager.MODE_ALLOWED
    }
}
