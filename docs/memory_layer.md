# Pulse Memory Layer

The Memory Layer is the long-term "soul" of the Pulse assistant. While **ContextSnapshots** capture the immediate "now", the Memory Layer captures patterns, habits, and preferences that persist across days and weeks.

## Concept Overview
Pulse agents (Risk, Planner, etc.) use memory to ground their decisions. For example, knowing that a user is "usually 5 minutes late to morning meetings" allows the Risk agent to provide more realistic interventions.

The memory is **durable** and **versioned**:
- **Source of Truth**: Postgres DB (for reliability and querying).
- **Inspection Layer**: YAML files in `memory/{userId}/` (for transparency and OpenClaw compliance).

## File Layout & Examples

### `identity.yaml`
Stores static user details and fixed locations.
```yaml
user_id: "user_123"
basics:
  name: "John Doe"
  timezone: "America/New_York"
locations:
  home: { lat: 40.7128, lon: -74.0060, address: "123 Main St" }
  office: { lat: 40.7580, lon: -73.9855, address: "Times Square" }
```

### `habits.yaml`
Tracks behavioral patterns relative to external events.
```yaml
patterns:
  departure_offsets: { morning: [-10, -5], evening: [15] }
  typical_lateness: 3
  routines:
    morning_departure_median: 510 # minutes from midnight
```

### `battery.yaml`
Device-specific energy characteristics.
```yaml
profile:
  discharge_rates: { active: 0.12, standby: 0.02 }
  thresholds: { low: 0.25, critical: 0.15 }
  risky_hours: [{ start: "17:00", end: "20:00" }]
```

## How the Summarizer Works
The **Daily Summarizer Agent** runs periodically (via the Heartbeat) and performs the following logic:
1. **Windowing**: Fetches the last 7 days of raw `ContextSnapshot` rows from Postgres.
2. **Clustering**: Groups snapshots into "sessions" (Morning Commute, Work Block, Evening).
3. **Habit Extraction**: Computes the median departure time for morning commitments based on `is_commute_window` flags.
4. **Energy Modeling**: Calculates the average battery level drop per hour when the device is not charging.
5. **Noise Filtering**: Identifies "noisy" apps by aggregating notification volume per package.
6. **Persistence**: Updates the `MemoryStore`, which atomically writes to Postgres and exports the fresh YAML files.

## Interaction Guidelines
- **Other Agents**: Should **NEVER** write to memory directly. They should use the `MemoryStore` service or call the `MemoryAgent` to trigger updates.
- **Reading**: Use `memoryStore.loadAll(userId)` or specific accessors like `getHabits(userId)`.
- **Primary vs Mirror**: In development, the Filesystem is treated as the primary source for `loadAll`, with Postgres serving as a mirror. In production, this can be toggled to prioritize Postgres.

## Versioning & Metadata
Every memory file contains:
- `schema_version`: Used by migration hooks to handle data shape changes.
- `last_updated`: Timestamp of the last summarization or manual edit.
- `source`: The agent or script that last modified the data (e.g., `daily_summarizer`, `manual_seed`).
