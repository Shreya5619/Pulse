export interface GeocodeResult {
  lat: number;
  lon: number;
  displayName: string;
}

class GeocodingService {
  private readonly baseUrl = "https://nominatim.openstreetmap.org/search";

  async geocode(query: string): Promise<GeocodeResult | null> {
    try {
      // Specifically target Bangalore as per user request
      const fullQuery = `${query}, Bangalore, Karnataka, India`;
      const url = `${this.baseUrl}?q=${encodeURIComponent(fullQuery)}&format=json&limit=1`;

      console.log(`[Geocoding] Fetching: ${url}`);
      
      const response = await fetch(url, {
        headers: {
          "User-Agent": "Pulse-App/1.0" // Nominatim requires a user-agent
        }
      });

      if (!response.ok) {
        throw new Error(`Nominatim error: ${response.status}`);
      }

      const data = await response.json() as any[];

      if (data && data.length > 0) {
        return {
          lat: parseFloat(data[0].lat),
          lon: parseFloat(data[0].lon),
          displayName: data[0].display_name
        };
      }

      return null;
    } catch (error) {
      console.error("[Geocoding] Error:", error);
      return null;
    }
  }
}

export const geocodingService = new GeocodingService();
