import pool from "./db";

async function initDb() {
    try {
        console.log("Checking database tables...");
        
        const createTableSql = `
            CREATE TABLE IF NOT EXISTS context_snapshots (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                timestamp TIMESTAMPTZ NOT NULL,
                payload JSONB NOT NULL,
                minutes_to_next_event INTEGER,
                has_next_event BOOLEAN
            );
            
            CREATE INDEX IF NOT EXISTS idx_snapshots_user_timestamp ON context_snapshots(user_id, timestamp DESC);
        `;

        await pool.query(createTableSql);
        console.log("Database initialized successfully: 'context_snapshots' table ready.");
        
        process.exit(0);
    } catch (error) {
        console.error("Failed to initialize database:", error);
        process.exit(1);
    }
}

initDb();
