# Pulse WebSocket Events

This document describes the **ordered sequence** of WebSocket events used in the v0 “Commute Rescue” demo.

---

## Envelope

All events share a common envelope:

```ts
interface WsEnvelope<T> {
  type: WsEventType;
  ts: string; // ISO timestamp
  payload: T;
}
```

`WsEventType`:

```ts
type WsEventType =
  | "heartbeat.tick"
  | "context.updated"
  | "risk.updated"
  | "planner.suggested"
  | "guardian.decided"
  | "intervention.created";
```

---

## Event types

### 1. `heartbeat.tick`

**Purpose:** Drive the agent loop; shows the system is alive.

```ts
interface HeartbeatTick {
  userId: string;
  sequence: number; // 1, 2, 3 ...
}
```

Example:

```json
{
  "type": "heartbeat.tick",
  "ts": "2026-04-22T10:00:05Z",
  "payload": {
    "userId": "USER_DEMO",
    "sequence": 1
  }
}
```

---

### 2. `context.updated`

**Purpose:** Broadcast normalized context from the Context Agent.

Payload: `ContextSignal` (see `api-contracts.md`).

Example:

```json
{
  "type": "context.updated",
  "ts": "2026-04-22T10:00:06Z",
  "payload": {
    "userId": "USER_DEMO",
    "timestamp": "2026-04-22T10:00:06Z",
    "locationLabel": "Home",
    "batteryPercent": 17,
    "minutesToEvent": 25,
    "eventName": "Physics Lab",
    "trafficStatus": "JAMMED"
  }
}
```

---

### 3. `risk.updated`

**Purpose:** Broadcast risk calculated by the Risk Agent.

Payload: `RiskAssessment`.

Example:

```json
{
  "type": "risk.updated",
  "ts": "2026-04-22T10:00:08Z",
  "payload": {
    "userId": "USER_DEMO",
    "timestamp": "2026-04-22T10:00:08Z",
    "scenario": "COMMUTE_LATE",
    "score": 0.84,
    "label": "HIGH",
    "reasons": [
      "Traffic worsening",
      "Battery at 17%",
      "25 minutes to lab"
    ]
  }
}
```

---

### 4. `planner.suggested`

**Purpose:** Share the Planner’s chosen intervention.

Payload: `PlannerSuggestion`.

Example:

```json
{
  "type": "planner.suggested",
  "ts": "2026-04-22T10:00:10Z",
  "payload": {
    "userId": "USER_DEMO",
    "timestamp": "2026-04-22T10:00:10Z",
    "actionId": "ACTION_LEAVE_NOW",
    "title": "Leave now for campus",
    "description": "Given traffic and your battery, leaving now keeps you on time for lab.",
    "recommendedAtMinutesToEvent": 25,
    "sideEffects": [
      "Enable Battery Saver",
      "Notify lab if ETA slips"
    ]
  }
}
```

---

### 5. `guardian.decided`

**Purpose:** Encode safety / approval policy from Guardian Agent.

Payload: `GuardianDecision`.

Example:

```json
{
  "type": "guardian.decided",
  "ts": "2026-04-22T10:00:12Z",
  "payload": {
    "userId": "USER_DEMO",
    "actionId": "ACTION_LEAVE_NOW",
    "timestamp": "2026-04-22T10:00:12Z",
    "mode": "ASK_FIRST",
    "rationale": "Action affects your calendar and sends a message; ask for confirmation."
  }
}
```

---

### 6. `intervention.created`

**Purpose:** Final UI‑ready card for the app.

Payload: `InterventionCard`.

Example:

```json
{
  "type": "intervention.created",
  "ts": "2026-04-22T10:00:15Z",
  "payload": {
    "userId": "USER_DEMO",
    "actionId": "ACTION_LEAVE_NOW",
    "createdAt": "2026-04-22T10:00:15Z",
    "headline": "Leave now and enable Battery Saver",
    "body": "Traffic is worsening and your phone is at 17%. Pulse recommends leaving now and enabling Battery Saver so you reach lab on time.",
    "ctaLabel": "Start commute",
    "secondaryCtaLabel": "Dismiss"
  }
}
```

---

## Demo ordering

For the v0 Commute Rescue:

1. `heartbeat.tick` (sequence 1)
2. `context.updated`
3. `heartbeat.tick` (sequence 2)
4. `risk.updated`
5. `heartbeat.tick` (sequence 3)
6. `planner.suggested`
7. `guardian.decided`
8. `intervention.created`

The mobile client can safely assume this order for the demo, but should still render events idempotently by `userId`/`actionId`.
