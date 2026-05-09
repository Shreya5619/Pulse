import { Pool } from "pg";
import dotenv from "dotenv";

// Only load .env file in local development
// Railway provides environment variables directly
dotenv.config();

const pool = new Pool({
    user: process.env.DB_USER,
    host: process.env.DB_HOST,
    database: process.env.DB_NAME,
    password: process.env.DB_PASSWORD,
    port: Number(process.env.DB_PORT),
});

export const query = (text: string, params?: any[]) => pool.query(text, params);

export default pool;