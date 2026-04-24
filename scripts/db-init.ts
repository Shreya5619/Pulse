import fs from "fs";
import path from "path";
import pool from "../server/src/db/db";

async function initDb() {
    console.log("🚀 Initializing Pulse Database...");
    
    const schemaPath = path.join(__dirname, "../server/src/db/schema.sql");
    const schema = fs.readFileSync(schemaPath, "utf8");

    try {
        await pool.query(schema);
        console.log("✅ Database schema applied successfully.");
    } catch (error) {
        console.error("❌ Failed to apply schema:", error);
    } finally {
        await pool.end();
    }
}

initDb();
