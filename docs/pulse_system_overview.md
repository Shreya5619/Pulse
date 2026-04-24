# Pulse System Overview & API Documentation

Pulse is a **multi-agent predictive assistant** that monitors user context (location, battery, calendar, notifications) to provide real-time risk mitigation and interventions. This document explains the current architecture, API surface, and integration guide for the mobile application.

---

## 1. System Architecture

The backend is built as a **Swarm of Agents** coordinated by a central heartbeat:
- **Ingestion Layer**: Receives raw sensor data from the mobile app.
- **Normalization Engine**: Transforms messy sensor data into strict, enriched `ContextSnapshots`.
- **Memory Layer**: A persistent store (Postgres + YAML) that tracks long-term habits, battery profiles, and commute patterns.
- **Agent Orchestrator**: Runs a deterministic flow (Heartbeat → Context → Risk → Planner → Guardian) to generate interventions.

---

## 2. API Reference

### 2.1 Context Ingestion
**Endpoint**: `POST /api/snapshots`  
**Description**: Primary endpoint for the mobile app to report device state.

- **Headers**:
  - `X-User-Id`: Unique identifier for the user (e.g., `user_123`).
  - `X-Device-Id`: Unique identifier for the hardware.
- **Payload**:
  - Requires `location` (lat/lon), `battery` (level/charging), `calendar` (events), `notifications` (active list), and `device_state`.
- **Response**:
  - Returns the `snapshot_id` and derived fields like `minutes_to_next_event`.
  - **Echo Mode**: In development, it returns the fully normalized object for verification.

### 2.2 Memory Access
**Endpoint**: `GET /api/memory/summary`  
**Description**: Returns the long-term "soul" of the user. Used by Risk and Planner agents to ground decisions.

- **Query Params**: `userId` (defaults to `user_123`).
- **Data Returned**:
  - **Identity**: Home/Office locations and commute windows.
  - **Habits**: Typical lateness and departure offsets.
  - **Battery Profile**: Average discharge rates and "risky hours" (times when charging is unlikely).
  - **Commute**: Frequent routes and travel time statistics (P50/P90).

### 2.3 Real-time Updates (WebSocket)
**Endpoint**: `ws://<host>:8080/ws`  
**Description**: Real-time stream of agent events.

- **Event Types**:
  - `heartbeat.tick`: Sent every 5 seconds to confirm connectivity.
  - `context.updated`: Emitted when a new snapshot is processed.
  - `risk.updated`: Emitted when the Risk Agent changes the safety score.
  - `intervention.created`: The final payload for the mobile app to show a notification or UI alert.

### 2.4 Demo & Triggering
- `POST /api/demo/trigger`: Runs a full "Commute Rescue" scenario simulation.
- `POST /api/heartbeat/manual`: Manually wakes the agent swarm to evaluate current context.
- `POST /api/memory/trigger`: Forces the Memory Agent to run a new 7-day summarization.

---

## 3. Seeding & Developer Helpers

Pulse includes several scripts to set up a testing environment without needing live mobile data:

- **`npm run db:init`**: Applies the Postgres schema (`schema.sql`). Run this first.
- **`npx tsx scripts/seedMemory.ts`**: Creates a plausible memory profile for `user_plausible` (simulating weeks of usage).
- **`npx tsx scripts/seed-snapshots.ts`**: Populates the DB with 140 historical snapshots for testing the Summarizer.
- **`npx tsx scripts/exportMemoryToFiles.ts [userId]`**: Dumps Postgres memory to human-readable YAML files in the `memory/` directory.

---

## 4. Mobile App Integration Guide

### 4.1 Communication Cadence
The mobile app should report context snapshots based on the following triggers:
1. **Periodic**: Every 15 minutes while the app is in the background.
2. **Event-Driven**: Immediately when the user enters a "Commute Window" (defined in Identity memory).
3. **Significant Change**: When battery drops below 20% or a new high-priority calendar event is detected.

### 4.2 Handling Interventions
The app should listen to the WebSocket for `intervention.created` events.
```json
{
  "type": "intervention.created",
  "data": {
    "headline": "Leave now and enable Battery Saver",
    "body": "Traffic is worsening and your phone is at 17%...",
    "ctaLabel": "Start commute"
  }
}
```
Upon receiving this, the app should display a **High-Priority Notification** or a **Glassmorphic Modal** if the app is foregrounded.

### 4.3 Data Synchronization
On app startup, the app should call `GET /api/memory/summary` to localise its behavior (e.g., knowing when to increase sensor polling based on the user's `morning_window`).
