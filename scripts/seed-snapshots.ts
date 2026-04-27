import { contextSnapshotRepo } from "../server/src/db/ContextSnapshotRepository";
import { ContextSnapshot } from "../shared/context_snapshot";
import crypto from "crypto";

async function seedSnapshots() {
  const userId = process.argv[2] || 'user_123';
  console.log(`[Seeder] Seeding snapshots for user: ${userId}`);

  const now = new Date();
  const snapshots: ContextSnapshot[] = [];

  // Generate 20 snapshots per day for the last 7 days
  for (let d = 0; d < 7; d++) {
    const dayDate = new Date(now.getTime() - d * 24 * 60 * 60 * 1000);

    for (let h = 0; h < 20; h++) {
      const timestamp = new Date(dayDate);
      timestamp.setUTCHours(7 + h, Math.floor(Math.random() * 60), 0, 0);

      const level = Math.max(0, 1.0 - (h * 0.04)); // Battery drain

      const snapshot: ContextSnapshot = {
        id: crypto.randomUUID(),
        user_id: userId,
        timestamp: timestamp.toISOString(),
        location: { lat: 40.7128, lon: -74.0060, accuracy: 10, provider: 'gps', source: 'gps' },
        calendar: { next_event: null, upcoming_events: [] },
        battery: { level, is_charging: false, power_saver_on: false },
        notifications: [
          { id: 'n1', app_package: 'com.whatsapp', sender: 'Friend', category: 'message', is_ongoing: false, posted_at: timestamp.toISOString() }
        ],
        device_state: { network_type: '4g', is_roaming: false, screen_on: true, do_not_disturb: false, ringer_mode: 'normal' },
        meta: { client_version: '1.0.0', schema_version: '1.0.0', capture_reason: 'timer' },
        derived: {
          has_next_event: false,
          minutes_to_next_event: null,
          is_commute_window: h === 2 || h === 10, // 9 AM and 5 PM
          battery_band: level > 0.2 ? 'ok' : 'low'
        }
      };
      snapshots.push(snapshot);
    }
  }

  for (const s of snapshots) {
    await contextSnapshotRepo.save(s);
  }

  console.log(`[Seeder] Seeded ${snapshots.length} snapshots.`);
  process.exit(0);
}

seedSnapshots().catch(err => {
  console.error("[Seeder] Failed:", err);
  process.exit(1);
});
