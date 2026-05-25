# Pulse & LifeCanvas: Literal Feature Reference Manual

This document is a comprehensive, literal reference of all screens, backend services, and APIs implemented in the Pulse monorepo. Use this as a quick-lookup index during the hackathon or Q&A.

---

## 📱 Mobile Screen Catalogue (Flutter Client)

Located in `mobile/lib/screens/`, these 18 screens form the Pulse mobile interface:

### 1. Home Screen (`home_screen.dart`)
* **Purpose:** The central workspace dashboard for the user.
* **Key Components:**
  * **Stress Score Dial:** A large, colorful radial gauge rendering the user's real-time computed Stress Index (0.0 to 1.0).
  * **Quick Actions Grid:** Direct access buttons to key screens (LifeCanvas, Futures, Digital Twin, Day Pulse, Scenario Player).
  * **Active Intervention Banner:** High-priority card rendering the latest approved Guardian suggestion.
  * **Sensor Status Chips:** Displays real-time device indicators (Battery level, GPS state, and active event count).

### 2. LifeCanvas Screen (`life_canvas_screen.dart`)
* **Purpose:** The primary interface for the AI-powered evolving memory graph.
* **Key Components:**
  * **Memory Galaxy Visualization:** A interactive visual map depicting events as stars and relationships as gravitational strings.
  * **Voice Journaling Button:** Tap-to-record voice note which sends raw audio to Whisper transcription and runs the LLM graph operations loop.
  * **Memory Feed:** A list of extracted life events showing emotional states (color-coded nodes), summary tags, and themes.
  * **Reflections Console:** Displays periodic AI-derived introspective insights (e.g., *"Confidence spikes correlate with creative output"*).

### 3. Futures Screen (`futures_screen.dart`)
* **Purpose:** Renders the A/B/C "What-if" simulation paths.
* **Key Components:**
  * **Path A Card (Do Nothing):** Baseline projection showing failure risks (e.g., predicted lateness or battery death).
  * **Path B Card (Recommended):** The optimal path (e.g., leave now and enable battery saver).
  * **Path C Card (Alternate):** Resilient/fallback path (e.g., charge for 15 minutes, then leave).
  * **Timeline Projection Slider:** Allows users to scrub through the next 120 minutes to see how risks escalate/decrease on each path.

### 4. Digital Twin Graph Screen (`twin_graph_screen.dart`)
* **Purpose:** Displays the live Neo4j behavioral model.
* **Key Components:**
  * **Interactive Subgraph View:** Renders the user's person node connected to current events, location anchors, and learned preferences.
  * **CustomPainter Canvas:** Handles fluid node layouts and interactive physics-based zoom/pan behaviors.

### 5. Day Pulse Screen (`day_pulse_screen.dart`)
* **Purpose:** Displays the daily health/lifestyle overview.
* **Key Components:**
  * **Chronological Time Blocks:** Graph of activities, battery drain, and stress metrics over the last 24 hours.
  * **Daily AI Summary:** A quick-read text card summarizing accomplishments and stressors.

### 6. AI Digest Screen (`digest_screen.dart`)
* **Purpose:** Aggregates, prioritizes, and summarizes notifications and unread messages.
* **Key Components:**
  * **Digest Feed:** Grouped summaries of low-priority notifications (e.g., promotional alerts) so they don't cause distraction.
  * **Response Debt Warnings:** Flags high-priority messages that have been left unread from key contacts.

### 7. Multi-Mode ETA Screen (`multi_mode_eta_screen.dart`)
* **Purpose:** Renders multi-modal route options (Walk, Transit, Drive) powered by OSRM.
* **Key Components:**
  * **Comparative Routes List:** Shows travel times, traffic delays, and battery impact (e.g., GPS navigation drains battery 50% faster).

### 8. Gantt Screen (`gantt_screen.dart`)
* **Purpose:** Provides a linear schedule timeline visualizing event overlaps and schedule conflicts.
* **Key Components:**
  * **Gantt Chart Blocks:** Highlights schedule overload risks if multiple appointments overlap.

