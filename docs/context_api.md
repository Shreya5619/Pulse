# Pulse Context Ingestion API

This API is used by the mobile application to send raw sensor and state data (snapshots) to the Pulse backend.

## 1. POST /api/snapshots

Ingest a new context snapshot from the device.

### Headers
| Name | Required | Description |
|------|----------|-------------|
| `X-User-Id` | Yes | Unique identifier for the user. |
| `X-Device-Id`| No | Identifier for the specific hardware device. |
| `Content-Type`| Yes | Must be `application/json`. |

### Request Body (Raw Payload)
The backend expects a payload very close to the raw Android/Flutter sensor output.

```json
{
  "timestamp": "2026-04-24T08:00:00Z",
  "location": {
    "lat": 37.7749,
    "lon": -122.4194,
    "accuracy": 10.5,
    "provider": "gps"
  },
  "calendar": {
    "next_event": {
      "title": "Meeting",
      "start_time": "2026-04-24T09:00:00Z",
      "end_time": "2026-04-24T10:00:00Z",
      "location_text": "Main Office"
    }
  },
  "battery": {
    "level": 0.85,
    "is_charging": false
  },
  "device_state": {
    "network_type": "wifi",
    "screen_on": true
  }
}
```

### Success Response (201 Created)
```json
{
  "snapshot_id": "uuid-v4-string",
  "accepted_at": "2026-04-24T08:00:01Z",
  "minutes_to_next_event": 60,
  "has_next_event": true
}
```

---

## 2. GET /api/snapshots/latest

Fetch the most recently processed and normalized snapshot for the user.

### Headers
| Name | Required | Description |
|------|----------|-------------|
| `X-User-Id` | Yes | Unique identifier for the user. |

### Success Response (200 OK)
Returns the **Normalized** `ContextSnapshot` including derived flags.

```json
{
  "ok": true,
  "data": {
    "id": "uuid",
    "user_id": "user_123",
    "timestamp": "...",
    "location": { "lat": 37.774900, ... },
    "derived": {
      "is_commute_window": true,
      "battery_band": "high"
    }
  }
}
```

---

## Usage Guidelines

### Call Cadence
- **Event-Driven**: The app should push a snapshot immediately on significant changes:
    - Location moves > 100m.
    - Battery drops into a new band (e.g., crossing 20%).
    - Calendar event starts or ends.
- **Interval**: A background heartbeat every 15-30 minutes is recommended if no events occur.

### Error Codes & Retries
- **400 Bad Request**: Validation or normalization failed. Do **not** retry automatically; log the error and check schema alignment.
- **429 Too Many Requests**: Backend is overwhelmed. Use exponential backoff (starting at 30s).
- **5xx Server Error**: Backend issue. Retry with exponential backoff.

### Security
In production, all requests must be signed or use a Bearer token. For the current demo, `X-User-Id` is used for identification.
