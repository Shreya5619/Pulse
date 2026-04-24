import { memoryRepository } from "../server/src/db/MemoryRepository";

async function seedMemory() {
  const userId = 'user_123';
  console.log(`[Seeder] Seeding memory for user: ${userId}`);

  const identity = {
    user_id: userId,
    basics: { name: "John Doe", primary_language: "en", timezone: "America/New_York" },
    locations: {
      home: { lat: 40.7128, lon: -74.0060, address: "123 Main St, New York, NY" },
      office: { lat: 40.7580, lon: -73.9855, address: "Times Square, New York, NY" }
    },
    commute_preferences: {
      morning_window: { start: "07:30", end: "09:30" },
      evening_window: { start: "17:00", end: "19:30" },
      default_mode: "transit"
    }
  };

  const habits = {
    patterns: {
      departure_offsets: { morning: [-15, -10, -5, 0], evening: [5, 10, 15] },
      typical_lateness: 3,
      routines: { morning_wake_up: "06:45", evening_wind_down: "22:30" }
    },
    last_updated: new Date().toISOString()
  };

  const battery = {
    profile: {
      discharge_rates: { active: 0.12, standby: 0.02 },
      thresholds: { low: 0.25, critical: 0.15 },
      risky_hours: [{ start: "17:00", end: "20:00", reason: "Commute/Gym period" }],
      typical_charge_windows: [{ start: "23:00", end: "06:30" }]
    },
    last_updated: new Date().toISOString()
  };

  const commute = {
    routes: [
      { id: "h2o", from_label: "Home", to_label: "Office", typical_duration_minutes: 35, eta_bands: { p50: 35, p90: 48 }, usual_mode: "transit" }
    ],
    recent_anomalies: [],
    last_updated: new Date().toISOString()
  };

  const notifications = {
    priority_senders: ["Boss", "Mom"],
    noisy_packages: ["com.whatsapp.promo"],
    quiet_hours: [{ start: "22:00", end: "07:00" }],
    app_sensitivity: { "com.slack": "high" },
    last_updated: new Date().toISOString()
  };

  await memoryRepository.save(userId, 'identity', identity);
  await memoryRepository.save(userId, 'habits', habits);
  await memoryRepository.save(userId, 'battery', battery);
  await memoryRepository.save(userId, 'commute', commute);
  await memoryRepository.save(userId, 'notifications', notifications);

  console.log("[Seeder] Done.");
  process.exit(0);
}

seedMemory().catch(err => {
  console.error("[Seeder] Failed:", err);
  process.exit(1);
});
