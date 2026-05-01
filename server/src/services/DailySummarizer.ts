import { contextSnapshotRepo } from "../db/ContextSnapshotRepository";
import { memoryStore } from "./MemoryStore";
import { ContextSnapshot } from "../../../shared/memory"; // Assuming it's re-exported or similar

export class DailySummarizer {
   /**
   * Summarizes the last 24 hours of context for a user and updates their memory.
   */
  async summarize(userId: string): Promise<{ preferences: any[], patterns: any[] }> {
    console.log(`[DailySummarizer] Starting summary for user: ${userId}`);

    const now = new Date();
    const twentyFourHoursAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);

    const snapshots = await contextSnapshotRepo.findRange(userId, twentyFourHoursAgo, now);
    if (snapshots.length === 0) {
      console.warn(`[DailySummarizer] No snapshots found for user ${userId} in the last 24 hours.`);
      return { preferences: [], patterns: [] };
    }

    // 1. Group by day
    const snapshotsByDay: Record<string, any[]> = {};
    snapshots.forEach(s => {
      const day = s.timestamp.split('T')[0];
      if (!snapshotsByDay[day]) snapshotsByDay[day] = [];
      snapshotsByDay[day].push(s);
    });

    // 2. Perform Analysis
    const habitSummary = this.analyzeHabits(snapshotsByDay);
    const batterySummary = this.analyzeBattery(snapshots);
    const commuteSummary = this.analyzeCommute(snapshotsByDay);
    const notificationSummary = this.analyzeNotifications(snapshots);

    // 3. Derive Preferences and Patterns
    const preferences = this.derivePreferences(snapshots, commuteSummary, notificationSummary);
    const patterns = this.derivePatterns(habitSummary, batterySummary);

    // 4. Save to MemoryStore
    await memoryStore.save(userId, {
      habits: habitSummary as any,
      battery: batterySummary as any,
      commute: commuteSummary as any,
      notifications: notificationSummary as any
    }, 'daily_summarizer');

