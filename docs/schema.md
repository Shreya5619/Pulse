A. Event
Represents a future obligation, usually from calendar.
json
{
  "id": "evt_001",
  "title": "ML Lab",
  "startTime": "2026-04-22T10:00:00+05:30",
  "endTime": "2026-04-22T11:00:00+05:30",
  "locationLabel": "Academic Block 3",
  "locationLat": 12.9716,
  "locationLng": 77.5946,
  "priority": "high",
  "source": "calendar",
  "attendenceExpected": true,
  "travelModeHint": "auto"
}
B. ContextSnapshot
Represents the user’s world at one moment.
json
{
  "timestamp": "2026-04-22T09:05:00+05:30",
  "lat": 12.9611,
  "lng": 77.6387,
  "batteryPct": 18,
  "charging": false,
  "networkType": "4g",
  "unreadNotifications": 43,
  "urgentNotifications": 3,
  "phoneMode": "normal",
  "nextEventId": "evt_001"
}
C. RiskScore
One object per risk type.
json
{
  "riskType": "lateness",
  "score": 0.78,
  "confidence": 0.84,
  "topFactors": [
    "eta_exceeds_buffer",
    "battery_low_for_navigation",
    "high_notification_load"
  ],
  "affectedEventId": "evt_001"
}
D. Intervention
Action the system suggests or triggers.
json
{
  "id": "int_001",
  "type": "leave_now_alert",
  "mode": "suggest",
  "reason": "Predicted lateness risk is 0.78",
  "expectedImpact": {
    "latenessRiskDelta": -0.45,
    "batteryRiskDelta": -0.10
  }
}
E. Feedback
Used to learn later.
json
{
  "interventionId": "int_001",
  "accepted": true,
  "timestamp": "2026-04-22T09:07:00+05:30",
  "outcome": "user_left_home"
}
F. FutureScenario
Needed for your wow feature.
json
{
  "scenarioId": "future_b",
  "label": "Leave now + battery saver",
  "predictedArrival": "2026-04-22T09:52:00+05:30",
  "predictedBatteryPct": 11,
  "latenessRisk": 0.21,
  "missedUrgentMessages": 0
}
