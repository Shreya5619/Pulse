# Pulse: The Proactive Digital Twin for Attention

Pulse is an autonomous, predictive assistant designed to bridge the gap between human intention and execution. Built on the **OpenClaw Agentic Framework**, Pulse moves beyond passive "smart assistants" by running a continuous **Neural Heartbeat** that anticipates failures and intervenes before they happen.

![Pulse Dashboard](docs/images/dashboard.png)

---

## 🚀 Why Pulse is Novel: The "Agentic Edge"

Unlike traditional productivity tools, Pulse introduces three industry-leading innovations:

### 1. The 5-Agent Neural Swarm
We have moved away from a single "Chatbot" model. Pulse utilizes a **Swarm of 5 Specialized Agents** (Context, Memory, Risk, Planner, Guardian) that run in parallel. This allows for multi-modal reasoning—simultaneously analyzing your GPS, battery discharge, and social media habits to decide your "Next Best Move."

### 2. The Heartbeat Loop (Proactive vs. Reactive)
Most AI assistants wait for a prompt. Pulse has a **Heartbeat**. Every 180 seconds, the system autonomously re-evaluates your trajectory. If it predicts a schedule collapse (e.g., *Traffic Spike + Low Battery*), it doesn't wait for you to notice—it pushes an **Active Intervention**.

### 3. The Digital Twin Graph
Pulse models your identity as a living **Digital Twin**. Using a graph-based memory system, it learns your "Contextual DNA"—how you handle stress, which contacts you prioritize, and your typical commute buffers. This twin evolves every night through an autonomous **Self-Reflection** cycle.

---

## 🛠️ Key Novel Features

| Feature | The "Next-Gen" Innovation |
| :--- | :--- |
| **Futures Engine** | Simulates hundreds of parallel timelines to identify "invisible" collisions hours before they occur. |
| **Guardian Shield** | Real-time **Doomscroll Prevention** that triggers app-locks only when your "Attention Risk" is critical. |
| **Ghost-Writer** | Context-aware communication that pre-drafts and suggests delay notes, status updates, and rescheduling requests. |
| **Privacy-First Monitoring** | High-frequency context signals (GPS, Notifications, Battery) are processed on-device, ensuring absolute privacy. |

![Bengaluru Stat](docs/images/bengaluru_stat.png)

---

## 🏗️ Technical Architecture

*   **Framework**: OpenClaw (Agentic Orchestration).
*   **Intelligence Swarm**: Node.js/TypeScript backend running 5 discrete reasoning loops.
*   **Persistence**: PostgreSQL (Audit), JSON/Markdown (Long-term Memory), Neo4j (Twin Graph).
*   **Geo-Intelligence**: Local OSRM integration for traffic-aware routing.
*   **Real-time Sync**: Low-latency WebSocket "Heartbeat" events (100ms response time).

---

## 📦 Release & SDKs

### Android APK
For a quick demo, you can download the latest stable build of the Pulse Guardian app:
*   🔗 **[Download Pulse.apk (v1.0.0)](https://drive.google.com/drive/u/1/folders/19EpEm6bIesJsUDiGa_PZQRafDZ5rwtFW)**

### SDK Requirements
*   **Flutter SDK**: `^3.11.5`
*   **Android SDK**: `minSdkVersion 21`, `targetSdkVersion 34`
*   **Critical SDKs**: `battery_plus`, `geolocator`, `flutter_notification_listener`, `web_socket_channel`.

---

## 🎬 The "Commute Rescue" Scenario
*Watch Pulse in action during a high-stakes morning:*
1.  **Context Agent** detects a traffic spike + 15% battery.
2.  **Risk Agent** scores an 85% probability of missing a class.
3.  **Guardian** pushes an intervention card with a pre-drafted delay note.
4.  **User** taps "Send" and the **Communication Service** executes the fix instantly.

![Pulse Notification](docs/images/notification.png)

---

*Pulse: Because in the age of distraction, attention is the only asset that matters.*