import pool from "../../db/db";

export class LifeGraphBuilder {
    async getLifeTree(userId: string) {
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
    }
}

export const lifeGraphBuilder = new LifeGraphBuilder();
