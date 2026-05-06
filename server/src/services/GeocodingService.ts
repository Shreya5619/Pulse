export interface GeocodeResult {
  lat: number;
  lon: number;
  displayName: string;
}

export class GeocodingService {
  private readonly baseUrl = "https://nominatim.openstreetmap.org/search";
  private readonly olaBaseUrl = "https://api.olamaps.io/places/v1/geocode";
  private readonly olaApiKey: string | undefined;
  private cache = new Map<string, GeocodeResult>();

  constructor() {
    this.olaApiKey = process.env.OLA_API_KEY;
  }

  async geocode(query: string): Promise<GeocodeResult | null> {
    if (!query) return null;
    const cacheKey = query.toLowerCase().trim();
    if (this.cache.has(cacheKey)) {
      console.log(`[Geocoding] Cache hit for: ${cacheKey}`);
      return this.cache.get(cacheKey)!;
    }

    // Try Nominatim first (usually more accurate for local context)
    try {
      const fullQuery = `${query}, Bangalore, Karnataka, India`;
      const url = `${this.baseUrl}?q=${encodeURIComponent(fullQuery)}&format=json&limit=1`;
      
      console.log(`[Geocoding] Trying Nominatim: ${query}`);
      const res = await fetch(url, { headers: { "User-Agent": "Pulse-App/1.0" } });
      
      if (res.ok) {
        const data = await res.json() as any[];
        if (data && data.length > 0) {
          const result = {
            lat: parseFloat(data[0].lat),
            lon: parseFloat(data[0].lon),
            displayName: data[0].display_name
          };
          this.cache.set(cacheKey, result);
          return result;
        }
      } else if (res.status === 429) {
        console.warn("[Geocoding] Nominatim rate limited (429), switching to Ola Maps...");
      }
    } catch (err) {
      console.warn("[Geocoding] Nominatim failed, trying Ola Maps...", err instanceof Error ? err.message : "");
    }

    // Fallback to Ola Maps
    if (this.olaApiKey) {
      try {
        const olaUrl = `${this.olaBaseUrl}?address=${encodeURIComponent(query)}&api_key=${this.olaApiKey}`;
        console.log(`[Geocoding] Trying Ola Maps: ${query}`);
        const res = await fetch(olaUrl);
        if (res.ok) {
          const json = await res.json() as any;
          if (json.status === "ok" && json.geocodingResults?.[0]) {
            const loc = json.geocodingResults[0].geometry.location;
            const result = {
              lat: loc.lat,
              lon: loc.lng,
              displayName: json.geocodingResults[0].formatted_address
            };
            this.cache.set(cacheKey, result);
            console.log(`[Geocoding] Ola Maps Success: ${query} -> ${result.displayName}`);
            return result;
          }
        }
      } catch (err) {
        console.error("[Geocoding] All geocoders failed", err);
      }
    }

    return null;

  }
}

export const geocodingService = new GeocodingService();
