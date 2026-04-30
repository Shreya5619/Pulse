# Pulse Digital Twin: Graph-Backed Behavioral Mirror

The Pulse Digital Twin is a real-time, graph-based representation of a user's digital life. It combines live context, historical patterns, and learned preferences into a unified knowledge graph powered by **Neo4j**.

## 1. Architecture Overview

The twin acts as a "behavioral mirror" that persists across heartbeat cycles.

- **Storage**: Neo4j (Bolt/Cypher) for complex relationship mapping.
- **Sync Engine**: `GraphAdapter` on the backend, triggered by every `ContextSnapshot`.
- **Reasoning Layer**: `MemoryAgent` and `DailySummarizer` derive high-level preferences and patterns.
- **Consumption**: Exposes a subgraph API for real-time Flutter visualization.

## 2. Data Model (Ontology)

The graph uses the following node types and relationships:

### Core Entities
- **:Person**: The central node representing the user.
- **:Event**: Calendar appointments with `riskScore`, `startTime`, and `endTime`.
- **:Location**: Physical coordinates and labels (Home, Work, etc.).
- **:BatteryState**: Chronological device state snapshots.
- **:Notification**: Recent pings from various apps.

### Preference Layer
- **:Preference**: Learned behavioral tendencies (e.g., `COMMUTE_MODE=WALK`).
- **:Pattern**: Complex recurring habits (e.g., "Leaves 10 min late for morning classes").

### Key Relationships
- `(:Person)-[:HAS_EVENT]->(:Event)`
- `(:Event)-[:AT_LOCATION]->(:Location)`
- `(:Person)-[:HAS_BATTERY]->(:BatteryState)`
- `(:BatteryState)-[:NEXT]->(:BatteryState)` (Chronological chain)
- `(:Person)-[:HAS_PREFERENCE]->(:Preference)`

## 3. The Preference Layer & Personalization

Unlike a simple database, the Digital Twin learns from user behavior:

1.  **Extraction**: The `DailySummarizer` analyzes the last 24 hours of snapshots and actions.
2.  **Mapping**: It generates structured preferences (e.g., `LATENESS_TOLERANCE=LOW`).
3.  **Risk Personalization**: The `RiskEngine` queries the twin before assessment. If a user has a "LOW" lateness tolerance for a specific event type, the risk score is automatically adjusted higher to trigger earlier alerts.

## 4. API Reference

### `GET /api/twin/graph`
Returns a layout-ready subgraph for visualization.

**Query Params:**
- `userId`: The ID of the user.
- `horizonMinutes` (default: 240): How far into the future to fetch events.

**Response Schema:**
```json
{
  "nodes": [
    { "id": "PERSON_user1", "label": "User", "type": "person", "x": 200, "y": 50, "risk": 0 },
    { "id": "PREF_...", "label": "COMMUTE_MODE: WALK", "type": "preference", "x": 50, "y": 300, "risk": 0 }
  ],
  "edges": [
    { "from": "PERSON_user1", "to": "PREF_...", "type": "HAS_PREFERENCE" }
  ]
}
```

## 5. Mobile Visualization

The Digital Twin is visualized in the mobile app via the **Digital Twin Explorer**:
- **Renderer**: Uses `CustomPainter` for edge connections and a `Stack` of interactive nodes.
- **Color Coding**: Nodes change color based on their real-time `riskScore` (stored in the graph).
- **Live Updates**: Connects via WebSocket to re-fetch data on every `TWIN_UPDATED` broadcast.

---

## Technical Setup (Local)

- **Neo4j Browser**: `http://localhost:7474`
- **Credentials**: `neo4j` / `pulse_guardian`
- **APOC**: Requires the APOC plugin for ID generation (`apoc.util.md5`).
