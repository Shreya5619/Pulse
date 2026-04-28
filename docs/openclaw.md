# OpenClaw Compliance & Agentic Architecture

Pulse follows the **OpenClaw** principles for building deterministic, auditable, and multi-agent systems. This document outlines how our architecture maps to these patterns.

## 1. Deterministic Pipeline

OpenClaw emphasizes a "clear state at each step." Our `HeartbeatOrchestrator` implements this by executing agents in a strict, sequential order:

1.  **Context Agent**: Normalizes raw device/calendar signals into a coherent world state.
2.  **Memory Agent**: Retrieves long-term patterns and recent episodes.
3.  **Graph Builder**: Construct a semantic relationship graph of the user's upcoming 4 hours.
4.  **Risk Agent**: Quantifies failure probability (Lateness, Battery, Overload).
5.  **Futures Engine**: Simulates "What-If" scenarios to find optimal risk-reduction paths.
6.  **Planner Agent**: Proposes ranked interventions based on risk/future data.
7.  **Guardian Agent**: Validates safety and decides on the approval mode (AUTO/ASK/BLOCK).

## 2. Structured Agent Contracts

Every agent in the Pulse swarm adheres to a single-responsibility contract:

*   **Input**: Explicit JSON payload (e.g., `userId`, `context`, or previous agent's `Decision`).
*   **Process**: Pure logic (or service delegation) without side-effects on the global orchestrator.
*   **Output**: Structured JSON objects (e.g., `RiskSnapshot`, `PlannerDecision`) documented in our [API Contracts](api-contracts.md).

## 3. Observability & Auditability

We maintain a full execution trace for every heartbeat cycle in the `heartbeat_audit` table. This record includes:
*   `started_at` / `finished_at` timestamps.
*   The exact `RiskSnapshot` produced.
*   The `FuturesResult` simulation data.
*   The `PlannerDecision` and the final `Guardian` safety determination.

This audit log allows for "Time-Travel Debugging" and retrospective evaluation of agent performance.

## 4. Replay-First Design

Because every agent is a pure function of its inputs, we can perform high-fidelity simulation and replay. The **Scenario Player** in the mobile app uses these exact same agent logic paths to replay historical logs, ensuring that "Replay is Reality."

## 5. Soul & Personality

The system's behavior and tone are governed by `data/openclaw/SOUL.md`, which defines the "Pulse Guardian" persona: proactive, calm, and safety-first.
