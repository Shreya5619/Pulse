/**
 * Test script for Planner Latest API
 */
async function testPlannerLatest() {
    const userId = "31d1ff89-6b28-44e0-bea3-7c61debfd1b6"; // Real user ID from demo
    const url = `http://localhost:8080/api/planner/latest?userId=${userId}`;

    console.log(`[Test] GETting from ${url}...`);
    try {
        const response = await fetch(url);
        const result = await response.json();
        
        if (response.ok) {
            console.log("[Test] Latest Recommendation found:");
            console.log(`ID: ${result.data.chosen?.id}`);
            console.log(`Title: ${result.data.chosen?.title}`);
            console.log(`Timestamp: ${result.data.timestamp}`);
        } else {
            console.warn("[Test] No recommendation found (this is expected if no heartbeat has run yet).");
            console.log("Result:", result);
        }
    } catch (error) {
        console.error("[Test] Failed:", error);
    }
}

testPlannerLatest();
