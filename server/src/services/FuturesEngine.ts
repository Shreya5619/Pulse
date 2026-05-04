import { RiskEngineService, riskEngine } from "./RiskEngineService";
import { RoutingService, routingService, RouteResult, MultiModeRouteResult } from "./RoutingService";
import { MemoryStore, memoryStore } from "./MemoryStore";
import { contextSnapshotRepo } from "../db/ContextSnapshotRepository";
import { eventsRepo } from "../db/EventsRepository";
import { FuturesResult, FutureCard, FutureId } from "../types/futures";
import { CalendarEvent, ContextSnapshot } from "../../../shared/context_snapshot";
import { MemoryState } from "../../../shared/memory";
import { RiskScore } from "../types/risk";
import { assessLateness, assessBattery } from "./RiskEngine";
import { geocodingService, GeocodingService } from "./GeocodingService";
import { GraphAdapter } from "./GraphAdapter";
import { PersonalityAnalysis } from "./PersonalityAnalyzer";

class FuturesEngine {
  constructor(
    private riskEngine: RiskEngineService,
    private routingService: RoutingService,
    private memoryStore: MemoryStore,
    private geocodingService: GeocodingService
  ) { }

  async computeForUser(userId: string): Promise<FuturesResult> {
    const now = new Date();
    const baseTime = now.toISOString();
    const horizonMinutes = 120;

    // Get current context & next event
    const context = await contextSnapshotRepo.findLatestByUser(userId);
    console.log(`[FuturesEngine] userId: ${userId}, context found: ${!!context}`);
    const nextEvent = await eventsRepo.getNextEvent(userId);
    console.log(`[FuturesEngine] nextEvent found: ${!!nextEvent}`);
    const memory = await this.memoryStore.loadAll(userId);
    const personality = await GraphAdapter.getUserPersonality(userId);

    // If no context, return empty (or idle for demo user)
    if (!context) {
      console.log(`[FuturesEngine] No context for ${userId}, returning idle futures.`);
      return {
        userId,
        baseTime,
        horizonMinutes,
        futures: this.buildIdleFutures(memory)
      };
    }

    // If no upcoming event, return trivial futures
    if (!nextEvent) {
      return {
        userId,
        baseTime,
        horizonMinutes,
        futures: this.buildIdleFutures(memory)
      };
    }

    // Resolve destination coordinates if missing
    let destLat = nextEvent.location?.lat;
    let destLon = nextEvent.location?.lon;

    if ((!destLat || !destLon) && nextEvent.location_text) {
      console.log(`[FuturesEngine] Destination coordinates missing, attempting geocode for: ${nextEvent.location_text}`);
      const resolved = await this.geocodingService.geocode(nextEvent.location_text);
      if (resolved) {
        destLat = resolved.lat;
        destLon = resolved.lon;
        console.log(`[FuturesEngine] Geocoded ${nextEvent.location_text} to: ${resolved.displayName} (${destLat}, ${destLon})`);
      }
    }

    // Use multi-mode routing to find best options
    let multiMode: MultiModeRouteResult | null = null;
    const startLat = context.location?.lat;
    const startLon = context.location?.lon;

    if (startLat && startLon && destLat && destLon) {
      try {
        console.log(`[FuturesEngine] Fetching multi-mode routes for user ${userId}...`);
        multiMode = await this.routingService.getMultiModeRoutes(
          { lat: startLat, lon: startLon },
          { lat: destLat, lon: destLon }
        );
        console.log(`[FuturesEngine] Multi-mode result: ${multiMode ? 'SUCCESS' : 'NULL'}`);
        if (multiMode) {
          console.log(`[FuturesEngine] Modes available: ${Object.keys(multiMode).join(', ')}`);
          console.log(`[FuturesEngine] Car duration: ${multiMode.car?.durationSeconds}s`);
        }
      } catch (e) {
        console.warn("[FuturesEngine] Multi-mode routing threw error:", e);
      }
    }

    const route = await this.estimateRoute(context, nextEvent, memory, destLat, destLon);
    const baseBattery = context.battery.level * 100;
    const powerSaverOn = context.battery.power_saver_on;

    const futureParams = { userId, baseTime, nextEvent, route, baseBattery, powerSaverOn, memory, personality };

    const futureA = await this.simulateDoNothing(futureParams);
    const futureB = await this.simulateRecommended({ ...futureParams, multiMode });
    const futureC = await this.simulateAlternate({ ...futureParams, multiMode });

    return {
      userId,
      baseTime,
      horizonMinutes,
      futures: [futureA, futureB, futureC]
    };
  }

  // ──────────────────────────────────────────────────────────────────
  // Shared Helpers
  // ──────────────────────────────────────────────────────────────────

