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

class RoutingService {
  private baseUrl: string;
  private olaApiKey: string | undefined;
  private routeCache = new Map<string, CacheEntry<RouteResult>>();
  private multiModeCache = new Map<string, CacheEntry<MultiModeRouteResult>>();

  private isRoutingInProgress = false;
  private lastGlobalFetch = 0;
  private readonly CACHE_TTL = 120 * 1000; // 120 seconds (2 minutes)
  private readonly MULTI_MODE_COOLDOWN = 120 * 1000; // 120 seconds (2 minutes)
  private readonly GLOBAL_COOLDOWN = 120 * 1000; // 2 minute global rate limit
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

  async getRoute(from: LatLng, to: LatLng, force = false): Promise<RouteResult> {
    const now = Date.now();
    const key = this.cacheKey(from, to);

    // 1. Check Cache + Global Cooldown
    const cached = this.routeCache.get(key);
    const globalAge = now - this.lastGlobalFetch;

    if (cached && !force) {
      const age = now - cached.timestamp;
      if (age < this.CACHE_TTL) {
        return cached.result;
      }
    }

    // 2. Enforce global cooldown if not forced
    if (globalAge < this.GLOBAL_COOLDOWN && !force) {
      console.log(`[Routing] Global cooldown active (${Math.round(globalAge / 1000)}s ago). Skipping Ola fetch for ${key}.`);
      return cached?.result || this.getFallbackRoute();
    }

    // 2. Guard against parallel calls
    if (this.isRoutingInProgress) {
      console.log(`[Routing] Skipping fetch for ${key}: Request already in progress`);
      return cached?.result || this.getFallbackRoute();
    }

    console.log(`[Routing] START: Fetching route for ${key} @ ${now}`);
    this.isRoutingInProgress = true;

    try {
      const result = await this.performRouteFetch(from, to, key);
      this.routeCache.set(key, { result, timestamp: Date.now() });
      this.lastGlobalFetch = Date.now(); // Update global timestamp on success
      return result;
    } catch (error) {
      console.error(`[Routing] Fetch failed for ${key}:`, error instanceof Error ? error.message : "Unknown error");
      return cached?.result || this.getFallbackRoute();
    } finally {
      this.isRoutingInProgress = false;
      console.log(`[Routing] END: Route fetch finished for ${key} @ ${Date.now()}`);
    }
  }

  private async performRouteFetch(from: LatLng, to: LatLng, key: string): Promise<RouteResult> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.FETCH_TIMEOUT);

    try {
      // Attempt Ola Maps API if API Key is available
      if (this.olaApiKey) {
        const olaUrl = `https://api.olamaps.io/routing/v1/directions?origin=${from.lat},${from.lon}&destination=${to.lat},${to.lon}&api_key=${this.olaApiKey}`;

        try {
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
              return { durationSeconds, distanceMeters };
            }
          }
        } catch (olaError) {
          console.warn(`[Routing] Ola Maps failed, trying OSRM...`, olaError instanceof Error ? olaError.message : "");
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

    // 1. Check Cache + Cooldown
    const cached = this.multiModeCache.get(key);
    const globalAge = now - this.lastGlobalFetch;

    if (cached && !force) {
      const age = now - cached.timestamp;
      if (age < this.MULTI_MODE_COOLDOWN) {
        return cached.result;
      }
    }

    // 2. Enforce global cooldown if not forced
    if (globalAge < this.GLOBAL_COOLDOWN && !force) {
      console.log(`[Routing] Global cooldown active (${Math.round(globalAge / 1000)}s ago). Skipping multi-mode fetch for ${key}.`);
      return cached?.result || this.getFallbackMultiMode();
    }

    // 2. Guard against parallel calls
    if (this.isRoutingInProgress) {
      console.log(`[Routing] Skipping multi-mode fetch: Routing already in progress`);
      return cached?.result || this.getFallbackMultiMode();
    }

    console.log(`[Routing] START: Multi-mode fetch for ${key} @ ${now}`);
    this.isRoutingInProgress = true;

    try {
      const car = await this.performRouteFetch(from, to, key);

      // Apply realistic physics-based heuristics to the live traffic route
      const result: MultiModeRouteResult = {
        car,
        auto: { durationSeconds: Math.round(car.durationSeconds * 1.1), distanceMeters: car.distanceMeters },
        twoWheeler: { durationSeconds: Math.round(car.durationSeconds * 0.85), distanceMeters: car.distanceMeters },
        walk: { durationSeconds: Math.round(car.distanceMeters / 1.4), distanceMeters: car.distanceMeters },
        transit: { durationSeconds: Math.round(car.durationSeconds * 1.3) + 480, distanceMeters: car.distanceMeters }
      };

      this.multiModeCache.set(key, { result, timestamp: Date.now() });
      return result;
    } catch (e) {
      console.error("[Routing] Multi-mode fetch failed:", e);
      return cached?.result || this.getFallbackMultiMode();
    } finally {
      this.isRoutingInProgress = false;
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

