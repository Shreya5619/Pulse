import pool from "../server/src/db/db";

async function migrate() {
    console.log("Adding columns to routines table...");
    try {
        await pool.query(`
            ALTER TABLE routines 
            ADD COLUMN IF NOT EXISTS destination_location JSONB,
            ADD COLUMN IF NOT EXISTS eta INTEGER;
        `);
        console.log("Successfully updated routines table.");
    } catch (e) {
        console.error("Migration failed:", e);
    } finally {
        await pool.end();
    }
}

migrate();
