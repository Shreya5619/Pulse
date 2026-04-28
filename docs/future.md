# Pulse Futures Engine

The Futures Engine is the "what-if" simulation layer of Pulse. It takes current risks and projects them into multiple possible future trajectories (A/B/C) to help the user make the best decision.

## 1. Data Model

Defined in `server/src/types/futures.ts`.

### FuturesResult
The top-level response for a futures computation.
- `userId`: Identifier for the user.
- `baseTime`: The point in time from which simulations start.
- `horizonMinutes`: How far into the future we are looking (default: 120 min).
- `futures`: Array of `FutureCard` objects.

### FutureCard
Represents a single projected path.
- `id`: `DO_NOTHING` | `RECOMMENDED` | `ALTERNATE`
- `title` & `description`: Human-readable labels.
- `metrics`: Quantitative outcomes (ETA, Battery, Lateness).
- `risks`: Active `RiskScore` objects for this specific future state.

## 2. Simulation Logic

Implemented in `server/src/services/FuturesEngine.ts`.

### Shared Heuristics
- **Routing**: Integrates with `RoutingService` for live ETAs, with a fallback to `CommuteMemory` if GPS/OSRM is unavailable.
- **Battery Prediction**: Uses the formula `predicted = baseBattery - (rate * minutes / 60)`. Rates are derived from `BatteryMemory` and adjusted for modes (e.g., +50% drain for GPS navigation).
- **Stress Scoring**: Combines projected risks into a 0–1 score, weighted toward the most severe risk (70% max risk + 30% average).

### The Three Paths (A/B/C)

| Feature | **A: Do Nothing** | **B: Recommended** | **C: Alternate** |
| :--- | :--- | :--- | :--- |
| **Assumption** | User leaves at usual habitual time. | User leaves **now** (optimized). | User charges for 15m, then leaves. |
| **Phone State** | Recent behavior (no saver). | **Battery Saver enabled**. | Normal behavior. |
| **Discharge Rate** | High (Mixed/GPS). | Low (30% reduction). | Mixed. |
| **Outcome Goal** | Baseline (often risky). | Safety & On-time arrival. | Resilience (battery priority). |

## 3. Integration

### API Endpoint
- **URL**: `GET /api/futures`
- **Params**: `userId`
- **Description**: Returns a full `FuturesResult` for on-demand UI rendering.

### WebSocket Broadcast
The engine is integrated into the core `pulseFlow` heartbeat. Every tick, after computing current risks, the system broadcasts a `futures.updated` event.

```json
{
  "type": "futures.updated",
  "eventId": "fut_...",
  "timestamp": "...",
  "data": { ... FuturesResult ... }
}
```

This allows the mobile app to update the "Futures" screen in real-time as traffic conditions or battery levels change.
