export type LatLng = { lat: number; lon: number };

export interface RouteResult {
  durationSeconds: number;
  distanceMeters: number;
  travelMode?: "car" | "metro" | "walking";
  worstSegment?: {
    name: string;
    delayMinutes: number;
  };
}

export interface MultiModeRouteResult {
  car: RouteResult;
  auto: RouteResult;
  twoWheeler: RouteResult;
  walk: RouteResult;
  transit: RouteResult;
}

interface CacheEntry<T> {
  result: T;
  timestamp: number;
}

export class RoutingService {
  private baseUrl: string;
  private olaApiKey: string | undefined;
  private routeCache = new Map<string, CacheEntry<RouteResult>>();
  private multiModeCache = new Map<string, CacheEntry<MultiModeRouteResult>>();

  private runningFetches = new Set<string>();
  private readonly CACHE_TTL = 30 * 1000; // 30 seconds
  private readonly MULTI_MODE_TTL = 30 * 1000; // 30 seconds
  private readonly FETCH_TIMEOUT = 30000; // 30 seconds

  constructor() {
    this.baseUrl = process.env.OSRM_BASE_URL || "http://localhost:5000";
    this.olaApiKey = process.env.OLA_API_KEY;
  }

  private cacheKey(from: LatLng, to: LatLng): string {
    const fLat = from.lat.toFixed(4);
    const fLon = from.lon.toFixed(4);
    const tLat = to.lat.toFixed(4);
    const tLon = to.lon.toFixed(4);
    return `${fLat},${fLon}-${tLat},${tLon}`;
  }

  async getRoute(from: LatLng, to: LatLng, force = false, mode: string = "driving"): Promise<RouteResult> {
    const now = Date.now();
    const key = `${this.cacheKey(from, to)}:${mode}`;

    const cached = this.routeCache.get(key);
    if (cached && !force) {
      const age = now - cached.timestamp;
      if (age < this.CACHE_TTL) {
        return cached.result;
      }
    }

    // 2. Guard against parallel calls for the SAME key
    if (this.runningFetches.has(key)) {
      console.log(`[Routing] Skipping fetch for ${key}: Request already in progress`);
      return cached?.result || this.getFallbackRoute();
    }

    console.log(`[Routing] START: Fetching route for ${key} @ ${now}`);
    this.runningFetches.add(key);

    try {
      const result = await this.performRouteFetch(from, to, key, mode);
      this.routeCache.set(key, { result, timestamp: Date.now() });
      return result;
    } catch (error) {
      console.error(`[Routing] Fetch failed for ${key}:`, error instanceof Error ? error.message : "Unknown error");
      if (cached?.result) return cached.result;
      const distance = this.getHaversineDistance(from, to);
      const durationSeconds = Math.round((distance / 10) * 1.5); // Assume 10m/s (~36km/h) average with 1.5x traffic multiplier
      console.warn(`[Routing] Using heuristic fallback: ${Math.round(durationSeconds/60)} mins, ${Math.round(distance)}m`);
      return {
        durationSeconds,
        distanceMeters: Math.round(distance),
        travelMode: mode as any,
        worstSegment: { name: "Local Road", delayMinutes: 5 }
      };
    } finally {
      this.runningFetches.delete(key);
      console.log(`[Routing] END: Route fetch finished for ${key} @ ${Date.now()}`);
    }
  }

