# Pulse & LifeCanvas: Hackathon Feature Catalogue

Welcome to the **Pulse & LifeCanvas Master Pitch & Feature Catalogue**. This document is designed for the **10-minute pitch + 10-minute Q&A** format. It outlines the core features of the system, details the "Wow Factors" that will impress judges, and maps potential questions directly to our technological strengths.

---

## 🚀 The Core Pitch (The 1-Minute Hook)
> **"Most assistants react only after you ask. Pulse is a proactive, multi-agent digital twin that predicts life-disruptions before they happen, paired with LifeCanvas—a dynamic, self-evolving cognitive map of your memories and identity. It doesn't just manage your schedule; it understands who you are."**

---

## 💎 The "Wow Factor" Features

Here is the master list of features. Each feature is designed to showcase advanced engineering, high-fidelity UI design, and sophisticated backend orchestration.

### 🧠 1. The Multi-Agent Predictive Swarm (OpenClaw Compliant)
* **Deterministic Agent Pipeline:** Built on OpenClaw principles, ensuring clear, auditable execution states. Every heartbeat loop (every 5–15 seconds) fires a sequence of specialized agents:
  1. **Context Agent:** Enriches raw signals (GPS, battery, calendars, notifications) into structured snapshots.
  2. **Memory Agent:** Pulls historical habits and patterns from the long-term database.
  3. **Graph Builder:** Generates a relational schema of the next 4 hours.
  4. **Risk Agent:** Quantifies exact failure probabilities.
  5. **Futures Engine:** Runs simulations for the next 120 minutes.
  6. **Planner Agent:** Suggests risk mitigation interventions.
  7. **Guardian Agent:** Approves actions based on safety rules (AUTO vs. ASK vs. BLOCK).
* **Observability & Time-Travel Debugging:** Every state change and decision is written to a `heartbeat_audit` table. This allows developers and judges to inspect the exact input, decision path, and output for any past moment.

### 🔮 2. The Futures Engine ("What-If" Simulation)
* **Real-time Trajectory Modeling:** Rather than just alerting you when a problem occurs, Pulse constantly simulates three distinct future paths (A/B/C) 120 minutes ahead:
  * **Path A (Do Nothing):** Baseline projection showing the consequences of keeping your current state (e.g., lateness, battery dying).
  * **Path B (Recommended):** Optimizes for survival and arrival (e.g., leave *now* + automatically toggle Battery Saver mode).
  * **Path C (Alternate):** Focuses on system resilience (e.g., charge device for 15 minutes first, then leave).
* **Dynamic Stress Score:** Combines multiple risk factors into a unified `Stress Index` ∈ [0, 1] using weighted heuristics (70% max risk + 30% average risk), keeping the UI clean and simple.

### 👥 3. Digital Twin: Graph-Backed Behavioral Mirror
* **Graph-Based Personalization:** Built on Neo4j, creating a direct representation of the user (`:Person`), their upcoming `:Event` objects, and their `:BatteryState` chain.
* **Daily Summarizer:** Automatically extracts patterns (e.g., *"Leaves 10 mins late for morning commutes"*) and saves them as `:Preference` and `:Pattern` nodes.
* **Closed-Loop Risk Calibration:** The Risk Engine adjusts threshold parameters based on the Digital Twin's preferences. For example, if a user has a `LATENESS_TOLERANCE=LOW` preference, the Risk Engine alerts them 15 minutes earlier than usual.

### 🌌 4. LifeCanvas: Evolving Cognitive Memory Graph
* **Not a Note App, But a Second Brain:** Unlike standard chronological diary/note-taking apps, LifeCanvas transforms voice notes or text entries into a **graph database representation of human identity**.
* **Galaxy Neural Network / Temporal River Visualization:** Visualized in the mobile client using a highly interactive graph interface.
  * **Stars & Orbits:** Major life-changing events appear as large nodes ("stars"), while minor recurring memories orbit them as particles.
  * **Gravitational Connections:** Lines between nodes represent non-chronological, semantic relationships (e.g., `caused_by`, `inspired_by`, `identity_shift`, `trauma_link`).
