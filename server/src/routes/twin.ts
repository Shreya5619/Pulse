import { Router } from 'express';
import { GraphAdapter } from '../services/GraphAdapter';

const router = Router();

/**
 * GET /api/twin/graph
 * Returns a subgraph for the Digital Twin visualization.
 */
router.get('/graph', async (req, res) => {
  const userId = (req.query.userId as string) || 'user1';
  const horizon = req.query.horizon ? parseInt(req.query.horizon as string) : 240;

  try {
    const graph = await GraphAdapter.getTwinSubgraph(userId, horizon);
    res.json(graph);
  } catch (error) {
    console.error('[Twin Route] Error fetching graph:', error);
    res.status(500).json({ error: 'Failed to fetch digital twin graph' });
  }
});

export default router;
