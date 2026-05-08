# Pulse: The Proactive Digital Twin for Attention

Pulse is an autonomous, predictive assistant designed to bridge the gap between human intention and execution. Built on the **OpenClaw Agentic Framework**, Pulse monitors your real-time context—traffic, battery, habits, and schedules—to predict failure risks and intervene before they happen.

![Pulse Dashboard](docs/images/dashboard.png)

---

## 🌟 Core Concepts

Pulse acts as a **Digital Twin** that protects your most valuable resource: **Attention**.

*   **The Heartbeat Architecture**: A continuous background loop that evaluates your state every 180 seconds.
*   **The 5-Agent Neural Swarm**: A coordinated orchestration of specialized agents (**Context, Memory, Risk, Planner, Guardian**) that think in parallel to solve your day's friction.
*   **Predictive Guardianship**: Pulse doesn't just notify; it intervenes. From locking distracting apps during high-risk blocks to ghost-writing delay notes when traffic spikes, Pulse is always one step ahead.

---

## 🚀 Key Features

| Feature | Description |
| :--- | :--- |
| **Futures Engine** | Simulates parallel trajectories for the next 4 hours to detect "invisible" collisions (e.g., phone death vs. meeting start). |
| **Digital Twin Graph** | A living model of your habits, preferences, and identity that evolves autonomously through nightly self-reflection. |
| **Risk Scoring** | A real-time 0-100 score indicating the stability of your current plan, synced via WebSockets. |
| **Active Interventions** | One-tap "Smart Cards" for rescheduling, auto-drafting messages, or shielding focus. |
| **Home-Screen Widget** | A glanceable "Heartbeat" portal keeping your Digital Twin status visible at all times. |

![Bengaluru Stat](docs/images/bengaluru_stat.png)

---

## 🛠️ Tech Stack

*   **Mobile**: Flutter (Dart) — High-fidelity, multi-mode interaction shell.
*   **Backend**: Node.js / TypeScript — Agentic orchestrator and "Heartbeat" server.
*   **Intelligence**: OpenClaw Framework — Multi-agent swarm and memory management.
*   **Data**: PostgreSQL (Audit) + JSON/Markdown (Agent Memory) + Neo4j (Twin Graph).
*   **Geo**: OSRM (Open Source Routing Machine) for traffic-aware local routing.

---

## 📁 Monorepo Layout

```txt
pulse/
  mobile/        # Flutter / Android client
  server/        # REST + WebSocket backend
  agents/        # Context, Risk, Planner, Guardian, Heartbeat agents
  memory/        # User profile + history + state store (OpenClaw style)
  contracts/     # Shared API + event schemas
  docs/          # Specs, API contracts, images
  data/          # Fixtures, mock user state, routing datasets
```

---

## 🚦 Getting Started

### 1. Prerequisites
*   Flutter SDK
*   Node.js (v18+)
*   Docker (Optional, for OSRM/DB)

### 2. Installation
```bash
# Clone the repo
git clone https://github.com/your-org/pulse.git
cd pulse

# Setup Backend
cd server
pnpm install

# Setup Mobile
cd ../mobile
flutter pub get
```

### 3. Run Locally
**Backend:**
```bash
cd server
npm run dev
```

**Mobile:**
```bash
cd mobile
flutter run
```

---

## 🎬 Demo Scenario: Commute Rescue

The primary showcase involves a real-time "Red Alert" scenario where:
1.  **Context Agent** detects a traffic spike + 15% battery.
2.  **Risk Agent** scores an 85% probability of missing a class.
3.  **Guardian** pushes a notification with a pre-drafted delay note.
4.  **User** taps "Send" and the **Communication Service** executes the fix instantly.

![Pulse Notification](docs/images/notification.png)

---

*Pulse was built for the high-stakes multitasking world, where every minute counts.*