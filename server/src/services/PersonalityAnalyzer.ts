import { ContextSnapshot } from "../../../shared/context_snapshot";
import dotenv from "dotenv";
import path from "path";

dotenv.config({ path: path.resolve(__dirname, "../../../.env") });

export interface PersonalityAnalysis {
  traits: string[];
  interests: string[];
  sentiment: string;
}

export class PersonalityAnalyzer {
  private lastAnalysisHash: string = "";

  /**
   * Analyzes a notification digest to derive personality traits, interests, and sentiment.
   */
  async analyze(userId: string, digest: ContextSnapshot["notification_digest"]): Promise<PersonalityAnalysis | null> {
    if (!digest || digest.total_count === 0) return null;

    // 1. Simple change detection to avoid redundant LLM calls
    const currentHash = this.computeHash(digest);
    if (currentHash === this.lastAnalysisHash) {
      return null; // No significant change
    }

    const apiKey = process.env.GROQ_API;
    if (!apiKey) {
      console.warn("[PersonalityAnalyzer] No GROQ_API found, skipping analysis.");
      return this.getFallbackAnalysis(digest);
    }

    try {
      const categoriesSummary = Object.entries(digest.by_category)
        .map(([cat, count]) => `${cat}: ${count}`)
        .join(", ");
      
      const threadsSummary = digest.top_threads
        .map(t => `Thread from ${t.sender} (${t.count} messages)`)
        .join("\n");

      const prompt = `
        Analyze this notification digest for user ${userId} and return a JSON object representing their current state and personality.
        Focus on:
        1. Traits: Long-term behavioral characteristics (e.g., "Highly responsive to work", "Socially active", "Focuses on fitness").
        2. Interests: Topics derived from senders or frequency (e.g., "AI", "Finance", "Gaming", "Cooking").
        3. Sentiment: Current emotional state or urgency (e.g., "Stressed", "Calm", "Excited", "Overwhelmed").

        Format:
        {
          "traits": ["trait1", "trait2", "trait3"],
          "interests": ["interest1", "interest2", "interest3"],
          "sentiment": "Current sentiment"
        }

        Digest Summary:
        Total Count: ${digest.total_count}
        By Category: ${categoriesSummary}
        Top Threads:
        ${threadsSummary}
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
            { role: "system", content: "You are a behavioral psychologist and data scientist specialized in digital twin modeling. Respond ONLY with the JSON object." },
            { role: "user", content: prompt }
          ],
          response_format: { type: "json_object" },
          temperature: 0.1
        })
      });

      if (!response.ok) {
        const errorData = await response.text();
        throw new Error(`LLM API returned ${response.status}: ${errorData}`);
      }

      const data: any = await response.json();
      const content = data.choices?.[0]?.message?.content;
      
      if (!content) throw new Error("Empty or invalid response from LLM");

      const analysis: PersonalityAnalysis = JSON.parse(content);
      this.lastAnalysisHash = currentHash;
      
      console.log(`[PersonalityAnalyzer] Successfully analyzed personality for ${userId}`);
      return analysis;

    } catch (error) {
      console.error("[PersonalityAnalyzer] Analysis failed:", error);
      return this.getFallbackAnalysis(digest);
    }
  }

  private computeHash(digest: any): string {
    return JSON.stringify(digest.by_category) + JSON.stringify(digest.top_threads);
  }

  private getFallbackAnalysis(digest: any): PersonalityAnalysis {
    const traits = ["Active Digital User"];
    const interests = digest.top_threads.map((t: any) => t.sender).slice(0, 3);
    const sentiment = digest.total_count > 20 ? "Busy" : "Calm";

    return {
      traits,
      interests,
      sentiment
    };
  }
}

export const personalityAnalyzer = new PersonalityAnalyzer();
