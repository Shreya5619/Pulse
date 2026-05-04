/**
 * Test script for Intelligent Planner based on Selected Scenario
 */
async function testIntelligentPlanner() {
    const userId = "31d1ff89-6b28-44e0-bea3-7c61debfd1b6"; // Real user ID from demo
    const baseUrl = "http://localhost:8080/api/planner";

    async function checkLatest() {
        const res = await fetch(`${baseUrl}/latest?userId=${userId}`);
        const result = await res.json();
        return result.data;
    }

    async function selectScenario(scenarioId: string) {
        console.log(`\n[Test] Selecting scenario: ${scenarioId}`);
        await fetch(`${baseUrl}/scenario/select`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ userId, scenarioId })
        });
    }

    async function triggerHeartbeat() {
        console.log("[Test] Triggering manual heartbeat...");
        await fetch(`http://localhost:8080/heartbeat/manual`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ userId })
        });
        // Wait for it to complete
        await new Promise(r => setTimeout(r, 2000));
    }

    console.log("--- Testing Intelligent Planner ---");

    // 1. Default (RECOMMENDED)
    await selectScenario("RECOMMENDED");
    await triggerHeartbeat();
    const d1 = await checkLatest();
    console.log(`[RECOMMENDED] Chosen: ${d1.chosen?.title || 'None'}`);

    // 2. DO_NOTHING
    await selectScenario("DO_NOTHING");
    await triggerHeartbeat();
    const d2 = await checkLatest();
    console.log(`[DO_NOTHING] Chosen: ${d2.chosen?.title || 'None'} (Expected: None)`);

    // 3. ALTERNATE (Focus)
    await selectScenario("ALTERNATE");
    await triggerHeartbeat();
    const d3 = await checkLatest();
    console.log(`[ALTERNATE] Chosen: ${d3.chosen?.title || 'None'} (Expected: Focus-oriented if multiple risks exist)`);
}

testIntelligentPlanner();
