import { query } from "../db/db";
import { queryGroq } from "../utils/llm";
import { GraphAdapter } from "./GraphAdapter";
import { contextSnapshotRepo } from "../db/ContextSnapshotRepository";
import fs from 'fs';
import path from 'path';

export class SelfReflectionService {
  async reflect(userId: string) {
    console.log(`[SelfReflection] Starting nightly reflection for ${userId}...`);

    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const now = new Date();

    // 1. Fetch data from last 24h
    const snapshots = await contextSnapshotRepo.findRange(userId, yesterday, now);
    
    const feedbackRes = await query(
      "SELECT * FROM user_feedback WHERE user_id = $1 AND timestamp >= $2",
      [userId, yesterday.toISOString()]
    );
    const feedback = feedbackRes.rows;

    const decisionsRes = await query(
      "SELECT * FROM planner_decisions WHERE user_id = $1 AND timestamp >= $2",
      [userId, yesterday.toISOString()]
    );
    const decisions = decisionsRes.rows;

    // 2. Format data for LLM
    const dataSummary = {
      snapshotCount: snapshots.length,
      averageBattery: snapshots.reduce((acc, s) => acc + (s.battery?.level || 0), 0) / (snapshots.length || 1),
      decisions: decisions.map(d => ({ title: d.chosen_title, time: d.timestamp })),
      feedback: feedback.map(f => ({ actionId: f.action_id, status: f.status, time: f.timestamp })),
      // Filter significant snapshots (e.g. low battery, lateness)
      anomalies: snapshots.filter(s => (s.battery?.level || 1) < 0.2 || (s.derived?.minutes_to_next_event || 0) < 0)
    };

    const prompt = `
      You are Chrona, the Pulse Digital Twin's reflective core. 
      Analyze the user's data from the last 24 hours and perform a self-reflection.
      
      User Data Summary:
      ${JSON.stringify(dataSummary, null, 2)}

      Task 1: Write a short, empathetic daily journal entry (1-2 sentences) starting with "Today you...". 
      Focus on patterns like rushing, charging habits, or notification responsiveness.

      Task 2: Extract or update structured preferences/patterns. 
      Return them in a JSON block with "preferences" (category, scope, value, confidence) and "patterns" (description, scope).
      Example categories: PREF_STUDY_SLOT, PREF_CHARGE_HABIT, PREF_COMMUTE_MODE.

      Response format:
      Journal: <your journal entry here>
      JSON: 
      {
        "preferences": [...],
        "patterns": [...]
      }
    `;

    try {
      const response = await queryGroq([
        { role: "system", content: "You are an insightful AI mentor." },
        { role: "user", content: prompt }
      ]);

      const journalMatch = response.match(/Journal:\s*(.*)/i);
      const jsonMatch = response.match(/JSON:\s*(\{[\s\S]*\})/i);

      if (journalMatch && jsonMatch) {
        const journal = journalMatch[1].trim();
        const extracted = JSON.parse(jsonMatch[1]);

        // 3. Save to Neo4j
        await GraphAdapter.applyPreferencesToNeo4j(userId, extracted);

        // 4. Update USER.md with Journal
        await this.appendJournalToUserMd(userId, journal);

        console.log(`[SelfReflection] Reflection complete for ${userId}. Journal: ${journal}`);
        return { journal, extracted };
      }
    } catch (err) {
      console.error("[SelfReflection] Error during reflection:", err);
    }
  }

  private async appendJournalToUserMd(userId: string, journal: string) {
    const memoryDir = path.resolve(__dirname, '../../../memory');
    const userMdPath = path.join(memoryDir, 'USER.md');

    if (!fs.existsSync(userMdPath)) return;

    try {
      let content = fs.readFileSync(userMdPath, 'utf8');
      const journalSection = `\n### Daily Reflection (${new Date().toLocaleDateString()})\n- ${journal}\n`;
      
      // Append to the end of the file or before Observed Patterns
      if (content.includes('## Observed Patterns')) {
        content = content.replace('## Observed Patterns', `${journalSection}\n## Observed Patterns`);
      } else {
        content += journalSection;
      }

      fs.writeFileSync(userMdPath, content);
    } catch (err) {
      console.error("[SelfReflection] Failed to update USER.md journal:", err);
    }
  }
}

export const selfReflectionService = new SelfReflectionService();
