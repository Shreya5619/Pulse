export type LatLng = { lat: number; lon: number };

export interface RouteResult {
  durationSeconds: number;
  distanceMeters: number;
}

export interface MultiModeRouteResult {
  car: RouteResult;
  auto: RouteResult;
  twoWheeler: RouteResult;
  walk: RouteResult;
  transit: RouteResult;
}

class RoutingService {
  private baseUrl: string;
  private olaApiKey: string | undefined;
  private routeCache = new Map<string, RouteResult>();

  constructor() {
    // Note: Node v18+ has built-in fetch. No need for node-fetch import.
    this.baseUrl = process.env.OSRM_BASE_URL || "http://localhost:5000";
    this.olaApiKey = process.env.OLA_API_KEY;
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

    // Attempt Ola Maps API if API Key is available
    if (this.olaApiKey) {
      const olaUrl = `https://api.olamaps.io/routing/v1/directions?origin=${from.lat},${from.lon}&destination=${to.lat},${to.lon}&api_key=${this.olaApiKey}`;
      console.log(`[Routing] Attempting Ola Maps Directions API for ${key}...`);

      try {
        const requestId = `pulse_routing_${Date.now()}`;
        const res = await fetch(olaUrl, {
          method: "POST",
          headers: {
            "X-Request-Id": requestId,
            "Accept": "application/json"
          }
        });

        if (res.ok) {
          const json = await res.json() as any;
          if (json && json.status === "SUCCESS" && json.routes && json.routes[0]) {
            const bestRoute = json.routes[0];
            const leg = bestRoute.legs?.[0];
            
            // Get route details, accounting for different potential API response shapes
            const durationSeconds = leg?.duration?.value ?? leg?.duration ?? 0;
            const distanceMeters = leg?.distance?.value ?? leg?.distance ?? 0;

            console.log(`[Routing] Ola Maps Success: duration=${durationSeconds}s, distance=${distanceMeters}m`);
            const result: RouteResult = { durationSeconds, distanceMeters };
            this.routeCache.set(key, result);
            return result;
          } else {
            console.warn(`[Routing] Ola Maps API returned unexpected format or error:`, json);
          }
        } else {
          console.warn(`[Routing] Ola Maps API responded with HTTP ${res.status}: ${res.statusText}`);
        }
      } catch (olaError) {
        console.error(`[Routing] Ola Maps API request failed:`, olaError instanceof Error ? olaError.message : olaError);
        console.warn("[Routing] Falling back to OSRM...");
      }
    }

    // Fallback: Original OSRM Logic
    const coords = `${from.lon},${from.lat};${to.lon},${to.lat}`;
    const url = `${this.baseUrl}/route/v1/driving/${coords}?overview=full&alternatives=false&steps=false`;
    
    try {
      const res = await fetch(url);
      if (!res.ok) {
        throw new Error(`OSRM error: ${res.status} ${res.statusText}`);
      }
      const json = await res.json() as any;

      if (!json.routes || !json.routes[0]) {
        throw new Error("No route found in OSRM response");
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
      
      console.warn("[Routing] Using fallback heuristic: 30 minutes, 5km");
      return {
        durationSeconds: 1800, // 30 minutes
        distanceMeters: 5000   // 5 km
      };
    }
  }

  async getMultiModeRoutes(from: LatLng, to: LatLng): Promise<MultiModeRouteResult> {
    const defaultRes = () => ({ durationSeconds: 1800, distanceMeters: 5000 });
    
    let car = defaultRes();
    let auto = defaultRes();
    let twoWheeler = defaultRes();
    let walk = defaultRes();
    let transit = defaultRes();

    if (this.olaApiKey) {
      try {
        const fetchMode = async (mode: string): Promise<RouteResult> => {
          const olaUrl = `https://api.olamaps.io/routing/v1/directions?origin=${from.lat},${from.lon}&destination=${to.lat},${to.lon}&travel_mode=${mode}&api_key=${this.olaApiKey}`;
          const res = await fetch(olaUrl, {
            method: "POST",
            headers: {
              "X-Request-Id": `pulse_multi_${mode}_${Date.now()}`,
              "Accept": "application/json"
            }
          });
          if (res.ok) {
            const json = await res.json() as any;
            if (json && json.status === "SUCCESS" && json.routes?.[0]) {
              const leg = json.routes[0].legs?.[0];
              return {
                durationSeconds: leg?.duration?.value ?? leg?.duration ?? 1800,
                distanceMeters: leg?.distance?.value ?? leg?.distance ?? 5000
              };
            }
          }
          throw new Error(`Ola Maps mode ${mode} fetch failed`);
        };

        // Fetch only driving route. Ola Maps Free Tier silently defaults to driving speeds for 'walk' and 'bike' modes, causing physically impossible ETAs.
        try { car = await fetchMode("driving"); } catch(e) {}

        // Apply realistic physics-based heuristics to the live traffic route
        if (car.distanceMeters > 0) {
          // Auto (rickshaw) is usually ~10% slower than a car in traffic
          auto = {
            durationSeconds: Math.round(car.durationSeconds * 1.1),
            distanceMeters: car.distanceMeters
          };
          
          // Two-wheeler can filter through traffic, ~15% faster than car
          twoWheeler = {
            durationSeconds: Math.round(car.durationSeconds * 0.85),
            distanceMeters: car.distanceMeters
          };
          
          // Walking speed is roughly 1.4 meters per second (5km/h)
          walk = {
            durationSeconds: Math.round(car.distanceMeters / 1.4),
            distanceMeters: car.distanceMeters
          };

          // Transit Heuristic
          transit = {
            durationSeconds: Math.round(car.durationSeconds * 1.3) + 480,
            distanceMeters: car.distanceMeters
          };
        }

      } catch (e) {
        console.error("[Routing] Multi-mode Ola fetch failed, executing fallback heuristics.", e);
      }
    } else {
      // OSRM Heuristic fallback
      try {
        const baseRoute = await this.getRoute(from, to);
        car = baseRoute;
        auto = { ...baseRoute, durationSeconds: Math.round(baseRoute.durationSeconds * 0.9) };
        twoWheeler = { ...baseRoute, durationSeconds: Math.round(baseRoute.durationSeconds * 0.75) };
        walk = { 
          distanceMeters: baseRoute.distanceMeters, 
          durationSeconds: Math.round(baseRoute.distanceMeters / 1.35) // roughly 5km/h walking speed
        };
        transit = {
          distanceMeters: baseRoute.distanceMeters,
          durationSeconds: Math.round(baseRoute.durationSeconds * 1.4) + 300
        };
      } catch (e) {
        console.error("[Routing] Multi-mode OSRM fallback failed.", e);
      }
    }

    return { car, auto, twoWheeler, walk, transit };
  }
}

export const routingService = new RoutingService();

