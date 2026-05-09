import { Pool } from "pg";
import dotenv from "dotenv";

import path from "path";

// Load .env from project root if it exists
dotenv.config({ path: path.resolve(__dirname, "../../../.env") });

const useDatabaseUrl = !!process.env.DATABASE_URL;

const poolConfig: any = useDatabaseUrl
    ? { connectionString: process.env.DATABASE_URL }
    : {
        user: process.env.DB_USER,
        host: process.env.DB_HOST,
        database: process.env.DB_NAME,
        password: process.env.DB_PASSWORD,
        port: Number(process.env.DB_PORT || 5432),
        ssl: process.env.DB_HOST?.includes('railway.internal') ? false : { rejectUnauthorized: false }
    };

// Railway managed DBs often require SSL if connecting from outside, 
// though internal networking usually doesn't. 
// Adding this for robustness when DATABASE_URL is used.
if (useDatabaseUrl && process.env.NODE_ENV === "production") {
    poolConfig.ssl = {
        rejectUnauthorized: false
    };
}

const pool = new Pool(poolConfig);

// Immediate connection test
pool.connect((err, client, release) => {
    if (err) {
        console.error(`[DB] ❌ Connection test failed for host "${poolConfig.host || 'DATABASE_URL'}":`, err.message);
        console.error(`[DB] Tip: If on Railway, ensure your DB service name matches DB_HOST (e.g., 'db.railway.internal' vs 'postgres.railway.internal').`);
    } else {
        console.log(`[DB] ✅ Connection test successful!`);
        release();
    }
});

// Debug log for connection attempts (host only)
const hostInfo = useDatabaseUrl ? "DATABASE_URL" : (process.env.DB_HOST || "localhost");
console.log(`[DB] Initializing connection pool to: ${hostInfo}`);

pool.on('error', (err) => {
    console.error('[DB] Unexpected error on idle client', err);
});



export const query = (text: string, params?: any[]) => pool.query(text, params);

export default pool;