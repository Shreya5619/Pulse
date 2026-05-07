# Agents

## ContextAgent
- Input: ContextSnapshot
- Output: Updates to the digital twin graph / DB
- Responsibility: Normalize raw device context into structured state.

## MemoryAgent
- Input: userId, recent context + actions
- Output: behavior profile, preferences, USER.md summary
- Responsibility: Learn habits and update user profile.

## RiskAgent
- Input: Digital Twin Graph
- Output: Scored Risk list
- Responsibility: Identify potential bottlenecks and safety issues.

## FuturesAgent
- Input: Current risks + Schedule
- Output: Predicted future states (90-min horizon)
- Responsibility: Forecast if current trajectory leads to high-risk states.

## PlannerAgent
- Input: Risks + Forecasts + Preferences
- Output: Possible intervention strategies (A/B/C)
- Responsibility: Determine the best path forward to mitigate risk.

## GuardianAgent
- Input: Planner strategies + Heartbeat Config
- Output: Execution of safe actions or "Ask" prompts
- Responsibility: Enforce safety rules and execute system-level interventions.

## ChatAgent
- Input: User query + Digital Twin context
- Output: Natural language response + Suggested Actions
- Responsibility: Provide a human-like interface for interacting with the twin.

## Call Graph
ContextAgent → MemoryAgent → RiskAgent → FuturesAgent → PlannerAgent → GuardianAgent → ChatAgent (when user interacts)
