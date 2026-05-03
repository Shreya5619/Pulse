import { Router } from "express";
import { geocodingService } from "../services/GeocodingService";
import { routingService } from "../services/RoutingService";

const router = Router();

/**
 * GET /api/route/eta
 * Query params: fromLat, fromLon, toLoc
 */
router.get("/eta", async (req, res) => {
  try {
    const { fromLat, fromLon, fromLoc, toLoc } = req.query;

    if (!toLoc || (!fromLoc && (!fromLat || !fromLon))) {
      return res.status(400).json({ 
        ok: false, 
        error: "Missing required parameters. Provide toLoc and either (fromLat, fromLon) or fromLoc." 
      });
    }

    // 1. Resolve starting point
    let startLat: number;
    let startLon: number;
    let startName: string | undefined;

    if (fromLoc) {
      console.log(`[Route] Geocoding origin: ${fromLoc}`);
      const origin = await geocodingService.geocode(fromLoc as string);
      if (!origin) {
        return res.status(404).json({ ok: false, error: `Could not find origin: ${fromLoc}` });
      }
      startLat = origin.lat;
      startLon = origin.lon;
      startName = origin.displayName;
    } else {
      startLat = Number(fromLat);
      startLon = Number(fromLon);
    }

    console.log(`[Route] Calculating ETA from ${startName || `(${startLat}, ${startLon})`} to "${toLoc}"`);

    // 2. Geocode the destination
    const destination = await geocodingService.geocode(toLoc as string);
    if (!destination) {
      return res.status(404).json({ 
        ok: false, 
        error: `Could not find destination: ${toLoc}` 
      });
    }

    console.log(`[Route] Destination geocoded to: ${destination.displayName} (${destination.lat}, ${destination.lon})`);

    // 3. Get ETA from OSRM
    const routeResult = await routingService.getRoute(
      { lat: startLat, lon: startLon },
      { lat: destination.lat, lon: destination.lon }
    );

    res.json({
      ok: true,
      data: {
        from: { 
          lat: startLat, 
          lon: startLon,
          name: startName || "Custom Location"
        },
        to: { 
          lat: destination.lat, 
          lon: destination.lon, 
          name: destination.displayName 
        },
        eta: {
          durationSeconds: routeResult.durationSeconds,
          durationMinutes: Math.round(routeResult.durationSeconds / 60),
          distanceMeters: routeResult.distanceMeters,
          display: `${Math.round(routeResult.durationSeconds / 60)} mins`
        }
      }
    });
  } catch (err) {
    console.error("[Route] /eta error:", err);
    res.status(500).json({ ok: false, error: "Internal server error" });
  }
});

export default router;
