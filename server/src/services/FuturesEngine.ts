import { RiskEngineService, riskEngine } from "./RiskEngineService";
import { RoutingService, routingService, RouteResult } from "./RoutingService";
import { MemoryStore, memoryStore } from "./MemoryStore";
import { contextSnapshotRepo } from "../db/ContextSnapshotRepository";
import { eventsRepo } from "../db/EventsRepository";
import { FuturesResult, FutureCard, FutureId } from "../types/futures";
import { CalendarEvent, ContextSnapshot } from "../../../shared/context_snapshot";
import { MemoryState } from "../../../shared/memory";
import { RiskScore } from "../types/risk";
import { assessLateness, assessBattery } from "./RiskEngine";

class FuturesEngine {
  constructor(
    private riskEngine: RiskEngineService,
    private routingService: RoutingService,
    private memoryStore: MemoryStore
  ) {}

  async computeForUser(userId: string): Promise<FuturesResult> {
    const now = new Date();
    const baseTime = now.toISOString();
    const horizonMinutes = 120;

    // Get current context & next event
    const context = await contextSnapshotRepo.findLatestByUser(userId);
    const nextEvent = await eventsRepo.getNextEvent(userId);
    const memory = await this.memoryStore.loadAll(userId);

    // If no context, return empty
    if (!context) {
      return {
        userId,
        baseTime,
        horizonMinutes,
        futures: []
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

    // Use routing + battery profile once as base
    const route = await this.estimateRoute(context, nextEvent, memory);
    const baseBattery = context.battery.level * 100;

    const futureA = await this.simulateDoNothing({ userId, baseTime, nextEvent, route, baseBattery, memory });
    const futureB = await this.simulateRecommended({ userId, baseTime, nextEvent, route, baseBattery, memory });
    const futureC = await this.simulateAlternate({ userId, baseTime, nextEvent, route, baseBattery, memory });

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

  private async estimateRoute(context: ContextSnapshot, nextEvent: CalendarEvent, memory: MemoryState): Promise<RouteResult> {
    if (context.location?.lat && context.location?.lon && nextEvent.location?.lat && nextEvent.location?.lon) {
      try {
        return await this.routingService.getRoute(
          { lat: context.location.lat, lon: context.location.lon },
          { lat: nextEvent.location.lat, lon: nextEvent.location.lon }
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

  private predictBattery(baseBattery: number, minutes: number, mode: 'navigation' | 'idle' | 'mixed', memory: MemoryState): number {
    const dischargeRates = memory.battery?.profile?.discharge_rates || { active: 8, standby: 3 };
    let rate = dischargeRates.standby;
    if (mode === 'navigation') rate = dischargeRates.active * 1.5; // Heuristic boost for GPS
    if (mode === 'mixed') rate = (dischargeRates.active + dischargeRates.standby) / 2;
    
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
        title: "Stay the Course",
        description: "No immediate appointments. You can continue your current routine.",
        metrics: {
          endTime: new Date(Date.now() + 120 * 60000).toISOString(),
          missedCommitments: 0,
          stressScore: 0.1
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
    memory: MemoryState;
  }): Promise<FutureCard> {
    const { nextEvent, route, baseBattery, memory } = params;
    
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
    const batteryAtArrival = this.predictBattery(baseBattery, (arrivalTime - nowTime) / 60000, 'mixed', memory);

    // Synthetic risks
    const latenessRisk = assessLateness(
      (eventStartTime - actualDepartureTime) / 60000,
      etaMinutes,
      memory.habits?.patterns?.typical_lateness ?? 5,
      nextEvent.title
    );
    const batteryRisk = assessBattery(baseBattery, (arrivalTime - nowTime) / 60000, memory.battery?.profile?.discharge_rates?.active ?? 8);
    
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
    memory: MemoryState;
  }): Promise<FutureCard> {
    const { nextEvent, route, baseBattery, memory } = params;
    
    // Leave slightly earlier or now
    const nowTime = new Date(params.baseTime).getTime();
    const eventStartTime = new Date(nextEvent.start_time).getTime();
    
    // Optimization: Leave now to maximize buffer
    const departureTime = nowTime;
    const etaMinutes = route.durationSeconds / 60;
    const arrivalTime = departureTime + route.durationSeconds * 1000;
    
    const expectedLatenessMinutes = Math.max(0, (arrivalTime - eventStartTime) / 60000);
    
    // Battery Saver Heuristic: 30% reduction in discharge
    const saverMemory = JSON.parse(JSON.stringify(memory));
    if (saverMemory.battery?.profile?.discharge_rates) {
      saverMemory.battery.profile.discharge_rates.active *= 0.7;
    }
    const batteryAtArrival = this.predictBattery(baseBattery, (arrivalTime - nowTime) / 60000, 'navigation', saverMemory);

    const latenessRisk = assessLateness(
      (eventStartTime - departureTime) / 60000,
      etaMinutes,
      0, // Optimized
      nextEvent.title
    );
    const batteryRisk = assessBattery(baseBattery, (arrivalTime - nowTime) / 60000, saverMemory.battery?.profile?.discharge_rates?.active ?? 5.6);
    
    const risks = [latenessRisk, batteryRisk].filter(r => r.score > 0.4);

    return {
      id: "RECOMMENDED",
      title: "Pulse Recommendation",
      description: "Leave now and enable Battery Saver. This ensures on-time arrival and preserves device power.",
      metrics: {
        endTime: nextEvent.end_time,
        etaMinutes: Math.round(etaMinutes),
        batteryPercent: Math.round(batteryAtArrival),
        expectedLatenessMinutes: Math.round(expectedLatenessMinutes),
        missedCommitments: 0,
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
    memory: MemoryState;
  }): Promise<FutureCard> {
    const { nextEvent, route, baseBattery, memory } = params;
    
    // Strategy: Charge for 15 minutes, then leave.
    const chargeDuration = 15;
    const chargeRate = 1.5; // 1.5% per minute heuristic
    
    const nowTime = new Date(params.baseTime).getTime();
    const eventStartTime = new Date(nextEvent.start_time).getTime();
    
    const departureTime = nowTime + chargeDuration * 60000;
    const arrivalTime = departureTime + route.durationSeconds * 1000;
    
    const batteryAfterCharge = Math.min(100, baseBattery + (chargeDuration * chargeRate));
    const batteryAtArrival = this.predictBattery(batteryAfterCharge, route.durationSeconds / 60, 'navigation', memory);
    
    const expectedLatenessMinutes = Math.max(0, (arrivalTime - eventStartTime) / 60000);
    const etaMinutes = route.durationSeconds / 60;

    const latenessRisk = assessLateness(
      (eventStartTime - departureTime) / 60000,
      etaMinutes,
      0,
      nextEvent.title
    );
    const batteryRisk = assessBattery(batteryAfterCharge, route.durationSeconds / 60, memory.battery?.profile?.discharge_rates?.active ?? 8);
    
    const risks = [latenessRisk, batteryRisk].filter(r => r.score > 0.4);

    return {
      id: "ALTERNATE",
      title: "Charge & Go",
      description: "Charge for 15 minutes before leaving. You arrive slightly later but with significantly more battery.",
      metrics: {
        endTime: nextEvent.end_time,
        etaMinutes: Math.round(etaMinutes),
        batteryPercent: Math.round(batteryAtArrival),
        expectedLatenessMinutes: Math.round(expectedLatenessMinutes),
        missedCommitments: expectedLatenessMinutes > 5 ? 1 : 0,
        stressScore: this.computeStressScore([latenessRisk, batteryRisk])
      },
      risks
    };
  }
}

export const futuresEngine = new FuturesEngine(riskEngine, routingService, memoryStore);
