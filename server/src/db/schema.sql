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

-- Planner Decisions — historical log of agent recommendations
CREATE TABLE IF NOT EXISTS planner_decisions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    chosen_id TEXT,
    chosen_title TEXT,
    alternatives JSONB NOT NULL DEFAULT '[]'::jsonb,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_planner_decisions_user ON planner_decisions(user_id);
CREATE INDEX IF NOT EXISTS idx_planner_decisions_user_ts ON planner_decisions(user_id, timestamp DESC);

-- Heartbeat Audit — full trace of every agent pipeline execution
CREATE TABLE IF NOT EXISTS heartbeat_audit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    finished_at TIMESTAMPTZ NOT NULL,
    context_id UUID,
    risk_snapshot JSONB,
    futures_result JSONB,
    planner_decision JSONB,
    guardian_decision JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_heartbeat_audit_user ON heartbeat_audit(user_id);
-- Routine Blocks
CREATE TABLE IF NOT EXISTS routines (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    title TEXT NOT NULL,
    start_time TEXT NOT NULL, -- HH:mm
    end_time TEXT NOT NULL,   -- HH:mm
    category TEXT NOT NULL,
    days INTEGER[] NOT NULL,
    start_location JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_routines_user ON routines(user_id);

-- Manual Events
CREATE TABLE IF NOT EXISTS manual_events (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_manual_events_user ON manual_events(user_id);

-- Event Overrides
CREATE TABLE IF NOT EXISTS event_overrides (
    user_id TEXT NOT NULL,
    event_id TEXT NOT NULL,
    updates JSONB NOT NULL,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, event_id)
);

CREATE INDEX IF NOT EXISTS idx_overrides_user ON event_overrides(user_id);
