export type LatLng = { lat: number; lon: number };

export interface RouteResult {
  durationSeconds: number;
  distanceMeters: number;
}

class RoutingService {
  private baseUrl: string;

  constructor() {
    // Note: Node v18+ has built-in fetch. No need for node-fetch import.
    this.baseUrl = process.env.OSRM_BASE_URL || "http://localhost:5000";
  }

  async getRoute(from: LatLng, to: LatLng): Promise<RouteResult> {
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
      return {
        durationSeconds: route.duration,
        distanceMeters: route.distance
      };
    } catch (error) {
      if (error instanceof Error) {
        throw new Error(`RoutingService failed: ${error.message}`);
      }
      throw error;
    }
  }
}

export const routingService = new RoutingService();
