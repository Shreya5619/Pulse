import { personalityAnalyzer } from "../server/src/services/PersonalityAnalyzer";
import { GraphAdapter } from "../server/src/services/GraphAdapter";
import { neo4jService } from "../server/src/services/Neo4jService";

async function test() {
  const userId = "test_user_123";
  
  // 1. Mock some notifications that imply specific traits/interests
  const notifications = [
    {
      id: "notif_1",
      app_package: "com.slack",
      sender: "Engineering Lead",
      title: "System Architecture Review",
      body: "Please review the new Neo4j schema for the personality model.",
      category: "message",
      posted_at: new Date().toISOString()
    },
    {
      id: "notif_2",
      app_package: "com.strava",
      sender: "Strava",
      title: "Morning Run Complete",
      body: "You ran 5.2 miles! Great job keeping the streak.",
      category: "unknown",
      posted_at: new Date().toISOString()
    },
    {
      id: "notif_3",
      app_package: "com.binance",
      sender: "Price Alert",
      title: "BTC at $100k",
      body: "Bitcoin has reached a new all-time high.",
      category: "promo",
      posted_at: new Date().toISOString()
    }
  ];

  console.log("[Test] Running Personality Analysis...");
  
  // Use the actual service (will use Groq if API key is present, else fallback)
  const analysis = await personalityAnalyzer.analyze(userId, notifications as any);
  
  if (!analysis) {
    console.log("[Test] No analysis produced (possibly no change or error).");
    return;
  }

  console.log("[Test] Analysis Results:");
  console.log(JSON.stringify(analysis, null, 2));

  console.log("[Test] Syncing to Neo4j...");
  await GraphAdapter.applyPersonalityToNeo4j(userId, analysis);

  // 2. Verify by querying Neo4j
  const session = await neo4jService.getSession();
  try {
    const result = await session.run(
      `MATCH (p:Person {id: $userId})
       OPTIONAL MATCH (p)-[:HAS_TRAIT]->(t)
       OPTIONAL MATCH (p)-[:INTERESTED_IN]->(i)
       OPTIONAL MATCH (p)-[:FEELS]->(s)
       RETURN collect(distinct t.name) as traits, 
              collect(distinct i.name) as interests, 
              s.value as sentiment`,
      { userId }
    );
    
    if (result.records.length > 0) {
      const record = result.records[0];
      console.log("[Test] Verification from Neo4j:");
      console.log("- Traits:", record.get('traits'));
      console.log("- Interests:", record.get('interests'));
      console.log("- Sentiment:", record.get('sentiment'));
    } else {
      console.log("[Test] No records found in Neo4j for verification.");
    }

    // 3. Test Risk Engine with this personality
    console.log("\n[Test] Computing Risks with Personality...");
    const { riskEngine } = await import("../server/src/services/RiskEngineService");
    const riskSnapshot = await riskEngine.computeForUser(userId);
    
    console.log("[Test] Risk Scores:");
    riskSnapshot.risks.forEach(r => {
      console.log(`- ${r.type.toUpperCase()}: ${r.score.toFixed(2)} (${r.label}) - ${r.summary}`);
    });

  } finally {
    await session.close();
    await neo4jService.close();
  }
}

test().catch(err => {
  console.error("[Test] Failed:", err);
  process.exit(1);
});
