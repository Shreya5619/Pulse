import pool from "../../db/db";
import * as fs from "fs";
import * as path from "path";

// Resolve the db/ folder from the server root whether running via tsx (src/) or compiled (dist/)
const SERVER_ROOT = path.resolve(__dirname, "../../..");
const JSON_STORE_PATH = path.join(SERVER_ROOT, "db", "lifecanvas_store.json");

function loadJsonStore() {
    if (!fs.existsSync(JSON_STORE_PATH)) {
        return {
            events: [],
            nodes: [
                { id: 1, user_id: "demo-user", type: "THEME", label: "AI", importance: 0.8, metadata: {}, created_at: new Date().toISOString() },
                { id: 2, user_id: "demo-user", type: "THEME", label: "Systems", importance: 0.7, metadata: {}, created_at: new Date().toISOString() },
                { id: 3, user_id: "demo-user", type: "THEME", label: "Health", importance: 0.6, metadata: {}, created_at: new Date().toISOString() },
                { id: 4, user_id: "demo-user", type: "THEME", label: "Relationships", importance: 0.7, metadata: {}, created_at: new Date().toISOString() }
            ],
            edges: []
        };
    }
    try {
        return JSON.parse(fs.readFileSync(JSON_STORE_PATH, "utf-8"));
    } catch (_) {
        return { events: [], nodes: [], edges: [] };
    }
}

export class LifeGraphBuilder {
    async getLifeTree(userId: string) {
        try {
            const res = await pool.query(
                `SELECT * FROM life_graph_nodes WHERE user_id = $1 ORDER BY created_at DESC LIMIT 100`,
                [userId]
            );
            const nodes = res.rows;

            const edgesRes = await pool.query(
                `SELECT * FROM life_graph_edges WHERE user_id = $1`,
                [userId]
            );
            const edges = edgesRes.rows;

            return { nodes, edges };
        } catch (dbErr) {
            console.warn("[LifeGraphBuilder] PostgreSQL down. Returning local JSON store.");
            const store = loadJsonStore();
            const nodes = store.nodes.filter((n: any) => n.user_id === userId);
            const edges = store.edges.filter((e: any) => e.user_id === userId);
            return { nodes, edges };
        }
    }
}

export const lifeGraphBuilder = new LifeGraphBuilder();
