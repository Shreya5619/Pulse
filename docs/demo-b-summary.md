# Pulse Demo B: Wired Agent Flow

Demo B establishes the core plumbing of Pulse, routing a deterministic "Commute Rescue" scenario through the 5-agent swarm and delivering it to a WebSocket-enabled client.

## Core Accomplishments
- **Standardized Schema**: Implemented a strict `{ type, eventId, timestamp, data }` envelope across all events.
- **Agent Orchestration**: Wired the `agents/` and `memory/` stubs into the main server loop.
- **Deterministic Scenario**: Fixed a 17% battery / 25min to class scenario as the stable integration target.
- **Integration Proven**: Created a test client to verify payload delivery without the mobile app.

## The Wired Flow
When `POST /demo/trigger` is called, the server executes:
1. **Heartbeat Agent**: Emits `heartbeat.tick` (sequence 1).
2. **Context Agent**: Normalizes raw signals -> Emits `context.updated`.
3. **Risk Agent**: Detects high failure risk -> Emits `risk.updated`.
4. **Planner Agent**: Proposes "Leave Now + Battery Saver" -> Emits `planner.suggested`.
5. **Guardian Agent**: Decides "Ask First" for delay note -> Emits `guardian.decided`.
6. **Delivery**: Final UI card is emitted over WebSocket -> `intervention.created`.

## How to Test
You can prove the end-to-end flow reaches the "client" side using the provided integration script:

1. Ensure the server is running (`npm run dev` in `server/`).
2. Open a new terminal in the root directory.
3. Run the integration test:
   ```bash
   cd server
   npm run test:integration
   ```

## Status Checklist
- [x] Build server REST + WebSocket skeleton
- [x] Create shared API and event contracts
- [x] Stub agents/ and memory/ modules
- [x] Add demo fixtures in data/
- [x] Document flow in docs/
- [x] Add replay scripts and integration tests
- [x] Prove fake payload reaches mobile/ end-to-end
