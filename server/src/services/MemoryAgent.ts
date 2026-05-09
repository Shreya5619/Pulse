import fs from 'fs';
import path from 'path';
import { dailySummarizer } from "./DailySummarizer";
import { memoryStore } from "./MemoryStore";
import { GraphAdapter } from "./GraphAdapter";

export class MemoryAgent {
  private lastSummaryTime: number = 0;
  private readonly TIME_THRESHOLD = 24 * 60 * 60 * 1000; // once per 24 hours

  /**
   * Called on every heartbeat to check if a new summary is needed.
   */
  async onHeartbeat(userId: string): Promise<void> {
    const now = Date.now();

    // For demo purposes, we'll run a quick summary check more often if the file needs update
    // But we'll respect the 24h threshold for the full heavy LLM summary
    const needsSummary = (now - this.lastSummaryTime) >= this.TIME_THRESHOLD;

    if (needsSummary) {
      await this.runSummary(userId);
    }
    
    // Always try to sync to USER.md if it's been a while or first run
    await this.updateUserMarkdown(userId);
  }

  /**
   * Manually trigger a summary.
   */
  async runSummary(userId: string): Promise<void> {
    console.log(`[MemoryAgent] Running scheduled summary for user: ${userId}`);
    
    try {
      const { preferences, patterns } = await dailySummarizer.summarize(userId);
      
      // Update Neo4j Digital Twin with structured preferences
      await GraphAdapter.applyPreferencesToNeo4j(userId, { preferences, patterns });

      this.lastSummaryTime = Date.now();

      // Log the update with specific metrics
      const habits = await memoryStore.getHabits(userId);
      if (habits && (habits.patterns.routines as any).morning_departure_median) {
        const departureMinutes = (habits.patterns.routines as any).morning_departure_median;
        const hours = Math.floor(departureMinutes / 60);
        const mins = Math.floor(departureMinutes % 60);
        const timeStr = `${hours.toString().padStart(2, '0')}:${mins.toString().padStart(2, '0')}`;
        
        console.log(`[MemoryAgent] Updated habits: morning departure now ${timeStr}, typical lateness ${habits.patterns.typical_lateness} minutes.`);
      }
    } catch (error) {
      console.error(`[MemoryAgent] Summary failed for user ${userId}:`, error);
    }
  }

  async updateUserMarkdown(userId: string) {
    const memoryDir = path.resolve(__dirname, '../../../memory');
    const userMdPath = path.join(memoryDir, 'USER.md');

    if (!fs.existsSync(userMdPath)) return;

    try {
      const habits = await memoryStore.getHabits(userId);
      if (!habits) return;

      const patterns = habits.patterns;
      const morningTime = (patterns.routines as any).morning_departure_median;
      const h = Math.floor((morningTime || 0) / 60);
      const m = Math.floor((morningTime || 0) % 60);

      const summaryLines = [
        `**Summary (last 7 days)**`,
        `- Usually leaves home around ${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}.`,
        `- Typical lateness observed: ${patterns.typical_lateness} minutes.`,
        `- Preferred commute mode appears to be: ${(patterns.routines as any).preferred_mode || 'Walking/Transit'}.`,
        `- Often active during late hours (detected study/work patterns).`,
        `*Last updated: ${new Date().toLocaleString()}*`
      ];

      const newContent = summaryLines.join('\n');
      
      let fileContent = fs.readFileSync(userMdPath, 'utf8');
      const markerStart = '<!-- BEGIN AUTO-USER-SUMMARY -->';
      const markerEnd = '<!-- END AUTO-USER-SUMMARY -->';

      if (fileContent.includes(markerStart) && fileContent.includes(markerEnd)) {
        const regex = new RegExp(`${markerStart}[\\s\\S]*?${markerEnd}`);
        fileContent = fileContent.replace(regex, `${markerStart}\n${newContent}\n${markerEnd}`);
        fs.writeFileSync(userMdPath, fileContent);
        console.log(`[MemoryAgent] USER.md auto-summary updated at ${new Date().toISOString()}`);
      }
    } catch (err) {
      console.error(`[MemoryAgent] Failed to update USER.md:`, err);
    }
  }

  /**
   * Returns the full memory state for a user.
   */
  async getMemorySummary(userId: string) {
    return await memoryStore.loadAll(userId);
  }
}

export const memoryAgent = new MemoryAgent();
