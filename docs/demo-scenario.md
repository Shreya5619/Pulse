# Demo Scenario: Commute Rescue

This document describes the exact scripted scenario used to demo Pulse v0.

---

## Story

Alex has **25 minutes** to reach a critical lab, but their phone is at **17% battery** and traffic is **worsening**. Pulse’s 5‑agent swarm spots the risk that Alex will arrive late with a dead phone, and recommends the next best move *before* things go wrong.

---

## Initial state

User:

```json
{
  "id": "USER_DEMO",
  "name": "Alex",
  "homeLocation": "Kormangala",
  "destination": "Campus Lab",
  "quietHours": "23:00-07:00"
}
```

Context:

```json
{
  "userId": "USER_DEMO",
  "timestamp": "2026-04-22T10:00:00Z",
  "locationLabel": "Home",
  "batteryPercent": 17,
  "minutesToEvent": 25,
  "eventName": "Physics Lab",
  "trafficStatus": "JAMMED"
}
```

---

## Objective

Show that:

1. **Mobile** can fetch initial state via REST.
2. **Backend + agents** can run a heartbeat loop.
3. **Events** flow over WebSocket in a predictable sequence.
4. **UI** renders a final intervention card from the streamed data.

No real ML, routing, or calendar integration is required for this milestone.

---

## Sequence of steps

1. User opens the Pulse demo app.
2. App calls `GET /demo/state?userId=USER_DEMO` and renders initial context.
3. App opens a WebSocket connection to `/ws`.
4. App calls `POST /demo/trigger` (or presses a “Start Demo” button that does this).
5. Backend:
   - Reads fixtures from `data/demo-user.json` and `data/demo-scenario.json`.
   - Loads OpenClaw‑style files from `data/openclaw/`:
     - `SOUL.md`
     - `agents.md`
     - `user.md`
     - `heartbeat.md`
   - Starts a heartbeat loop emitting the WS events defined in `docs/ws-events.md`.
6. App listens and progressively updates the UI:
   - Shows context and risk changing.
   - Highlights the planner’s suggested action.
   - Shows guardian’s decision mode (Auto‑act vs Ask first).
   - Finally renders the **Intervention Card** with CTA.

---

## UI mapping (suggested)

Screen 1 – **Hero**

- Title + tagline (“Predicts risk. Plans action. Prevents failure.”)
- Button: “Run Commute Rescue Demo”

Screen 2 – **Signals**

- Show context: time to lab, battery, traffic.
- Annotate: “Pulse watches these signals.”

Screen 3 – **5‑Agent Swarm**

- Visual of the 5 agents around the Heartbeat Core.
- As WS events arrive, highlight each agent as it fires.

Screen 4 – **Intervention**

- Final card with:
  - Headline: “Leave now and enable Battery Saver”
  - Body copy from `InterventionCard.body`
  - Primary CTA: “Start commute”
  - Secondary: “Dismiss”

---

## Constraints

- Demo should be **deterministic**: same events in same order on each run.
- All payloads must conform to `docs/api-contracts.md`.
- No external APIs are required for v0 – all data can be local fixtures.
