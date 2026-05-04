/**
 * Test script for Guardian Agent API
 */
async function testGuardian() {
    const url = "http://localhost:8080/api/guardian/validate";
    const action = {
        id: "test_001",
        title: "Charge Phone",
        description: "Battery is low",
        type: "HARDWARE",
        priority: 1
    };

    console.log(`[Test] POSTing to ${url}...`);
    try {
        const response = await fetch(url, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ action })
        });
        const result = await response.json();
        console.log("[Test] Guardian Response:", JSON.stringify(result, null, 2));
    } catch (error) {
        console.error("[Test] Failed:", error);
    }
}

testGuardian();
