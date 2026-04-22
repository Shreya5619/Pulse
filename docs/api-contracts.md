# Pulse API Contracts (Standardized v0)

This document defines the strict REST and WebSocket contracts for the Pulse v0 demo.

## WebSocket Envelope
All WebSocket messages follow this strict envelope:
```json
{
  "type": "event.name",
  "eventId": "unique_id",
  "timestamp": "ISO_TIMESTAMP",
  "data": { ... }
}
```

### Event Names
- `connection.ready`: Initial signal upon socket connection.
- `heartbeat.tick`: Orchestration signal.
- `context.updated`: Normalized world state update.
- `risk.updated`: High-level risk assessment.
- `planner.suggested`: Recommended interventions.
- `guardian.decided`: Safety and delivery gatekeeping decision.
- `intervention.created`: Final UI-ready card.

## REST Endpoints
- `GET /health`: System health status.
- `GET /demo/state`: Bootstrap data (profile + context).
- `POST /demo/trigger`: Start the scripted demo replay.
- `GET /demo/events`: Retrieve the full list of scripted events.
- `GET /config/openclaw-files`: Raw OpenClaw configuration contents.

## Key Schema Principles
- Use `timestamp` instead of `ts`.
- Use `data` instead of `payload`.
- Use `minutesToEvent` for time-to-deadline signals.
- Use `trafficStatus` (JAMMED, SLOW, CLEAR) for traffic state.
- Use `label` (LOW, MEDIUM, HIGH, CRITICAL) for risk levels.