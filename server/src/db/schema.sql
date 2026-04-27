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
-- Memory Tables
CREATE TABLE IF NOT EXISTS memory_identity (
    user_id TEXT PRIMARY KEY,
    data JSONB NOT NULL,
    schema_version INTEGER DEFAULT 1,
    last_updated TIMESTAMPTZ DEFAULT NOW(),
    source TEXT
);

CREATE TABLE IF NOT EXISTS memory_habits (
    user_id TEXT PRIMARY KEY,
    data JSONB NOT NULL,
    schema_version INTEGER DEFAULT 1,
    last_updated TIMESTAMPTZ DEFAULT NOW(),
    source TEXT
);

CREATE TABLE IF NOT EXISTS memory_battery (
    user_id TEXT PRIMARY KEY,
    data JSONB NOT NULL,
    schema_version INTEGER DEFAULT 1,
    last_updated TIMESTAMPTZ DEFAULT NOW(),
    source TEXT
);

CREATE TABLE IF NOT EXISTS memory_notifications (
    user_id TEXT PRIMARY KEY,
    data JSONB NOT NULL,
    schema_version INTEGER DEFAULT 1,
    last_updated TIMESTAMPTZ DEFAULT NOW(),
    source TEXT
);

CREATE TABLE IF NOT EXISTS memory_commute (
    user_id TEXT PRIMARY KEY,
    data JSONB NOT NULL,
    schema_version INTEGER DEFAULT 1,
    last_updated TIMESTAMPTZ DEFAULT NOW(),
    source TEXT
);

-- Risk Snapshots — point-in-time risk assessments
CREATE TABLE IF NOT EXISTS risk_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    top_score REAL NOT NULL DEFAULT 0,
    risk_count INTEGER NOT NULL DEFAULT 0,
    risks JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_risk_snapshots_user ON risk_snapshots(user_id);
CREATE INDEX IF NOT EXISTS idx_risk_snapshots_user_ts ON risk_snapshots(user_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_risk_snapshots_top_score ON risk_snapshots(top_score DESC);
