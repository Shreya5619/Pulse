
async function testMultiMode() {
  const userId = "user1";
  const baseUrl = "http://localhost:8080/api";

  console.log("--- Step 1: Posting Dummy Snapshot with Lateness Risk ---");
  
  // Coordinates for a lateness risk (Koramanagala to Whitefield in Bengaluru)
  const fromLat = 12.9352;
  const fromLon = 77.6245;
  const toLat = 12.9698;
  const toLon = 77.7500;

  const eventStartTime = new Date(Date.now() + 25 * 60 * 1000).toISOString(); // 25 mins from now
  
  const snapshot = {
    userId,
    timestamp: new Date().toISOString(),
    battery: { level: 0.8, is_charging: false },
    location: { lat: fromLat, lon: fromLon, status: "Koramangala" },
    calendar: {
      next_event: {
        id: "evt_multi_mode_test",
        title: "Test Meeting in Whitefield",
        start_time: eventStartTime,
        end_time: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
        location: { lat: toLat, lon: toLon },
        location_text: "Whitefield, Bengaluru"
      },
      upcoming_events: []
    },
    notification_digest: {
        total_count: 5,
        by_category: { "IMPORTANT_SENDER": 1 },
        top_threads: []
    }
  };

  const postRes = await fetch(`${baseUrl}/snapshots`, {
    method: 'POST',
    headers: { 
        'Content-Type': 'application/json',
        'X-User-Id': userId,
        'X-Device-Id': 'test-device'
    },
    body: JSON.stringify(snapshot)
  });

  if (!postRes.ok) {
    const err = await postRes.text();
    console.error("Failed to post snapshot:", err);
    return;
  }

  const postData = await postRes.json();
  console.log("Snapshot Posted successfully. ID:", postData.snapshot_id);

  console.log("\n--- Step 2: Fetching Planner Decision ---");
  // Give it a second to process the flow
  await new Promise(r => setTimeout(r, 2000));

  const planRes = await fetch(`${baseUrl}/planner/decision?userId=${userId}`);
  const planData = await planRes.json();

  if (planData.ok && planData.data.chosen) {
    const action = planData.data.chosen;
    console.log("RECOMMENDED ACTION:", action.title);
    console.log("DESCRIPTION:", action.description);
    if (action.transportModeInfo) {
        console.log("BEST MODE:", action.transportModeInfo.bestMode, "(", action.transportModeInfo.bestEta, ")");
        console.log("ALT MODE:", action.transportModeInfo.altMode, "(", action.transportModeInfo.altEta, ")");
    } else {
        console.log("No multi-mode info found in action.");
    }
  } else {
    console.log("No recommended action found or error:", planData.error);
  }

  console.log("\n--- Step 3: Fetching Futures ---");
  const futRes = await fetch(`${baseUrl}/futures?userId=${userId}`);
  const futData = await futRes.json();
  if (futData.ok) {
    console.log("FUTURES GENERATED:");
    futData.data.futures.forEach((f: any) => {
        console.log(`- ${f.id} (${f.title}): ${f.description}`);
    });
  } else {
    console.log("Futures fetch failed.");
  }
}

testMultiMode().catch(console.error);