### 9. Scenario Player (`scenario_player_screen.dart` & `replay_screen.dart`)
* **Purpose:** Developer helper to simulate scenarios.
* **Key Components:**
  * **Play/Pause controls:** Step through historical logs or run the "Commute Rescue" demo step-by-step.
  * **Event Log Terminal:** Prints real-time WebSocket payloads as they are received.

### 10. Context Debug Screen (`context_debug_screen.dart`)
* **Purpose:** Real-time sensor monitoring.
* **Key Components:**
  * **Raw Telemetry Readout:** Displays exact coordinates, battery discharge rates, calendar arrays, and active notifications.

### 11. Other Screens:
* **Intervention Screen (`intervention_screen.dart`):** Detailed modal explaining *why* an intervention was recommended and offering quick one-tap actions.
* **Feedback Screen (`feedback_screen.dart`):** Lets users rate agent decisions to train the preference database.
* **Graph Explanation Screen (`graph_explanation_screen.dart`):** Educates the user on how the AI builds connections in LifeCanvas.
* **Stream Screen (`stream_screen.dart`):** Debug list showing the raw JSON feed from the WebSocket.
* **Timeline Screen (`timeline_screen.dart`):** Chronological linear list of upcoming tasks.
* **Overlay Screen (`overlay_screen.dart`):** Android overlay widget for quick dashboard glances.

---

## ⚙️ Backend Services & Endpoints (TypeScript Server)

Located in `server/src/routes/` and backed by core agents in `agents/`:

### 1. Context Ingestion (`context.ts` / Ingestion Service)
* **Endpoint:** `POST /api/snapshots`
* **Features:** Normalizes raw mobile telemetry, computes basic time metrics (like `minutes_to_next_event`), and triggers the agent heartbeat evaluation.

### 2. Risk Engine (`graph.ts` / Risk Agent)
* **Endpoint:** `GET /api/graph/risk` & `GET /api/graph/risk/history`
* **Features:** Evaluates the user's risk scores across four dimensions:
  * **Lateness:** Travel time vs. event start time.
  * **Battery:** Drain rate projection.
  * **Response Debt:** Unread priority messages and time elapsed.
  * **Overload:** Calendar overlaps and notification frequency.

### 3. Futures Simulation (`futures.ts` / Futures Service)
* **Endpoint:** `GET /api/futures`
* **Features:** Simulates the A/B/C path projections. Evaluates GPS routing data and battery discharge rates under different scenarios (e.g. saver mode vs. normal mode) for a 120-minute horizon.

### 4. Digital Twin API (`twin.ts` / Sync Engine)
* **Endpoint:** `GET /api/twin/graph`
* **Features:** Generates a structured JSON subgraph (nodes & edges) representing the user, their upcoming calendar events, and preferences from Neo4j.

### 5. LifeCanvas Engine (`lifecanvas.ts` / Memory Service)
* **Endpoint:** `POST /api/lifecanvas/journal`
* **Features:** Transcribes audio via Whisper, executes semantic extraction via LLM, proposes graph mutations, and updates the Neo4j life graph.

### 6. Daily Summarizer (`dayPulse.ts` / Summarization Service)
* **Endpoint:** `GET /api/daypulse/summary`
* **Features:** Runs a batch job to analyze the last 24 hours of user snapshots and generates an AI summary of the user's day, updating preferences (e.g., commute timing habits) in the Digital Twin.

### 7. Routing Service (`routing.ts` / OSRM Service)
* **Endpoint:** `POST /api/routing/eta`
* **Features:** Performs routing calculations using local OSRM datasets (specifically for the Bengaluru region demo).

### 8. Other Route Endpoints:
* **`memory.ts`:** Accesses user habits and battery usage profiles.
* **`planner.ts`:** Returns ranked intervention proposals.
* **`guardian.ts`:** Configures automation approval thresholds.
* **`comm.ts`:** Monitors priority contacts and unread queues.
