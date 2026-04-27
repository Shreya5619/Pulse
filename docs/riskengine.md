# Risk Engine

The Pulse Risk Engine is a deterministic heuristic scoring system that quantifies failure probability across multiple dimensions of a user's life. It transforms raw context data and long-term memory into actionable risk scores.

## Core Philosophy

1. **Pure & Deterministic**: The core scoring functions in `RiskEngine.ts` are pure functions. They take numeric or string inputs and return a score between 0 and 1. This ensures they are easy to test, debug, and reason about without needing a database or complex state.
2. **Heuristic-Based**: Rather than using black-box machine learning, Pulse uses transparent heuristics. Each risk score comes with a list of "causes" and a human-readable "summary" so the user (and the agent) knows exactly *why* a risk is forming.
3. **Layered Assessment**: 
    - **Raw Score**: A float ∈ [0, 1].
    - **Label**: A categorical severity (`LOW`, `MEDIUM`, `HIGH`).
    - **Snapshot**: A point-in-time collection of all active risks for a user.

---

## 1. Risk Dimensions

### 1.1 Lateness Risk
Calculates the probability that a user will be late for an upcoming appointment.

- **Inputs**: 
    - `minutesToEvent`: Time remaining until the event starts.
    - `etaMinutes`: Estimated travel time (derived from OSRM/Routing).
    - `buffer`: The habitual buffer the user typically leaves (derived from `memory.habits`).
- **Logic**:
    - `slack = minutesToEvent - etaMinutes - buffer`
    - `slack >= 10`: 0.1 (LOW)
    - `slack >= 5`: 0.4 (MEDIUM)
    - `slack >= 0`: 0.7 (MEDIUM/HIGH)
    - `slack < 0`: 0.9 (HIGH) — User is already projected to be late.

### 1.2 Battery Depletion Risk
Predicts if the device will run out of power before a significant horizon (e.g., the next event or a 2-hour window).

- **Inputs**:
    - `currentPct`: Current battery level (0-100).
    - `horizonMinutes`: The look-ahead window.
    - `dischargePerHour`: Typical drain rate (derived from `memory.battery`).
- **Logic**:
    - `predictedPct = currentPct - (dischargePerHour * horizonMinutes) / 60`
    - `predictedPct >= 30`: 0.1 (LOW)
    - `predictedPct >= 20`: 0.4 (MEDIUM)
    - `predictedPct >= 10`: 0.7 (HIGH)
    - `predictedPct < 10`: 0.9 (CRITICAL)

### 1.3 Response Debt Risk
Quantifies the stress/risk of unaddressed communication.

- **Inputs**:
    - `importantPending`: Count of unread messages from priority senders.
    - `oldestMinutes`: Age of the oldest unanswered important message.
- **Logic**:
    - Base score: `min(1, importantPending / 5)`
    - Boosts: 
        - `+0.2` if oldest message > 60 mins.
        - `+0.3` if oldest message > 180 mins.

### 1.4 Overload Risk
Measures cognitive or schedule density.

- **Inputs**:
    - `eventsNext90`: Number of calendar events in the next 90 minutes.
    - `overlapScore`: Ratio of time-window overlap among events.
    - `notifRate`: Notifications received per 15-minute window.
- **Logic**:
    - `+0.4` if `eventsNext90 >= 3`.
    - `+0.3` if `overlapScore > 0.5`.
    - `+0.3` if `notifRate > 20`.

---

## 2. Data Structures

### RiskScore
A structured assessment of a single risk type.
```typescript
{
  type: "lateness" | "battery" | "response_debt" | "overload";
  score: number;      // 0 to 1
  label: "LOW" | "MEDIUM" | "HIGH";
  nodeId?: string;    // Reference to the Graph Node
  summary: string;    // Human-readable summary
  causes: string[];   // List of contributing factors
}
```

### RiskSnapshot
A point-in-time collection of all non-zero risks for a user.
```typescript
{
  userId: string;
  timestamp: string;
  risks: RiskScore[];
}
```

---

## 3. Persistence & Querying

Risk snapshots are persisted in the **Postgres** `risk_snapshots` table. This allows the system to:
- Track risk trends over time.
- Provide "Scenario History" to the UI.
- Allow agents to see if a risk is escalating or stabilizing.

**Key Endpoints**:
- `GET /api/graph/risk`: Compute and return a live snapshot.
- `GET /api/graph/risk/history`: Query stored snapshots for a user.