  private async performRouteFetch(from: LatLng, to: LatLng, key: string, mode: string = "driving"): Promise<RouteResult> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.FETCH_TIMEOUT);

    try {
      // Attempt Ola Maps API if API Key is available
      if (this.olaApiKey) {
        const olaUrl = `https://api.olamaps.io/routing/v1/directions?origin=${from.lat},${from.lon}&destination=${to.lat},${to.lon}&mode=${mode}&api_key=${this.olaApiKey}`;

        try {
          console.log(`[Routing] Requesting Ola [${mode}]: FROM(${from.lat.toFixed(4)},${from.lon.toFixed(4)}) TO(${to.lat.toFixed(4)},${to.lon.toFixed(4)})`);
          const res = await fetch(olaUrl, {
            method: "POST",
            headers: {
              "X-Request-Id": `pulse_${Date.now()}`,
              "Accept": "application/json"
            },
            signal: controller.signal as any
          });

          if (res.ok) {
            const json = await res.json() as any;
            if (json && json.status === "SUCCESS" && json.routes?.[0]) {
              const leg = json.routes[0].legs?.[0];
              const durationSeconds = leg?.duration?.value ?? leg?.duration ?? 0;
              const distanceMeters = leg?.distance?.value ?? leg?.distance ?? 0;
              console.log(`[Routing] Ola Maps Success [${mode}]: ${Math.round(durationSeconds/60)} mins`);
              return { durationSeconds, distanceMeters };
            } else {
              console.warn(`[Routing] Ola Maps API returned success status but invalid route data [${mode}]:`, json.status);
            }
          } else {
            const errText = await res.text();
            console.warn(`[Routing] Ola Maps API error [${mode}]: ${res.status}`, errText);
          }
        } catch (olaError) {
          console.warn(`[Routing] Ola Maps network/fetch failure [${mode}]:`, olaError instanceof Error ? olaError.message : "");
        }
      }

      // Fallback: OSRM Logic
      const coords = `${from.lon},${from.lat};${to.lon},${to.lat}`;
      const url = `${this.baseUrl}/route/v1/driving/${coords}?overview=full&alternatives=false&steps=false`;

      const res = await fetch(url, { signal: controller.signal as any });
      if (!res.ok) throw new Error(`OSRM error: ${res.status}`);

      const json = await res.json() as any;
      if (!json.routes?.[0]) throw new Error("No route found");

      return {
        durationSeconds: json.routes[0].duration,
        distanceMeters: json.routes[0].distance,
        travelMode: "car",
        worstSegment: { name: "ORR", delayMinutes: 5 }
      };
    } finally {
      clearTimeout(timeout);
    }
  }

  private getHaversineDistance(p1: LatLng, p2: LatLng): number {
    const R = 6371e3; // Earth radius in meters
    const φ1 = p1.lat * Math.PI / 180;
    const φ2 = p2.lat * Math.PI / 180;
    const Δφ = (p2.lat - p1.lat) * Math.PI / 180;
    const Δλ = (p2.lon - p1.lon) * Math.PI / 180;

    const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
              Math.cos(φ1) * Math.cos(φ2) *
              Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return R * c;
  }

  private getFallbackRoute(): RouteResult {
    return {
      durationSeconds: 1800,
      distanceMeters: 5000,
      travelMode: "car"
    };
  }

  async getMultiModeRoutes(from: LatLng, to: LatLng, force = false): Promise<MultiModeRouteResult> {
    const now = Date.now();
    const key = this.cacheKey(from, to);

    // 1. Check Cache
    const cached = this.multiModeCache.get(key);

    if (cached && !force) {
      const age = now - cached.timestamp;
      if (age < this.MULTI_MODE_TTL) {
        return cached.result;
      }
    }

    // 2. Guard against parallel calls
    if (this.runningFetches.has(key)) {
      console.log(`[Routing] Skipping multi-mode fetch: Routing already in progress for ${key}`);
      return cached?.result || this.getFallbackMultiMode();
    }

    console.log(`[Routing] START: Multi-mode fetch for ${key} @ ${now}`);
    this.runningFetches.add(key);

    try {
      // Fetch all modes in parallel for performance
      const [car, twoWheeler, walk] = await Promise.all([
        this.getRoute(from, to, force, "driving"),
        this.getRoute(from, to, force, "two_wheeler"),
        this.getRoute(from, to, force, "walking")
      ]);

      const result: MultiModeRouteResult = {
        car,
        auto: { durationSeconds: Math.round(car.durationSeconds * 1.1), distanceMeters: car.distanceMeters },
        twoWheeler,
        walk,
        transit: { durationSeconds: Math.round(car.durationSeconds * 1.3) + 480, distanceMeters: car.distanceMeters }
      };

      this.multiModeCache.set(key, { result, timestamp: Date.now() });
      return result;
    } catch (e) {
      console.error("[Routing] Multi-mode fetch failed:", e);
      return cached?.result || this.getFallbackMultiMode();
    } finally {
      this.runningFetches.delete(key);
      console.log(`[Routing] END: Multi-mode fetch finished for ${key} @ ${Date.now()}`);
    }
  }

  private getFallbackMultiMode(): MultiModeRouteResult {
    const fallback = this.getFallbackRoute();
    return {
      car: fallback,
      auto: fallback,
      twoWheeler: fallback,
      walk: fallback,
      transit: fallback
    };
  }
}

export const routingService = new RoutingService();

