import { Router } from 'express';
import { GraphAdapter } from '../services/GraphAdapter';
import { queryGroq } from '../utils/llm';

const router = Router();

/**
 * GET /api/twin/graph
 * Returns a subgraph for the Digital Twin visualization.
 */
router.get('/graph', async (req, res) => {
  const userId = req.header("X-User-Id") || (req.query.userId as string) || (req.query.deviceId as string) || 'user1';
  const horizon = req.query.horizon ? parseInt(req.query.horizon as string) : 240;

  try {
    const graph = await GraphAdapter.getTwinSubgraph(userId, horizon);
    res.json(graph);
  } catch (error) {
    console.error('[Twin Route] Error fetching graph:', error);
    res.status(500).json({ error: 'Failed to fetch digital twin graph' });
  }
});

/**
 * GET /api/twin/summary
 * Returns an LLM summary of the Digital Twin.
 */
router.get('/summary', async (req, res) => {
  const userId = req.header("X-User-Id") || (req.query.userId as string) || (req.query.deviceId as string) || 'user1';

  try {
    const graph = await GraphAdapter.getTwinSubgraph(userId, 480); // 8h horizon for more context
    
    const prompt = `
      You are the Pulse Digital Twin Analyzer. Below is the structured data of a user's digital twin.
      Summarize this person's current state, personality, and immediate risks in a conversational, insightful way.
      Focus on:
      - Who they are (Traits & Interests)
      - How they are feeling (Sentiment)
      - What they are doing (Upcoming Events)
      - Any immediate concerns (Battery, Risks)
      - Their learned preferences.

      Digital Twin Data:
      ${JSON.stringify(graph, null, 2)}

      Keep the summary concise (2-3 paragraphs), premium, and empathetic. Do not mention "nodes" or "edges".
    `;

    const summary = await queryGroq([
      { role: "system", content: "You are an insightful AI that understands human behavior through graph data." },
      { role: "user", content: prompt }
    ]);

    res.json({ ok: true, data: { summary } });
  } catch (error) {
    console.error('[Twin Route] Error generating summary:', error);
    res.status(500).json({ error: 'Failed to generate digital twin summary' });
  }
});

import { selfReflectionService } from '../services/SelfReflectionService';

/**
 * POST /api/twin/reflect
 * Triggers a self-reflection loop for the digital twin.
 */
router.post('/reflect', async (req, res) => {
  const userId = req.header("X-User-Id") || req.body.userId || 'user1';
  
  try {
    const result = await selfReflectionService.reflect(userId);
    res.json({ ok: true, data: result });
  } catch (error) {
    console.error('[Twin Route] Error during reflection:', error);
    res.status(500).json({ error: 'Failed to perform self-reflection' });
  }
});

export default router;