  private async estimateRoute(
    context: ContextSnapshot,
    nextEvent: CalendarEvent,
    memory: MemoryState,
    destLat?: number | null,
    destLon?: number | null
  ): Promise<RouteResult> {
    const startLat = context.location?.lat;
    const startLon = context.location?.lon;

    if (startLat && startLon && destLat && destLon) {
      try {
        return await this.routingService.getRoute(
          { lat: startLat, lon: startLon },
          { lat: destLat, lon: destLon }
        );
      } catch (e) {
        console.warn("[FuturesEngine] Routing failed, falling back to memory");
      }
    }

    // Fallback to memory
    const typicalDuration = memory.commute?.routes?.[0]?.typical_duration_minutes || 20;
    return {
      durationSeconds: typicalDuration * 60,
      distanceMeters: 5000
    };
  }

  private predictBattery(baseBattery: number, minutes: number, mode: 'navigation' | 'idle' | 'mixed', memory: MemoryState, powerSaverOn: boolean = false): number {
    const dischargeRates = memory.battery?.profile?.discharge_rates || { active: 8, standby: 3 };
    let rate = dischargeRates.standby;
    if (mode === 'navigation') rate = dischargeRates.active * 1.5; // Heuristic boost for GPS
    if (mode === 'mixed') rate = (dischargeRates.active + dischargeRates.standby) / 2;

    if (powerSaverOn) {
      rate *= 0.6; // Power saver reduces drain by 40%
    }

    const predicted = baseBattery - (rate * minutes / 60);
    return Math.max(0, predicted);
  }

  private computeStressScore(risks: RiskScore[]): number {
    if (risks.length === 0) return 0.1;
    const scores = risks.map(r => r.score);
    const maxScore = Math.max(...scores);
    const avgScore = scores.reduce((a, b) => a + b, 0) / scores.length;
    return (maxScore * 0.7 + avgScore * 0.3);
  }

  private buildIdleFutures(memory: MemoryState): FutureCard[] {
    return [
      {
        id: "DO_NOTHING",
        title: "Maintain Routine",
        description: "Everything is on track. No upcoming travel or critical risks in the next 2 hours.",
        metrics: {
          endTime: new Date(Date.now() + 120 * 60000).toISOString(),
          etaMinutes: 0,
          batteryPercent: 88,
          expectedLatenessMinutes: 0,
          missedCommitments: 0,
          notificationCount: 12,
          overlapCount: 0,
          stressScore: 0.15
        },
        risks: []
      },
      {
        id: "RECOMMENDED",
        title: "Optimization Plan",
        description: "Proactive battery saving enabled. You'll finish the period with maximum reserve.",
        metrics: {
          endTime: new Date(Date.now() + 120 * 60000).toISOString(),
          etaMinutes: 0,
          batteryPercent: 92,
          expectedLatenessMinutes: 0,
          missedCommitments: 0,
          notificationCount: 4,
          overlapCount: 0,
          stressScore: 0.1
        },
        risks: []
      },
      {
        id: "ALTERNATE",
        title: "Focus Path",
        description: "Aggressive notification filtering to minimize cognitive load during this block.",
        metrics: {
          endTime: new Date(Date.now() + 120 * 60000).toISOString(),
          etaMinutes: 0,
          batteryPercent: 85,
          expectedLatenessMinutes: 0,
          missedCommitments: 0,
          notificationCount: 2,
          overlapCount: 0,
          stressScore: 0.2
        },
        risks: []
      }
    ];
  }

  // ──────────────────────────────────────────────────────────────────
  // 3.2 Future A: Do nothing
  // ──────────────────────────────────────────────────────────────────