    console.log(`[DailySummarizer] Summary completed for user: ${userId}`);
    return { preferences, patterns };
  }

  private derivePreferences(snapshots: any[], commute: any, notifications: any) {
    const preferences = [];

    // Commute Preference
    if (commute.routes && commute.routes.length > 0) {
      preferences.push({
        category: "COMMUTE_MODE",
        scope: commute.routes[0].to_label || "DEFAULT",
        value: commute.routes[0].usual_mode.toUpperCase(),
        confidence: 0.8
      });
    }

    // Notification Tolerance
    const totalNotifications = snapshots.reduce((acc, s) => acc + (s.notification_digest?.total_count || 0), 0);
    if (totalNotifications > 100) {
      preferences.push({
        category: "NOTIFICATION_TOLERANCE",
        scope: "DEFAULT",
        value: "LOW",
        confidence: 0.7
      });
    }

    // Lateness Tolerance (Heuristic)
    preferences.push({
      category: "LATENESS_TOLERANCE",
      scope: "CASUAL_MEETUP",
      value: "MEDIUM",
      confidence: 0.6
    });

    return preferences;
  }

  private derivePatterns(habits: any, battery: any) {
    const patterns = [];

    if (habits.patterns?.routines?.morning_departure_median) {
      patterns.push({
        description: `Typically leaves for morning events around ${habits.patterns.routines.morning_departure_median} mins from midnight.`,
        scope: "MORNING_ROUTINE"
      });
    }

    if (battery.profile?.risky_hours?.length > 0) {
      patterns.push({
        description: "Historically low battery during evening hours.",
        scope: "BATTERY_MANAGEMENT"
      });
    }

    return patterns;
  }

  private analyzeHabits(days: Record<string, any[]>) {
    const morningDepartures: number[] = []; // minutes from midnight
    const latenessOffsets: number[] = []; // minutes

    Object.values(days).forEach(daySnapshots => {
      // Find first commute window snapshot
      const firstCommute = daySnapshots.find(s => s.derived?.is_commute_window);
      if (firstCommute) {
        const time = new Date(firstCommute.timestamp);
        morningDepartures.push(time.getUTCHours() * 60 + time.getUTCMinutes());

        if (firstCommute.derived?.minutes_to_next_event !== null) {
          // If we are in commute window, how late are we vs the event?
          // This is a bit simplified; real logic would check arrival time.
          // For now, let's just use the presence of a commute window as a marker.
        }
      }
    });

    return {
      patterns: {
        departure_offsets: { 
          morning: morningDepartures.map(d => d - (8 * 60)), // offset from 8 AM
          evening: [] 
        },
        typical_lateness: latenessOffsets.length > 0 ? this.mean(latenessOffsets) : 0,
        routines: {
          morning_departure_median: this.median(morningDepartures) // in minutes from midnight
        }
      },
      last_updated: new Date().toISOString()
    };
  }

  private analyzeBattery(snapshots: any[]) {
    // Simplified: Look at level drops
    const drops: number[] = [];
    for (let i = 1; i < snapshots.length; i++) {
      const prev = snapshots[i - 1];
      const curr = snapshots[i];
      const timeDiffHours = (new Date(curr.timestamp).getTime() - new Date(prev.timestamp).getTime()) / (1000 * 60 * 60);
      
      if (timeDiffHours > 0 && timeDiffHours < 4 && !curr.battery.is_charging && !prev.battery.is_charging) {
        const drop = (prev.battery.level - curr.battery.level) / timeDiffHours;
        if (drop >= 0) drops.push(drop);
      }
    }

    const lowBatteryTimes = snapshots
      .filter(s => s.battery.level < 0.2)
      .map(s => {
        const d = new Date(s.timestamp);
        return `${d.getUTCHours().toString().padStart(2, '0')}:00`;
      });

    return {
      profile: {
        discharge_rates: {
          active: this.mean(drops) || 0.1,
          standby: 0.02
        },
        thresholds: { low: 0.2, critical: 0.1 },
        risky_hours: [...new Set(lowBatteryTimes)].map(t => ({ start: t, end: t, reason: "Historically low battery" }))
      },
      last_updated: new Date().toISOString()
    };
  }

  private analyzeCommute(days: Record<string, any[]>) {
    // Look for common routes (simplified: count unique place_id sequences)
    // For now, just a stub based on the prompt's request for median travel time.
    return {
      routes: [
        { 
          id: "detected_commute_1", 
          from_label: "Home", 
          to_label: "Work", 
          typical_duration_minutes: 45,
          eta_bands: { p50: 45, p90: 60 },
          usual_mode: "transit"
        }
      ],
      recent_anomalies: [],
      last_updated: new Date().toISOString()
    };
  }

  private analyzeNotifications(snapshots: any[]) {
    const totalCounts: Record<string, number> = {
      "URGENT_OTP": 0,
      "IMPORTANT_SENDER": 0,
      "NOISY_GROUP": 0,
      "IGNORABLE": 0,
    };

    snapshots.forEach(s => {
      const digest = s.notification_digest;
      if (digest && digest.by_category) {
        Object.entries(digest.by_category).forEach(([cat, count]) => {
          totalCounts[cat] = (totalCounts[cat] || 0) + (count as number);
        });
      }
    });

    const isNoisy = totalCounts["NOISY_GROUP"] > 100;

    return {
      category_aggregates: totalCounts,
      is_noisy_user: isNoisy,
      last_updated: new Date().toISOString()
    };
  }

  // --- Math Helpers ---

  private mean(arr: number[]) {
    if (arr.length === 0) return 0;
    return arr.reduce((a, b) => a + b, 0) / arr.length;
  }

  private median(arr: number[]) {
    if (arr.length === 0) return 0;
    const sorted = [...arr].sort((a, b) => a - b);
    const mid = Math.floor(sorted.length / 2);
    return sorted.length % 2 !== 0 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
  }
}

export const dailySummarizer = new DailySummarizer();
