# Pulse Graph Engine

The Pulse Graph Engine is the core modeling layer of the system. It transforms raw context snapshots and historical memory into a **Dynamic Constraint Graph**, which is then used by the Agent Swarm to identify risks and interventions.

## 1. Graph Structure

The graph is a directed, weighted graph that models the relationships between the user's current state, their obligations, and their environment.

### Node Types
| Type | Description |
| :--- | :--- |
| `NOW` | The current temporal reference point. |
| `PLACE` | A physical location (Home, Office, Lab). |
| `APPOINTMENT` | A scheduled event with a start/end time. |
| `BATTERY_STATE` | The current energy status of the device. |
| `MESSAGE_OBLIGATION` | A pending notification or communication debt. |

### Edge Types
| Type | From → To | Weight | Description |
| :--- | :--- | :--- | :--- |
| `TRAVEL` | `PLACE` → `APP` | Minutes | Time required to reach the destination (via OSRM). |
| `URGENCY` | `NOW` → `APP` | Minutes | Time remaining until the event starts. |
| `ENERGY_COST` | `NOW` → `BATTERY` | Factor | Estimated battery drain risk. |
| `INTERRUPTION` | `NOW` → `MSG` | Factor | Cognitive load from pending notifications. |

---

## 2. Intelligence Layer: Heuristic Scoring

After the graph is built, the `GraphBuilder` calculates **Risk Scores** (0.0 to 1.0) for each node based on its connected edges and historical memory.

- **Lateness Score**: Calculated by comparing `TRAVEL` weight + `bufferMinutes` (from memory) against the `URGENCY` weight.
- **Battery Score**: Derived from the current battery band and the historical drain rate stored in memory.
- **Overload Score**: Calculated based on overlapping appointments and high notification volume.
- **Response Debt**: Scaled by the importance of the sender and the age of the notification.

---

## 3. API Endpoints

The Graph Engine exposes the following endpoints under `/api/graph/`:

### 3.1 Graph Summary
Returns the top 3 most critical risks identified in the next 90 minutes.
- **URL**: `GET /api/graph/summary`
- **Headers**: `X-User-Id`
- **Response**:
  ```json
  {
    "ok": true,
    "data": {
      "totalRisksNext90Min": 1,
      "risks": [
        {
          "type": "lateness",
          "score": 0.84,
          "nodeId": "APP_event_lab",
          "label": "Likely late for Physics Lab",
          "occursAt": "2026-04-26T21:25:00Z"
        }
      ]
    }
  }
  ```

### 3.2 Full Graph Data
Returns the complete list of nodes and edges for visualization or debugging.
- **URL**: `GET /api/graph/full`
- **Headers**: `X-User-Id`

---

## 4. Performance & Caching
- **Rebuilding**: The graph is automatically rebuilt whenever a new `context.updated` event occurs.
- **Caching**: The `GraphBuilder` maintains an in-memory cache of the latest graph for each user to ensure fast retrieval by the UI.

---

## 5. Integration with OSRM
The `GraphBuilder` uses the `RoutingService` to dynamically update `TRAVEL` edge weights. This ensures that the graph reflects real-world traffic and distance constraints rather than static estimates.