  private async simulateDoNothing(params: {
    userId: string;
    baseTime: string;
    nextEvent: CalendarEvent;
    route: RouteResult;
    baseBattery: number;
    powerSaverOn: boolean;
    memory: MemoryState;
    personality: PersonalityAnalysis;
  }): Promise<FutureCard> {
    const { nextEvent, route, baseBattery, powerSaverOn, memory, personality } = params;

    // Assume usual departure (e.g. 10 min before event)
    const departureOffset = memory.habits?.patterns?.typical_lateness ?? 5; // simplified
    const eventStartTime = new Date(nextEvent.start_time).getTime();
    const nowTime = new Date(params.baseTime).getTime();

    // Time user realistically starts moving
    const usualDepartureTime = eventStartTime - (departureOffset * 60000) - route.durationSeconds * 1000;
    const actualDepartureTime = Math.max(nowTime, usualDepartureTime);

    const travelStartMinutesFromNow = (actualDepartureTime - nowTime) / 60000;
    const etaMinutes = route.durationSeconds / 60;
    const arrivalTime = actualDepartureTime + route.durationSeconds * 1000;

    const expectedLatenessMinutes = Math.max(0, (arrivalTime - eventStartTime) / 60000);
    const batteryAtArrival = this.predictBattery(baseBattery, (arrivalTime - nowTime) / 60000, 'mixed', memory, powerSaverOn);

    // Synthetic risks
    const latenessRisk = assessLateness(
      (eventStartTime - actualDepartureTime) / 60000,
      etaMinutes,
      memory.habits?.patterns?.typical_lateness ?? 5,
      nextEvent.title,
      undefined,
      [],
      personality
    );
    const batteryRisk = assessBattery(
      baseBattery,
      (arrivalTime - nowTime) / 60000,
      memory.battery?.profile?.discharge_rates?.active ?? 8,
      false, // isCharging
      powerSaverOn,
      "BATTERY", // nodeId
      [], // preferences
      personality
    );

    const risks = [latenessRisk, batteryRisk].filter(r => r.score > 0.4);

    return {
      id: "DO_NOTHING",
      title: "Stick to Routine",
      description: "You usually leave with a tight buffer. This path assumes no changes to your current habits.",
      metrics: {
        endTime: nextEvent.end_time,
        etaMinutes: Math.round(etaMinutes),
        batteryPercent: Math.round(batteryAtArrival),
        expectedLatenessMinutes: Math.round(expectedLatenessMinutes),
        missedCommitments: expectedLatenessMinutes > 5 ? 1 : 0,
        notificationCount: 34,
        overlapCount: 3,
        stressScore: this.computeStressScore([latenessRisk, batteryRisk])
      },
      risks
    };
  }

  // ──────────────────────────────────────────────────────────────────
  // 3.3 Future B: Recommended intervention
  // ──────────────────────────────────────────────────────────────────

  private async simulateRecommended(params: {
    userId: string;
    baseTime: string;
    nextEvent: CalendarEvent;
    route: RouteResult;
    baseBattery: number;
    powerSaverOn: boolean;
    memory: MemoryState;
    personality: PersonalityAnalysis;
    multiMode: MultiModeRouteResult | null;
  }): Promise<FutureCard> {
    let { nextEvent, route, baseBattery, powerSaverOn, memory, personality, multiMode } = params;

    const allModes = multiMode ? [
      { name: "Car/Taxi", data: multiMode.car },
      { name: "Auto Rickshaw", data: multiMode.auto },
      { name: "Two-Wheeler", data: multiMode.twoWheeler },
      { name: "Public Transit", data: multiMode.transit },
      { name: "Walking", data: multiMode.walk }
    ].filter(m => m.data.durationSeconds > 0)
     .sort((a, b) => a.data.durationSeconds - b.data.durationSeconds) : [];

    // Pick BEST mode if available
    let transportMode = "Car/Taxi";
    let alternateModes: { mode: string; etaMinutes: number }[] = [];

    if (allModes.length > 0) {
      const best = allModes[0];
      route = best.data;
      transportMode = best.name;
      
      // Also show other modes as alternates even in Recommended
      alternateModes = allModes.slice(1).map(m => ({
        mode: m.name,
        etaMinutes: Math.round(m.data.durationSeconds / 60)
      }));
    }

    // Leave slightly earlier or now
    const nowTime = new Date(params.baseTime).getTime();
    const eventStartTime = new Date(nextEvent.start_time).getTime();

    // Optimization: Leave now to maximize buffer
    const departureTime = nowTime;
    const etaMinutes = route.durationSeconds / 60;
    const arrivalTime = departureTime + route.durationSeconds * 1000;

    const expectedLatenessMinutes = Math.max(0, (arrivalTime - eventStartTime) / 60000);

    // RECOMMENDED scenario assumes battery saver is ON (either it was already on, or we turn it on)
    const batteryAtArrival = this.predictBattery(baseBattery, (arrivalTime - nowTime) / 60000, 'navigation', memory, true);

    const latenessRisk = assessLateness(
      (eventStartTime - departureTime) / 60000,
      etaMinutes,
      0, // Optimized
      nextEvent.title,
      undefined,
      [],
      personality
    );
    const batteryRisk = assessBattery(
      baseBattery,
      (arrivalTime - nowTime) / 60000,
      memory.battery?.profile?.discharge_rates?.active ?? 8,
      false,
      true, // Battery saver assumed in recommendation
      "BATTERY",
      [],
      personality
    );

    const risks = [latenessRisk, batteryRisk].filter(r => r.score > 0.4);

    return {
      id: "RECOMMENDED",
      title: "Pulse Recommendation",
      description: `Leave now via ${transportMode} and enable Battery Saver. This ensures the fastest arrival.`,
      metrics: {
        endTime: nextEvent.end_time,
        etaMinutes: Math.round(etaMinutes),
        batteryPercent: Math.round(batteryAtArrival),
        expectedLatenessMinutes: Math.round(expectedLatenessMinutes),
        transportMode,
        alternateModes,
        missedCommitments: 0,
        notificationCount: 18,
        overlapCount: 1,
        stressScore: this.computeStressScore([latenessRisk, batteryRisk])
      },
      risks
    };
  }

