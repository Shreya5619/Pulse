# Pulse

Pulse is a **multi‑agent, predictive assistant** that runs on your phone and talks to a backend “heartbeat” server. It models your context, risk, and priorities, then recommends your **next best move** in real time.

> Tech focus: Flutter mobile client + TypeScript/Node backend with REST + WebSocket, plus an OpenClaw‑style agent and memory layout.

---

## Monorepo layout

```txt
pulse/
  mobile/        # Flutter / Android client
  server/        # REST + WebSocket backend
  agents/        # Context, Risk, Planner, Guardian, Heartbeat agents
  memory/        # User profile + history + state store
  contracts/     # Shared API + event schemas
  docs/          # Specs, API contracts, demo scenario
  scripts/       # Dev / demo / tooling scripts
  data/          # Fixtures, mock user state, OpenClaw-style files
  tests/         # API + integration tests
  .env.example   # Sample backend environment
  docker-compose.yml
  README.md
```

---

## Concept

Pulse acts like a **personal digital twin** for your attention and time:

- Watches **context signals**: time, location, battery, calendars, traffic.
- Runs a **5‑agent neural swarm** (Context, Memory, Risk, Planner, Guardian).
- Uses a **heartbeat loop** to evaluate short‑term failure risk (e.g., “you’ll miss class + lab instructions”).
- Pushes **simple interventions** to your phone (leave now, enable battery saver, auto‑draft a delay note).

The current sprint focuses on a single demo scenario (the “Commute Rescue”) to prove the end‑to‑end architecture.

---

## Tech stack

- **Mobile:** Flutter (Android‑first shell, 4 demo screens)
- **Backend:** Node/TypeScript (Express or Fastify) + WebSocket
- **Agents:** TypeScript modules in `agents/` orchestrated by the server
- **Memory:** JSON‑backed store (swappable for DB later)
- **Contracts:** Shared TypeScript types for REST + WS payloads
- **Infra:** Docker + `docker-compose` for local dev

---

## Getting started

### 1. Clone and install

```bash
git clone https://github.com/your-org/pulse.git
cd pulse

# install backend deps
cd server
pnpm install   # or npm/yarn

# install mobile deps
cd ../mobile
flutter pub get
```

### 2. Configure environment

Copy the sample env and adjust ports/keys as needed:

```bash
cp .env.example .env
```

Key vars (backend):

- `PULSE_HTTP_PORT` – REST/WS port (default: 8080)
- `PULSE_DEMO_USER_ID` – user id for the demo scenario

### 3. Run with Docker (recommended)

From repo root:

```bash
docker-compose up --build
```

This will:

- Start the **Pulse server** (REST + WebSocket)
- Optionally start supporting services (e.g., DB / cache, if added later)

### 4. Run locally without Docker

Backend:

```bash
cd server
pnpm dev    # or npm run dev
```

Mobile:

```bash
cd mobile
flutter run
```

Point the app to the backend host/port in your Flutter env/config.

---

## Demo scenario: Commute Rescue

The first milestone is a **fake but fully wired** demo where data flows from server → agents → mobile.

### Flow

1. Mobile calls `GET /demo/state` to fetch initial context (25 mins to class, 17% battery, traffic worsening).
2. Mobile opens a WebSocket connection to `/ws`.
3. Server reads fixtures from `data/` and OpenClaw‑style files in `data/openclaw/`:
   - `SOUL.md` – assistant personality & safety boundaries  
   - `agents.md` – role definitions for 5 agents  
   - `user.md` – user preferences, trusted contacts  
   - `heartbeat.md` – heartbeat loop rules
4. Server runs a **demo heartbeat**:
   - Context agent normalizes signals  
   - Memory agent retrieves patterns  
   - Risk agent scores failure probability  
   - Planner agent proposes an intervention  
   - Guardian agent decides auto‑act vs ask‑first
5. Server emits a sequence of WS events:
   - `heartbeat.tick`
   - `context.updated`
   - `risk.updated`
   - `planner.suggested`
   - `guardian.decided`
   - `intervention.created`
6. Mobile listens and renders the intervention card on one of the demo screens.

---

## API overview (v0 demo)

### REST

- `GET /health`  
  Returns `{ "status": "ok" }` to confirm backend is running.

- `GET /demo/state`  
  Returns initial demo context and user snapshot.

- `POST /demo/trigger`  
  Starts the demo heartbeat sequence for the current user.

### WebSocket

Connect to:

```txt
ws://<host>:<port>/ws
```

Core event types (enveloped):

- `heartbeat.tick`
- `context.updated`
- `risk.updated`
- `planner.suggested`
- `guardian.decided`
- `intervention.created`

Payload shapes are defined in `contracts/` and documented in `docs/ws-events.md`.

---

## Development workflow

- **A (mobile):**
  - Owns `mobile/` app shell, navigation, and 4 demo screens.
  - Renders data from REST bootstrap + WS events using shared contracts.

- **B (backend):**
  - Owns `server/`, `agents/`, `memory/`, `contracts/`, `data/`, and backend docs.
  - Ensures monorepo boots and the fake demo payload moves end‑to‑end.

Routing is limited to Bengaluru region for demo; OSRM dataset included.