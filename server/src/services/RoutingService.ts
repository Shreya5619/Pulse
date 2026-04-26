export type LatLng = { lat: number; lon: number };

export interface RouteResult {
  durationSeconds: number;
  distanceMeters: number;
}

class RoutingService {
  private baseUrl: string;
  private routeCache = new Map<string, RouteResult>();

  constructor() {
    // Note: Node v18+ has built-in fetch. No need for node-fetch import.
    this.baseUrl = process.env.OSRM_BASE_URL || "http://localhost:5000";
  }

  private cacheKey(from: LatLng, to: LatLng): string {
    // Round to 4 decimal places (~11m precision) to increase cache hits
    const fLat = from.lat.toFixed(4);
    const fLon = from.lon.toFixed(4);
    const tLat = to.lat.toFixed(4);
    const tLon = to.lon.toFixed(4);
    return `${fLat},${fLon}-${tLat},${tLon}`;
  }

  async getRoute(from: LatLng, to: LatLng): Promise<RouteResult> {
    const key = this.cacheKey(from, to);
    if (this.routeCache.has(key)) {
      console.log(`[Routing] Cache hit for ${key}`);
      return this.routeCache.get(key)!;
    }

    const coords = `${from.lon},${from.lat};${to.lon},${to.lat}`;
    const url = `${this.baseUrl}/route/v1/driving/${coords}?overview=full&alternatives=false&steps=false`;
    
    try {
      const res = await fetch(url);
      if (!res.ok) {
        throw new Error(`OSRM error: ${res.status} ${res.statusText}`);
      }
      const json = await res.json() as any;

      if (!json.routes || !json.routes[0]) {
        throw new Error("No route found");
      }

      const route = json.routes[0];
      const result: RouteResult = {
        durationSeconds: route.duration,
        distanceMeters: route.distance
      };

      this.routeCache.set(key, result);
      return result;
    } catch (error) {
      console.error(`[Routing] OSRM failed: ${error instanceof Error ? error.message : "Unknown error"}`);
      
      // Fallback: Check if we have any cached value even if not an exact match (not implemented here for simplicity)
      // or return a safe heuristic.
      console.warn("[Routing] Using fallback heuristic: 30 minutes, 5km");
      return {
        durationSeconds: 1800, // 30 minutes
        distanceMeters: 5000   // 5 km
      };
    }
  }
}

export const routingService = new RoutingService();