  // ──────────────────────────────────────────────────────────────────
  // 3.4 Future C: Alternate strategy (Charge then Leave)
  // ──────────────────────────────────────────────────────────────────

  private async simulateAlternate(params: {
    userId: string;
    baseTime: string;
    nextEvent: CalendarEvent;
    route: RouteResult;
    baseBattery: number;
    powerSaverOn: boolean;
    memory: MemoryState;
    personality: PersonalityAnalysis;
    multiMode: MultiModeRouteResult | null;
  }): Promise<FutureCard> {
    let { nextEvent, route, baseBattery, powerSaverOn, memory, personality, multiMode } = params;

    // Pick 2nd BEST mode if available, otherwise stick to Charge & Go logic but with a mode
    let transportMode = "Car/Taxi";
    let alternateDescription = "Charge for 15 minutes before leaving. You arrive slightly later but with significantly more battery.";
    let chargeDuration = 15;
    const chargeRate = 1.5;

    const allModes = multiMode ? [
      { name: "Car/Taxi", data: multiMode.car },
      { name: "Auto Rickshaw", data: multiMode.auto },
      { name: "Two-Wheeler", data: multiMode.twoWheeler },
      { name: "Public Transit", data: multiMode.transit },
      { name: "Walking", data: multiMode.walk }
    ].filter(m => m.data.durationSeconds > 0)
      .sort((a, b) => a.data.durationSeconds - b.data.durationSeconds) : [];

    console.log(`[FuturesEngine] simulateAlternate: allModes.length = ${allModes.length}`);

    let alternateModes: { mode: string; etaMinutes: number }[] = [];

    if (allModes.length >= 2) {
      // Use 2nd best mode as the primary for this card
      const secondBest = allModes[1];
      route = secondBest.data;
      transportMode = secondBest.name;
      alternateDescription = `Use ${transportMode} (${Math.round(route.durationSeconds / 60)}m) as a secondary option. Other modes also available.`;
      chargeDuration = 0;

      // Populate metadata for all other modes
      alternateModes = allModes.slice(1).map(m => ({
        mode: m.name,
        etaMinutes: Math.round(m.data.durationSeconds / 60)
      }));
    }

    const nowTime = new Date(params.baseTime).getTime();
    const eventStartTime = new Date(nextEvent.start_time).getTime();

    const departureTime = nowTime + chargeDuration * 60000;
    const arrivalTime = departureTime + route.durationSeconds * 1000;

    const batteryAfterCharge = Math.min(100, baseBattery + (chargeDuration * chargeRate));
    const batteryAtArrival = this.predictBattery(batteryAfterCharge, route.durationSeconds / 60, 'navigation', memory, powerSaverOn);

    const expectedLatenessMinutes = Math.max(0, (arrivalTime - eventStartTime) / 60000);
    const etaMinutes = route.durationSeconds / 60;

    const latenessRisk = assessLateness(
      (eventStartTime - departureTime) / 60000,
      etaMinutes,
      0,
      nextEvent.title,
      undefined,
      [],
      personality
    );
    const batteryRisk = assessBattery(
      batteryAfterCharge,
      route.durationSeconds / 60,
      memory.battery?.profile?.discharge_rates?.active ?? 8,
      false,
      "BATTERY",
      [],
      personality
    );

    const risks = [latenessRisk, batteryRisk].filter(r => r.score > 0.4);

    return {
      id: "ALTERNATE",
      title: multiMode && multiMode.car.durationSeconds > 0 ? `Switch to ${transportMode}` : "Charge & Go",
      description: alternateDescription,
      metrics: {
        endTime: nextEvent.end_time,
        etaMinutes: Math.round(etaMinutes),
        batteryPercent: Math.round(batteryAtArrival),
        expectedLatenessMinutes: Math.round(expectedLatenessMinutes),
        transportMode,
        alternateModes,
        missedCommitments: expectedLatenessMinutes > 5 ? 1 : 0,
        notificationCount: 9,
        overlapCount: 0,
        stressScore: this.computeStressScore([latenessRisk, batteryRisk])
      },
      risks
    };
  }
}

export const futuresEngine = new FuturesEngine(riskEngine, routingService, memoryStore, geocodingService);