* **Hallucination-Safe Agentic Graph Mutations:** To protect database integrity, the LLM never directly edits the Neo4j graph. Instead, the LLM acts as an observer proposing connection operations, which are validated by a deterministic orchestration layer before mutation.
* **Hybrid Memory Retrieval:** 
  1. **Vector Retrieval:** Employs cosine similarity over semantic embeddings (e.g., mapping *"feeling isolated"* to *"disconnected"*).
  2. **Temporal Retrieval:** Grouping events that occurred within the same timeframe.
  3. **Graph-Traversal Retrieval:** Cypher-based querying of emotional/thematic clusters in Neo4j.


---

## 🛠️ The Technology Stack

| Layer | Technology Used | Hackathon Pitch Value |
| :--- | :--- | :--- |
| **Mobile Client** | Flutter, CustomPainter, EventChannels | Cross-platform, fluid glassmorphic UI, native system channel access. |
| **Database** | Neo4j (Cypher) + PostgreSQL | Graph relationships + transactional audit logs for agentic state. |
| **Orchestration** | TypeScript / Node.js | Fast, type-safe event buses and WebSocket streams. |
| **AI / NLP** | Whisper (Speech-to-Text), LLM (Groq / Ollama) | Fast transcription + agentic reasoning at the edge or locally. |
| **Routing** | OSRM (Open Source Routing Machine) | Independent, offline-capable travel time estimation. |

---

## 🎯 Judges Q&A Response Matrix (The Q&A Hack)

Map the judges' questions to our **Wow Factors** to command the Q&A session:

| If the Judge Asks... | Map it to this Feature | The Winning Pitch Response |
| :--- | :--- | :--- |
| **"How is this different from a calendar app or a basic notification alert?"** | **Digital Twin & Futures Engine** | "Traditional calendars are static tables of time. Pulse is a **living behavioral model**. We don't just tell you that you have an event; we continuously simulate your travel time, battery decay, and cognitive load 2 hours into the future, and actively coordinate with system settings (like Battery Saver) to rescue your commute." |
| **"LLMs hallucinate and can be slow. How do you guarantee system reliability?"** | **Guardian Agent & Audit Pipeline** | "We enforce a strict **OpenClaw-compliant, layered architecture**. The LLM never writes directly to databases or initiates system actions. It only *proposes* decisions. A deterministic **Guardian Agent** checks these proposals against safety rules. Furthermore, all agent evaluations are logged in our `heartbeat_audit` database for complete transparency." |
| **"How does the user interface prevent cognitive overload?"** | **Futures Engine (Stress Score) & Galaxy UI** | "We summarize complex multi-agent analysis into a single, clean **Stress Score (0 to 1)**. In addition, the **LifeCanvas Galaxy view** represents memories as orbiting nodes, allowing users to intuitively grasp how their career, relationships, and habits interact without reading dense tables of text." |
| **"How does the app scale? What happens when a user has years of data?"** | **Memory Hierarchy & Hybrid Retrieval** | "We don't query raw logs. We process them into a multi-layer hierarchy: **Raw Logs ➔ Events ➔ Themes ➔ Identity Arcs ➔ Life Epochs**. As the dataset grows, old data is summarized and stored in Neo4j as high-level preferences or memory clusters. This keeps vector similarity searches fast and keeps database operations highly performant." |
| **"What is the privacy story here? This app tracks everything."** | **Edge Deployment & Local Models** | "Privacy is core to our architecture. Pulse is designed to support **Ollama local models** running on-device or on a personal private server. Since our context normalization and risk calculation are deterministic and run on the device/local server, user location and sensitive raw calendars never need to be uploaded to commercial third-party cloud providers." |

---

## ⏱️ The 10-Minute Presentation Outline

1. **Minutes 0–2 (The Problem):** Present the chaos of modern life—disjointed apps, dead batteries, missed alerts. Explain why static tools fail.
2. **Minutes 2–4 (The Solution - Pulse):** Show the Flutter app. Demonstrate the central dashboard, the live Stress Index, and highlight the **5-Agent Swarm** working behind the scenes.
3. **Minutes 4–6 (The Futures Engine):** Walk through a live "Commute Rescue" scenario. Show the **A/B/C Future trajectories** simulation in real time.
4. **Minutes 6–8 (LifeCanvas):** Showcase the **Galaxy Neural Network**. Record a quick voice note, watch the transcription, and show how the LLM extracts and links it to existing memory clusters.
5. **Minutes 8–10 (Architecture & Scale):** Show the Neo4j Digital Twin graph schema and explain the OpenClaw deterministic safety pipeline. Close strong!
