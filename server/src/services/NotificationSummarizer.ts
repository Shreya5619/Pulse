import dotenv from "dotenv";
import path from "path";

// Load .env from root (Pulse/.env)
// NotificationSummarizer is in server/src/services
dotenv.config({ path: path.resolve(__dirname, "../../../.env") });

export class NotificationSummarizer {
  async summarize(notifications: any[]): Promise<{ highlight: string, digest: string, actionItems: string[] }> {
    const apiKey = process.env.GROQ_API;
    
    console.log(`[NotificationSummarizer] Summarizing ${notifications.length} notifications. API Key present: ${!!apiKey}`);
    
    if (!notifications || notifications.length === 0) {
      return {
        highlight: "No recent notifications.",
        digest: "",
        actionItems: []
      };
    }

    if (!apiKey) {
      console.warn("[NotificationSummarizer] No GROQ_API found in environment. Check Pulse/.env file.");
      return this.fallbackSummarize(notifications);
    }

    try {
      const notificationList = notifications.map(n => 
        `- [${n.appName || n.packageName}] ${n.title}: ${n.text}`
      ).join("\n");

      const prompt = `
        You are an advanced notification filter and summarizer for a high-performance user.
        Analyze these notifications and provide:
        1. A high-level 'highlight' (one short sentence) of the most critical event.
        2. A 'digest' paragraph summarizing all low-priority/noise notifications.
        3. A list of up to 5 'actionItems' for the most important notifications.

        Format your response ONLY as a JSON object:
        {
          "highlight": "The urgent headline",
          "digest": "Summary of everything else",
          "actionItems": ["Action 1", "Action 2"]
        }

        Notifications:
        ${notificationList}
      `;

      const response = await fetch("https://api.groq.com/openai/v1/chat/completions", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          model: "llama-3.1-8b-instant",
          messages: [
            { role: "system", content: "You are a professional assistant. Respond ONLY with valid JSON." },
            { role: "user", content: prompt }
          ],
          response_format: { type: "json_object" },
          temperature: 0.1
        })
      });

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`Groq API error (${response.status}): ${errorText}`);
      }

      const data: any = await response.json();
      const content = data.choices?.[0]?.message?.content;
      
      if (!content) throw new Error("Empty response from Groq");

      const result = JSON.parse(content);
      console.log(`[NotificationSummarizer] Successfully generated AI summary.`);
      return result;

    } catch (error) {
      console.error("[NotificationSummarizer] LLM summarization failed:", error);
      return this.fallbackSummarize(notifications);
    }
  }

  private fallbackSummarize(notifications: any[]) {
    console.log("[NotificationSummarizer] Using fallback template logic.");
    const byApp: Record<string, number> = {};
    for (const n of notifications) {
      const appName = n.appName || n.packageName || 'Unknown';
      byApp[appName] = (byApp[appName] || 0) + 1;
    }

    let topApp = 'Unknown';
    let maxCount = 0;
    for (const [app, count] of Object.entries(byApp)) {
        if (count > maxCount) {
            topApp = app;
            maxCount = count;
        }
    }

    const urgent: string[] = [];
    const important: string[] = [];
    let noiseCount = 0;

    for (const n of notifications) {
      const text = (n.text || '').toLowerCase();
      const app = (n.appName || n.packageName || '').toLowerCase();

      if (text.includes('otp') || text.includes('code')) {
        urgent.push(`Action Required: ${n.appName || n.packageName} Code`);
      } else if (app.includes('slack') || app.includes('whatsapp') || app.includes('teams')) {
        important.push(`Message from ${n.appName || n.packageName}: ${n.title}`);
      } else {
        noiseCount++;
      }
    }

    let highlight = `Summary of ${notifications.length} notifications`;
    if (urgent.length > 0) highlight = urgent[0];
    else if (important.length > 0) highlight = important[0];

    const actionItems = [...urgent, ...important].slice(0, 5);
    const digest = `Captured ${noiseCount} minor alerts from various apps. Primary activity concentrated in ${topApp}.`;

    return {
      highlight,
      actionItems,
      digest
    };
  }
}

export const notificationSummarizer = new NotificationSummarizer();
