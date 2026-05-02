import { routingService } from "../src/services/RoutingService";

async function testStacking() {
  const from = { lat: 12.9716, lon: 77.5946 }; // Bangalore
  const to = { lat: 12.9352, lon: 77.6245 };   // Koramangala

  console.log("--- SIMULATING HEARTBEAT STACKING ---");

  // Call 1: Should start a real fetch
  console.log("Triggering Call 1...");
  const p1 = routingService.getRoute(from, to);

  // Call 2: Immediately after, should be skipped by guard
  console.log("Triggering Call 2 (Immediate)...");
  const p2 = routingService.getRoute(from, to);

  // Call 3: Multi-mode, should also be skipped if Call 1 is still in progress
  console.log("Triggering Call 3 (Multi-mode)...");
  const p3 = routingService.getMultiModeRoutes(from, to);

  const [r1, r2, r3] = await Promise.all([p1, p2, p3]);

  console.log("\nResults Summary:");
  console.log("R1 Duration:", r1.durationSeconds);
  console.log("R2 Duration:", r2.durationSeconds);
  console.log("R3 (Car) Duration:", r3.car.durationSeconds);

  console.log("\n--- WAITING FOR CACHE EXPIRY (Simulated) ---");
  // We can't easily wait 60s in a test, but we can check if it returns cached value immediately now
  console.log("Triggering Call 4 (After Call 1 finished)...");
  const r4 = await routingService.getRoute(from, to);
  console.log("R4 Duration:", r4.durationSeconds);
}

testStacking().catch(console.error);
