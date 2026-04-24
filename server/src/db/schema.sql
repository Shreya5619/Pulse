-- Pulse Database Schema

CREATE TABLE IF NOT EXISTS context_snapshots (
    id UUID PRIMARY KEY,
    user_id TEXT NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    payload JSONB NOT NULL,
    minutes_to_next_event INTEGER,
    has_next_event BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_snapshots_user_id ON context_snapshots(user_id);
CREATE INDEX IF NOT EXISTS idx_snapshots_timestamp ON context_snapshots(timestamp);
CREATE INDEX IF NOT EXISTS idx_snapshots_minutes_to_event ON context_snapshots(minutes_to_next_event);

-- Composite index for latest snapshot lookup
CREATE INDEX IF NOT EXISTS idx_snapshots_user_timestamp ON context_snapshots(user_id, timestamp DESC);
