
async function testActRisk() {
    const userId = "test-user-uuid";
    const deviceId = "test-device-id";

    // 1. Send snapshot to establish battery state (discharging)
    console.log("Sending snapshot to establish battery state...");
    await fetch('http://localhost:8080/api/snapshots', {
        method: 'POST',
        body: JSON.stringify({
            userId,
            location: { lat: 12.9716, lon: 77.5946, status: "stable" },
            battery: { level: 0.35, is_charging: false }, // 35% battery, discharging
            calendar: { next_event: null, upcoming_events: [] },
            notifications: []
        }),
        headers: { 'Content-Type': 'application/json', 'X-User-Id': userId, 'X-Device-Id': deviceId }
    });

    // 2. Add an ACT (event with timing but no location)
    const startTime = new Date(Date.now() + 30 * 60000).toISOString();
    const endTime = new Date(Date.now() + 90 * 60000).toISOString();

    console.log("Adding ACT event (no location)...");
    try {
        const res = await fetch('http://localhost:8080/api/day-pulse/add', {
            method: 'POST',
            body: JSON.stringify({
                userId,
                event: {
                    id: "act-test-1",
                    title: "Virtual Standup (No Location)",
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
        if (!data.ok) {
            console.error("Failed to add event:", data.error);
            return;
        }
        console.log("ACT event added.");

        // 3. Verify risks in the returned timeline
        const actBlock = data.data.blocks.find(b => b.eventId === "act-test-1");
        if (actBlock) {
            console.log("\nFound ACT block in daily pulse:");
            console.log("Title:", actBlock.title);
            console.log("Risks:", JSON.stringify(actBlock.risks, null, 2));

            const batteryRisk = actBlock.risks.find(r => r.type === 'battery');
            if (batteryRisk && batteryRisk.explanation.includes("[ACT]")) {
                console.log("\n✅ SUCCESS: Found [ACT] battery risk for event without location.");
                console.log("Battery risk explanation:", batteryRisk.explanation);

                // Check if charging state is considered
                // 35% - (8% * 0.5h) = 31%
                if (batteryRisk.explanation.includes("31%")) {
                    console.log("✅ SUCCESS: Battery prediction matches expected discharging calculation (31%).");
                }
            } else {
                console.log("\n❌ FAILURE: Could not find specific ACT battery risk.");
            }
        } else {
            console.log("\n❌ FAILURE: Could not find the test event in daily pulse.");
        }
    } catch (err) {
        console.error("Error in test flow:", err.message);
    }
}

testActRisk();
