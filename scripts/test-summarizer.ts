import { dailySummarizer } from "../server/src/services/DailySummarizer";

async function testSummarizer() {
  const userId = 'user_123';
  console.log(`[Test] Running DailySummarizer for user: ${userId}`);

  await dailySummarizer.summarize(userId);

  console.log("[Test] Summary complete. Check memory/user_123/*.yaml for updates.");
  process.exit(0);
}

testSummarizer().catch(err => {
  console.error("[Test] Failed:", err);
  process.exit(1);
});
