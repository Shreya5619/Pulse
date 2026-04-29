import { dailySummarizer } from "./DailySummarizer";
import { memoryStore } from "./MemoryStore";

export class MemoryAgent {
  private lastSummaryTime: number = 0;
  private readonly TIME_THRESHOLD = 24 * 60 * 60 * 1000; // once per 24 hours

  /**
   * Called on every heartbeat to check if a new summary is needed.
   */
  async onHeartbeat(userId: string): Promise<void> {
    const now = Date.now();

    // Check if 24 hours have passed since the last summary
    const needsSummary = (now - this.lastSummaryTime) >= this.TIME_THRESHOLD;

    if (needsSummary) {
      await this.runSummary(userId);
    }
  }

  /**
   * Manually trigger a summary.
   */
  async runSummary(userId: string): Promise<void> {
    console.log(`[MemoryAgent] Running scheduled summary for user: ${userId}`);
    
    try {
      await dailySummarizer.summarize(userId);
      this.lastSummaryTime = Date.now();
      this.snapshotCounter = 0;

      // Log the update with specific metrics
      const habits = await memoryStore.getHabits(userId);
      if (habits && habits.patterns.routines.morning_departure_median) {
        const departureMinutes = habits.patterns.routines.morning_departure_median;
        const hours = Math.floor(departureMinutes / 60);
        const mins = Math.floor(departureMinutes % 60);
        const timeStr = `${hours.toString().padStart(2, '0')}:${mins.toString().padStart(2, '0')}`;
        
        console.log(`[MemoryAgent] Updated habits: morning departure now ${timeStr}, typical lateness ${habits.patterns.typical_lateness} minutes.`);
      }
    } catch (error) {
      console.error(`[MemoryAgent] Summary failed for user ${userId}:`, error);
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
