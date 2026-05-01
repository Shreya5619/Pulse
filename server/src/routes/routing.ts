import { Router } from "express";
import { routingService } from "../services/RoutingService";
import { contextSnapshotRepo } from "../db/ContextSnapshotRepository";
import { eventsRepo } from "../db/EventsRepository";

const router = Router();

/**
 * GET /api/routing/eta
 * Query params: fromLat, fromLon, toLat, toLon
 */
router.get("/eta", async (req, res) => {
  try {
    const { fromLat, fromLon, toLat, toLon } = req.query;

    if (!fromLat || !fromLon || !toLat || !toLon) {
      return res.status(400).json({ ok: false, error: "Missing coordinates" });
    }

    const result = await routingService.getRoute(
      { lat: Number(fromLat), lon: Number(fromLon) },
      { lat: Number(toLat), lon: Number(toLon) }
    );

    res.json({
      ok: true,
      data: {
        durationSeconds: result.durationSeconds,
        distanceMeters: result.distanceMeters
      }
    });
  } catch (err) {
    console.error("[Routing] /eta error:", err);
    res.status(500).json({ ok: false, error: "Routing failed" });
  }
});

/**
 * GET /api/routing/next-appointment-eta
 * Query params: userId
 */
router.get("/next-appointment-eta", async (req, res) => {
  try {
    const userId = req.query.userId as string;
    if (!userId) {
      return res.status(400).json({ ok: false, error: "Missing userId" });
    }

    const context = await contextSnapshotRepo.findLatestByUser(userId);
    const nextEvent = await eventsRepo.getNextEvent(userId);

    if (!context || !nextEvent || !nextEvent.location || !context.location.lat || !context.location.lon) {
      return res.json({ 
        ok: true, 
        data: { 
          hasRoute: false,
          reason: !context ? "No context" : !nextEvent ? "No event" : !nextEvent.location ? "No event location" : "No current location"
        } 
      });
    }

    const from = { lat: context.location.lat, lon: context.location.lon };
    const to = { lat: nextEvent.location.lat, lon: nextEvent.location.lon };

    const result = await routingService.getRoute(from, to);

    const now = new Date(context.timestamp);
    const eventTime = new Date(nextEvent.start_time);
    const travelSeconds = result.durationSeconds;
    const leaveByTime = new Date(eventTime.getTime() - travelSeconds * 1000);
    const leaveInMinutes = Math.round((leaveByTime.getTime() - now.getTime()) / 60000);
    
    const latenessRisk = leaveInMinutes < 5 ? "at_risk" : "nominal";

    res.json({
      ok: true,
      data: {
        hasRoute: true,
        durationSeconds: result.durationSeconds,
        distanceMeters: result.distanceMeters,
        travelMode: result.travelMode || "car",
        worstSegment: result.worstSegment,
        eventId: nextEvent.id,
        eventTitle: nextEvent.title,
        eventTime: nextEvent.start_time,
        destinationName: nextEvent.location_text || "Destination",
        leaveInMinutes: leaveInMinutes,
        latenessRisk: latenessRisk,
        etaDisplay: `${Math.round(result.durationSeconds / 60)} min`
      }
    });
  } catch (err) {
    console.error("[Routing] /next-appointment-eta error:", err);
    res.status(500).json({ ok: false, error: "Routing failed" });
  }
});

/**
 * GET /api/routing/multi-mode-eta
 * Query params: fromLat, fromLon, toLat, toLon
 */
router.get("/multi-mode-eta", async (req, res) => {
  try {
    const { fromLat, fromLon, toLat, toLon } = req.query;

    if (!fromLat || !fromLon || !toLat || !toLon) {
      return res.status(400).json({ ok: false, error: "Missing coordinates" });
    }

    const result = await routingService.getMultiModeRoutes(
      { lat: Number(fromLat), lon: Number(fromLon) },
      { lat: Number(toLat), lon: Number(toLon) }
    );

    res.json({
      ok: true,
      data: result
    });
  } catch (err) {
    console.error("[Routing] /multi-mode-eta error:", err);
    res.status(500).json({ ok: false, error: "Multi-mode routing failed" });
  }
});

export default router;
