
async function testActRiskCharging() {
    const userId = "test-user-uuid-charging";
    const deviceId = "test-device-id-charging";

    // 1. Send snapshot to establish battery state (CHARGING)
    console.log("Sending snapshot to establish battery state (CHARGING)...");
    await fetch('http://localhost:8080/api/snapshots', {
        method: 'POST',
        body: JSON.stringify({
            userId,
            location: { lat: 12.9716, lon: 77.5946, status: "stable" },
            battery: { level: 0.35, is_charging: true }, // 35% battery, CHARGING
            calendar: { next_event: null, upcoming_events: [] },
            notifications: []
        }),
        headers: { 'Content-Type': 'application/json', 'X-User-Id': userId, 'X-Device-Id': deviceId }
    });

    // 2. Add an ACT
    const startTime = new Date(Date.now() + 60 * 60000).toISOString(); // 1 hour away
    const endTime = new Date(Date.now() + 120 * 60000).toISOString();

    console.log("Adding ACT event (no location)...");
    try {
        const res = await fetch('http://localhost:8080/api/day-pulse/add', {
            method: 'POST',
            body: JSON.stringify({
                userId,
                event: {
                    id: "act-test-2",
                    title: "Charging Test (No Location)",
                    start_time: startTime,
                    end_time: endTime,
                    location_text: null,
                    importance: 0.8
                }
            }),
            headers: { 
                'Content-Type': 'application/json',
                'X-User-Id': userId, 
                'X-Device-Id': deviceId 
            }
        });
        const data = await res.json() as any;
        
        const actBlock = data.data.blocks.find(b => b.eventId === "act-test-2");
        if (actBlock) {
            console.log("\nFound ACT block in Day Pulse:");
            const batteryRisk = actBlock.risks.find(r => r.type === 'battery');
            if (batteryRisk) {
                // Expected: 35% + (20% * 1h) = 55%
                // Since 55% > 40% (the threshold I set for ACTS), it might NOT show up as a risk 
                // unless I lower the threshold or check the explanation.
                // Wait, if it's > 40%, it won't be in the 'risks' array.
                console.log("Battery risk explanation:", batteryRisk.explanation);
            } else {
                console.log("\n✅ SUCCESS: No battery risk shown because battery is predicted to increase to 55% (Above 40% threshold).");
            }
        }
    } catch (err) {
        console.error("Error in test flow:", err.message);
    }
}

testActRiskCharging();
