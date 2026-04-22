# Heartbeat Loop Rules

## Cycle Configuration
- **Standard Interval**: 300 seconds (5 minutes).
- **High Alert Interval**: 30 seconds (triggered when risk > 0.7).

## Termination Criteria
- No upcoming events for 6+ hours.
- User toggles "Off-Duty" mode.

## Event Sequence
1. `heartbeat.tick`
2. `context.updated`
3. `risk.updated`
4. `planner.suggested`
5. `guardian.decided`
6. `intervention.created` (if approved)
