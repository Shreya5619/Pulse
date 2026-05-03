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
    const { fromLat, fromLon, toLoc } = req.query;

    if (!fromLat || !fromLon || !toLoc) {
      return res.status(400).json({ 
        ok: false, 
        error: "Missing required parameters: fromLat, fromLon, toLoc" 
      });
    }

    console.log(`[Route] Calculating ETA from (${fromLat}, ${fromLon}) to "${toLoc}"`);

    // 1. Geocode the destination
    const destination = await geocodingService.geocode(toLoc as string);
    if (!destination) {
      return res.status(404).json({ 
        ok: false, 
        error: `Could not find location: ${toLoc}` 
      });
    }

    console.log(`[Route] Destination geocoded to: ${destination.displayName} (${destination.lat}, ${destination.lon})`);

    // 2. Get ETA from OSRM (via routingService)
    const from = { lat: Number(fromLat), lon: Number(fromLon) };
    const to = { lat: destination.lat, lon: destination.lon };
    
    const routeResult = await routingService.getRoute(from, to);

    res.json({
      ok: true,
      data: {
        from: { lat: from.lat, lon: from.lon },
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
