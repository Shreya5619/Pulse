
# Pulse API Contracts (v0 Demo)

This document freezes the **REST** and **WebSocket** contracts for the v0 “Commute Rescue” demo.  
Mobile and backend must treat these payloads as the single source of truth.

---

## 1. Shared types

All payloads live in `contracts/` as TypeScript types.

```ts
// contracts/common.ts
export type ISODateTime = string; // e.g. "2026-04-22T10:30:00Z"
export type UUID = string;

// contracts/context.ts
export interface ContextSignal {
  userId: UUID;
  timestamp: ISODateTime;
  locationLabel: string;      // "Home", "Campus", "Bus"
  batteryPercent: number;     // 0–100
  minutesToEvent: number;     // e.g. 25
  eventName: string;          // "Physics Lab"
  trafficStatus: "CLEAR" | "SLOW" | "JAMMED";
}

// contracts/risk.ts
export interface RiskAssessment {
  userId: UUID;
  timestamp: ISODateTime;
  scenario: "COMMUTE_LATE" | "BATTERY_DIE" | "MIXED";
  score: number;              // 0–1
  label: "LOW" | "MEDIUM" | "HIGH" | "CRITICAL";
  reasons: string[];          // human-readable
}

// contracts/planner.ts
export interface PlannerSuggestion {
  userId: UUID;
  timestamp: ISODateTime;
  actionId: UUID;
  title: string;              // "Leave now for campus"
  description: string;
  recommendedAtMinutesToEvent: number;
  sideEffects: string[];      // ["Enable Battery Saver", ...]
}

// contracts/guardian.ts
export type GuardianDecisionMode = "AUTO_ACT" | "ASK_FIRST" | "BLOCK";

export interface GuardianDecision {
  userId: UUID;
  actionId: UUID;
  timestamp: ISODateTime;
  mode: GuardianDecisionMode;
  rationale: string;
}

// contracts/intervention.ts
export interface InterventionCard {
  userId: UUID;
  actionId: UUID;
  createdAt: ISODateTime;
  headline: string;           // short, UI-ready
  body: string;               // 1–2 sentences
  ctaLabel: string;           // "Leave now"
  secondaryCtaLabel?: string; // "Dismiss"
}

// contracts/ws.ts
export type WsEventType =
  | "heartbeat.tick"
  | "context.updated"
  | "risk.updated"
  | "planner.suggested"
  | "guardian.decided"
  | "intervention.created";

export interface WsEnvelope<T> {
  type: WsEventType;
  ts: ISODateTime;
  payload: T;
}

// contracts/api.ts
export interface ApiResponse<T> {
  ok: boolean;
  data?: T;
  error?: string;
}
```

---

## 2. REST API

Base URL: `http://<host>:<port>`

### 2.1 `GET /health`

Health check.

```http
GET /health
```

Response:

```json
{
  "ok": true,
  "data": {
    "service": "pulse-server",
    "version": "0.0.1",
    "uptimeSeconds": 123
  }
}
```

---

### 2.2 `GET /demo/state`

Bootstrap state for the Commute Rescue demo.

```http
GET /demo/state?userId=<uuid>
```

Response:

```json
{
  "ok": true,
  "data": {
    "userId": "f9c0c5fa-91ba-4b9f-92a3-9b3d8c6ae111",
    "profile": {
      "name": "Alex",
      "homeLocation": "Kormangala",
      "destination": "Campus Lab",
      "quietHours": "23:00-07:00"
    },
    "context": {
      "userId": "f9c0c5fa-91ba-4b9f-92a3-9b3d8c6ae111",
      "timestamp": "2026-04-22T10:00:00Z",
      "locationLabel": "Home",
      "batteryPercent": 17,
      "minutesToEvent": 25,
      "eventName": "Physics Lab",
      "trafficStatus": "JAMMED"
    }
  }
}
```

---

### 2.3 `POST /demo/trigger`

Start the scripted demo heartbeat for a user.

```http
POST /demo/trigger
Content-Type: application/json

{
  "userId": "f9c0c5fa-91ba-4b9f-92a3-9b3d8c6ae111"
}
```

Response:

```json
{
  "ok": true,
  "data": {
    "message": "Demo scenario started",
    "userId": "f9c0c5fa-91ba-4b9f-92a3-9b3d8c6ae111"
  }
}
```

---

### 2.4 `GET /config/openclaw-files`

Expose OpenClaw‑style config files for debugging.

```http
GET /config/openclaw-files
```

Response:

```json
{
  "ok": true,
  "data": {
    "soul": "string: contents of SOUL.md",
    "agents": "string: contents of agents.md",
    "user": "string: contents of user.md",
    "heartbeat": "string: contents of heartbeat.md"
  }
}
```

---

## 3. WebSocket protocol

Endpoint:

```txt
ws://<host>:<port>/ws
```

All messages use `WsEnvelope<T>`.

Examples:

```json
{
  "type": "heartbeat.tick",
  "ts": "2026-04-22T10:00:05Z",
  "payload": {
    "userId": "f9c0c5fa-91ba-4b9f-92a3-9b3d8c6ae111",
    "sequence": 1
  }
}
```

```json
{
  "type": "context.updated",
  "ts": "2026-04-22T10:00:06Z",
  "payload": {
    "userId": "f9c0c5fa-91ba-4b9f-92a3-9b3d8c6ae111",
    "timestamp": "2026-04-22T10:00:06Z",
    "locationLabel": "Home",
    "batteryPercent": 17,
    "minutesToEvent": 25,
    "eventName": "Physics Lab",
    "trafficStatus": "JAMMED"
  }
}
```

```json
{
  "type": "risk.updated",
  "ts": "2026-04-22T10:00:08Z",
  "payload": {
    "userId": "f9c0c5fa-91ba-4b9f-92a3-9b3d8c6ae111",
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

…and so on for `planner.suggested`, `guardian.decided`, `intervention.created`.

```json
{
  "type": "intervention.created",
  "ts": "2026-04-22T10:00:15Z",
  "payload": {
    "userId": "f9c0c5fa-91ba-4b9f-92a3-9b3d8c6ae111",
    "actionId": "93ebb8a3-40d2-4b56-b08d-6358d1c0c222",
    "createdAt": "2026-04-22T10:00:15Z",
    "headline": "Leave now and enable Battery Saver",
    "body": "Traffic is worsening and your phone is at 17%. Pulse recommends leaving now and enabling Battery Saver so you reach lab on time.",
    "ctaLabel": "Start commute",
    "secondaryCtaLabel": "Dismiss"
  }
}
```

---

## 4. Versioning

- This file describes **v0 demo contracts**.
- Any breaking change must bump the version and update both mobile + server.
- Keep changelog notes at the bottom of this file.