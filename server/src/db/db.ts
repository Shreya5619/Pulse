import { Pool } from "pg";
import dotenv from "dotenv";

dotenv.config();

const pool = new Pool({
    user: process.env.DB_USER || "pulse_user",
    host: process.env.DB_HOST || "localhost",
    database: process.env.DB_NAME || "pulse_db",
    password: process.env.DB_PASSWORD || "pulse_password",
    port: Number(process.env.DB_PORT || 5432),
});

export const query = (text: string, params?: any[]) => pool.query(text, params);

export default pool;
