# Pulse: Project Feature Inventory

Pulse is a **proactive digital twin** designed to protect human attention and optimize execution in high-friction environments. Built on the **OpenClaw Agentic Framework**, it moves beyond passive calendars into autonomous intervention.

---

### 🧠 1. Core Agentic Architecture (OpenClaw Swarm)
*   **The 5-Agent Neural Swarm**: A coordinated orchestration of five specialized agents:
    *   **Context Agent**: Normalizes multi-modal signals (GPS, Battery, Calendar, App Usage).
    *   **Memory Agent**: Retrieves long-term habits and digital twin preferences.
    *   **Risk Agent**: Calculates "Failure Probability" scores for upcoming commitments.
    *   **Planner Agent**: Simulates and selects the "Next Best Move" from multiple futures.
    *   **Guardian Agent**: Decides the level of intervention (Notify vs. Auto-Act).
*   **Autonomous Heartbeat Loop**: A low-latency background pipeline that re-evaluates the user's state every 180 seconds, ensuring the system is never out of sync with reality.
*   **Full Audit Observability**: Every single decision is logged in a `heartbeat_audit` trail, allowing developers to trace an intervention back to the specific sensor signal that triggered it.

### 👤 2. The Digital Twin & Memory System
*   **Nightly Self-Reflection**: A "sleep cycle" for the AI. Every night, the **MemoryAgent** reviews the day’s graph, analyzes schedule deviations, and updates the `user.md` preference file to evolve with the user.
*   **Multi-Dimensional Memory Tables**: specialized persistence for:
    *   **Habit Memory**: Learning recurring routines without manual input.
    *   **Battery Memory**: Predicting phone death based on historical discharge patterns.
    *   **Commute Memory**: Tracking favorite routes and typical "buffer" times.
*   **Graph-Based Identity**: Modeling the user not as a list of tasks, but as a network of relationships, priorities, and constraints.

### 🔮 3. Risk & Predictive Intelligence
*   **The Futures Engine**: A "simulation mode" that projects the user's current trajectory into the next 4 hours to detect "invisible" collisions (e.g., *“If you stay here, you will reach your 6 PM meeting with 2% battery”*).
*   **Dynamic Risk Scoring**: A real-time 0-100 score indicating the stability of the current plan, visualized via the "Heartbeat" ring on the mobile dashboard.
*   **Context-Aware ETA (OSRM Integration)**: Real-time routing that combines live traffic data with personal "buffer preferences" to provide the most realistic arrival times.

### 🛡️ 4. Proactive Guardian Interventions
*   **Doomscroll Prevention**: Real-time integration with `AppState` to detect social media usage during "High Risk" focus blocks.
*   **Adaptive App Shielding**: Automatically suggesting (or enforcing) notification silences or app locks when the user's "Attention Risk" is high.
*   **Ghost-Writing / Auto-Drafting**: The **CommunicationService** can pre-draft "I'll be late" messages or "Status Updates" for stakeholders, ready for a one-tap send the moment a delay is detected.
*   **Intervention Feedback Loop**: Pulse learns from "Dismissals." If a user ignores a specific guardian nudge, the system adjusts its "Heartbeat Policy" to be less intrusive or more relevant.

### 📱 5. Experience & Real-Time Sync
*   **Ask Pulse (Agentic Chat)**: A natural language interface that doesn't just "talk"—it executes. You can ask *"Reschedule my gym"* and it updates the graph and notifies relevant parties.
*   **Live WebSocket Dashboard**: A real-time link between the Node.js agent swarm and the Flutter mobile client, ensuring 100ms latency for risk updates and intervention cards.
*   **Pulse Mobile Widget**: A home-screen portal that keeps the "Digital Twin Status" visible at a glance, minimizing the need to open the app.

---

### 🛠️ Technical Stack
*   **Backend**: Node.js/TypeScript (Fastify/Express)
*   **Intelligence**: OpenClaw Framework (Agentic Logic), LLM Orchestration
*   **Mobile**: Flutter (Cross-platform shell)
*   **Data**: PostgreSQL (Persistence), Neo4j (Graph), JSON (Agent Memory)
*   **Geo**: OSRM (Routing), Geocoding APIs
