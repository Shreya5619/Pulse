import { contextSnapshotRepo } from "../server/src/db/ContextSnapshotRepository";
import { ContextSnapshot } from "../shared/context_snapshot";
import crypto from "crypto";

async function seedOsrmTest() {
  const userId = 'user_123';
  console.log(`[Seeder] Seeding OSRM test data for user: ${userId}`);

  const now = new Date();
  
  // 1. Create a snapshot with current location (Vidhana Soudha)
  const snapshot: ContextSnapshot = {
    id: crypto.randomUUID(),
    user_id: userId,
    timestamp: now.toISOString(),
    location: { 
      lat: 12.9716, 
      lon: 77.5946, 
      accuracy: 10, 
      provider: 'gps', 
      source: 'gps' 
    },
    calendar: { 
      next_event: {
        id: "event_lab",
        title: "Physics Lab",
        start_time: new Date(now.getTime() + 30 * 60000).toISOString(), // in 30 mins
        end_time: new Date(now.getTime() + 90 * 60000).toISOString(),
        location_text: "Indiranagar",
        location: {
          lat: 12.9859,
          lon: 77.6387
        },
        is_all_day: false,
        importance: "high"
      }, 
      upcoming_events: [] 
    },
    battery: { level: 0.17, is_charging: false, power_saver_on: false },
    notifications: [],
    device_state: { 
      network_type: '4g', 
      is_roaming: false, 
      screen_on: true, 
      do_not_disturb: false, 
      ringer_mode: 'normal' 
    },
    meta: { client_version: '1.0.0', schema_version: '1.0.0', capture_reason: 'manual' },
    derived: {
      has_next_event: true,
      minutes_to_next_event: 30,
      is_commute_window: true,
      battery_band: 'low'
    }
  };

  await contextSnapshotRepo.save(snapshot);
  console.log(`[Seeder] Seeded OSRM test snapshot.`);
  process.exit(0);
}

seedOsrmTest().catch(err => {
  console.error("[Seeder] Failed:", err);
  process.exit(1);
});
