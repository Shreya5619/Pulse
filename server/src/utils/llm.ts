export async function queryGroq(messages: any[], options: { model?: string, temperature?: number, response_format?: any } = {}): Promise<string> {
    const primaryKey = process.env.GROQ_API_KEY || process.env.GROQ_API;
    const fallbackKey = process.env.GROQ_FALLBACK;
    
    const tryQuery = async (key: string) => {
        const response = await fetch("https://api.groq.com/openai/v1/chat/completions", {
            method: "POST",
            headers: { "Content-Type": "application/json", "Authorization": `Bearer ${key}` },
            body: JSON.stringify({
                model: options.model || "llama-3.3-70b-versatile",
                messages,
                response_format: options.response_format,
                temperature: options.temperature ?? 0.1
            })
        });

        if (!response.ok) {
            let errorDetail = response.statusText;
            try {
                const errorJson = await response.json();
                errorDetail = errorJson.error?.message || errorDetail;
            } catch (_) {}
            throw { status: response.status, message: errorDetail };
        }

        const data = await response.json() as any;
        return data.choices?.[0]?.message?.content || "";
    };

    try {
        if (!primaryKey) throw { status: 401, message: "No primary API key found" };
        return await tryQuery(primaryKey);
    } catch (e: any) {
        // If it's a network error (e.g. fetch failed), e.status will be undefined
        const isNetworkError = !e.status;
        
        if ((isNetworkError || e.status === 429 || e.status === 401) && fallbackKey) {
            console.warn(`[LLM Utils] Primary key failed or network error (${e.status || 'Network'}: ${e.message}). Trying fallback.`);
            try {
                return await tryQuery(fallbackKey);
            } catch (fallbackError: any) {
                console.error("[LLM Utils] Fallback also failed:", fallbackError);
                throw new Error(`Groq Fallback Error: ${fallbackError.message}`);
            }
        }
        
        console.error("[LLM Utils] Groq Query Failed:", e);
        throw new Error(`Groq Error: ${e.message || 'Unknown error'}`);
    }
}
