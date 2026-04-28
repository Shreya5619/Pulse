# Planner Agent

The **Planner Agent** is the decision-making core of the Pulse system. It bridges the gap between situational awareness (Risks & Futures) and system intervention (Guardian & Notifications).

## Core Responsibilities

1.  **Contextual Synthesis**: Orchestrates calls to the `RiskEngine`, `FuturesEngine`, and `MemoryStore` to build a complete picture of the user's current and projected state.
2.  **Intervention Generation**: Translates identified risks (e.g., high lateness probability) into a set of actionable `PlannerAction` candidates.
3.  **Prioritization**: Uses a deterministic weighting system to pick the "best" single intervention to propose to the user.
4.  **Transparency**: Provides the "Why" behind every recommendation, including contributing risk factors and potential side effects.

## The Planning Loop

The Planner follows a 4-step execution model during every heartbeat tick:

### 1. Assessment
It gathers three inputs:
*   **Risk Snapshot**: Current scores for Lateness, Battery, Overload, and Response Debt.
*   **Futures Result**: Simulated projections (e.g., "What happens if I charge for 15 minutes?").
*   **User Memory**: Historical habits, preferred buffers, and previous intervention feedback.

### 2. Candidate Building
If a risk score exceeds a threshold (default `0.6`), a candidate action is generated:
*   **ACTION_LEAVE_NOW**: Triggered by high Lateness risk.
*   **ACTION_ENABLE_BATTERY_SAVER**: Triggered by low Battery projection.
*   **ACTION_SUPPRESS_NOISY_NOTIFICATIONS**: Triggered by high Overload score.
*   **ACTION_RECOMMEND_CHARGING_STOP**: Triggered by specific Alternate Futures.

### 3. Selection (The "Chosen" One)
The agent applies a priority hierarchy to ensure the most critical issues are addressed first:
1.  **Lateness** (Physical attendance is high stakes)
2.  **Battery** (Device death is a total loss of guardian)
3.  **Focus/Overload** (Cognitive load management)
4.  **Communication** (Response debt management)

### 4. Broadcast
The final `PlannerDecision` is broadcast via the `planner.suggested` WebSocket event and passed to the **Guardian Agent** for safety validation.

## API Integration

*   **WebSocket**: Emits `planner.suggested` with the full decision payload.
*   **REST API**: `GET /api/planner/decision?userId={id}` returns the current candidate list and chosen action for debugging and evaluation.

## Determinism & Replay
The Planner is designed to be deterministic. Given the same Risk/Future inputs, it will always pick the same action. this ensures that the **Scenario Player** (Screen 6) provides a reproducible "time-travel" experience for evaluation.
