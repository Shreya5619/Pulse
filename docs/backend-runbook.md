# Backend Runbook (Pulse v0)

This runbook explains how to run, debug, and extend the Pulse backend for the v0 demo.

---

## 1. Services

The backend currently exposes:

- **HTTP REST API** (Express/Fastify) on `PULSE_HTTP_PORT`
- **WebSocket endpoint** at `/ws`
- **Agent orchestration** in `agents/`
- **Memory store** in `memory/` backed by JSON fixtures in `data/`

---

## 2. Booting locally

### 2.1 Requirements

- Node.js 20+
- pnpm / npm / yarn
- Docker (optional, for `docker-compose`)

### 2.2 Environment

From repo root:

```bash
cp .env.example .env
```

Key variables:

```env
PULSE_HTTP_PORT=8080
PULSE_LOG_LEVEL=debug
PULSE_DEMO_USER_ID=USER_DEMO
```

### 2.3 Start server

Without Docker:

```bash
cd server
pnpm dev          # or npm run dev
```

With Docker:

```bash
docker-compose up --build
```

---

## 3. Health checks

### REST

```bash
curl http://localhost:8080/health
```

Expected:

```json
{
  "ok": true,
  "data": {
    "service": "pulse-server",
    "version": "0.0.1"
  }
}
```

### WebSocket

Use `wscat` or similar:

```bash
wscat -c ws://localhost:8080/ws
```

On a running demo you should see `heartbeat.tick` and other events.

---

## 4. Demo scenario

### 4.1 Trigger via REST

```bash
# get initial state
curl "http://localhost:8080/demo/state?userId=USER_DEMO"

# trigger demo
curl -X POST "http://localhost:8080/demo/trigger" \
  -H "Content-Type: application/json" \
  -d '{"userId":"USER_DEMO"}'
```

### 4.2 Files used

- `data/demo-user.json`
- `data/demo-scenario.json`
- `data/openclaw/SOUL.md`
- `data/openclaw/agents.md`
- `data/openclaw/user.md`
- `data/openclaw/heartbeat.md`

The heartbeat loop should emit the WS events in the order documented in `docs/ws-events.md`.

---

## 5. Code structure (server)

Suggested layout:

```txt
server/
  src/
    app.ts            # create HTTP + WS server
    routes/
      demo.ts         # /demo/state, /demo/trigger
      health.ts       # /health
      config.ts       # /config/openclaw-files
    ws/
      gateway.ts      # connection handling, broadcast
      demoFlow.ts     # scripted demo event sequence
    services/
      heartbeat.ts    # orchestrates agents per tick
      logging.ts
    adapters/
      agentsAdapter.ts  # calls modules in /agents
      memoryAdapter.ts  # calls modules in /memory
      dataAdapter.ts    # loads fixtures from /data
    util/
      time.ts
      env.ts
```

Agents and memory live in separate top‑level folders:

```txt
agents/
  context/
  memory/
  risk/
  planner/
  guardian/
  heartbeat/

memory/
  profile/
  history/
  store/
```

---

## 6. Common operations

### 6.1 Tail logs

```bash
cd server
pnpm dev  # logs to stdout with PULSE_LOG_LEVEL
```

### 6.2 Run tests

```bash
cd server
pnpm test
```

Tests should cover:

- `GET /health`
- `GET /demo/state`
- `POST /demo/trigger`
- WS sequence (via integration test)

### 6.3 Reset demo state

If you add stateful behavior, provide a reset script:

```bash
pnpm demo:reset
```

This can simply delete/overwrite `data/state/*.json`.

---

## 7. Making changes safely

1. **Update contracts first**  
   - Edit `contracts/*` and `docs/api-contracts.md`.
   - Get sign‑off from mobile.

2. **Update backend implementation**  
   - Adjust routes and WS emitters.
   - Run tests.

3. **Notify mobile**  
   - Share example payloads and any changed fields.

4. **Update docs**  
   - Sync `docs/ws-events.md` and `docs/demo-scenario.md`.

---

## 8. Troubleshooting

### No events on WebSocket

- Check server logs for connection events.
- Verify app is connecting to the correct host/port.
- Verify `POST /demo/trigger` is called.

### Wrong payload shape

- Compare against `docs/api-contracts.md`.
- Run contract tests in `tests/`.

### Docker issues

- Ensure port mapping in `docker-compose.yml` matches `PULSE_HTTP_PORT`.
- Rebuild images after changing dependencies:

```bash
docker-compose build --no-cache
```

---

## 9. Future work

- Swap JSON memory for a real DB.
- Add authentication / user separation.
- Generalize heartbeat loop for multiple scenarios.
- Add metrics / tracing for agent decisions.
