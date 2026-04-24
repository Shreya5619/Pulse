import { contextSnapshotRepo } from "../server/src/db/ContextSnapshotRepository";
import pool from "../server/src/db/db";

async function inspect(userId: string) {
    console.log(`🔍 Inspecting latest snapshot for user: ${userId}`);
    
    try {
        const latest = await contextSnapshotRepo.findLatestByUser(userId);
        
        if (!latest) {
            console.log("⚠️ No snapshots found.");
        } else {
            console.log(JSON.stringify(latest, null, 2));
            console.log("\n--- Summary ---");
            console.log(`ID: ${latest.id}`);
            console.log(`Timestamp: ${latest.timestamp}`);
            console.log(`Derived Commute: ${latest.derived?.is_commute_window}`);
            console.log(`Battery Band: ${latest.derived?.battery_band}`);
        }
    } catch (error) {
        console.error("❌ Inspection failed:", error);
    } finally {
        await pool.end();
    }
}

const userId = process.argv[2] || "user_123";
inspect(userId);
