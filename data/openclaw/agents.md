# Pulse Agent Roles

## Context Agent
Normalizes raw signals (GPS, Battery, Calendar) into a structured "World State".
- **Primary Goal**: Truth maintenance.

## Memory Agent
Retrieves historical patterns and user preferences.
- **Primary Goal**: Personalization.

## Risk Agent
Scores likelihood of failure (e.g., Lateness Score: 0.8).
- **Primary Goal**: Prediction.

## Planner Agent
Constructs 1-3 candidate interventions based on risk.
- **Primary Goal**: Problem solving.

## Guardian Agent
Decides how to delivery interventions (Auto-act, Ask, Block).
- **Primary Goal**: UX and Safety Gatekeeping.
