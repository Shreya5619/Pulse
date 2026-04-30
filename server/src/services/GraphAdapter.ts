import { ContextSnapshot } from '../../../shared/context_snapshot';
import { neo4jService } from './Neo4jService';
import { PersonalityAnalysis } from './PersonalityAnalyzer';

export class GraphAdapter {
  /**
   * Translates a ContextSnapshot into Neo4j mutations to update the Digital Twin.
   */
  static async applySnapshotToNeo4j(userId: string, snapshot: ContextSnapshot): Promise<void> {
    console.log(`[Neo4j Adapter] Applying snapshot for user: ${userId}`);
    const session = await neo4jService.getSession();
    
    try {
      await session.executeWrite(async (tx) => {
        // 1. Upsert Person
        await tx.run(
          `MERGE (p:Person {id: $userId})
           SET p.lastSeen = $timestamp`,
          { userId, timestamp: snapshot.timestamp }
        );

        // 2. Upsert Now (Current Context Pointer)
        await tx.run(
          `MERGE (n:Now {userId: $userId})
           SET n.timestamp = $timestamp,
               n.lat = $lat,
               n.lon = $lon`,
          { 
            userId, 
            timestamp: snapshot.timestamp,
            lat: snapshot.location.lat,
            lon: snapshot.location.lon
          }
        );

        // 3. Upsert Events & Locations
        const events = [];
        if (snapshot.calendar.next_event) events.push(snapshot.calendar.next_event);
        if (snapshot.calendar.upcoming_events) events.push(...snapshot.calendar.upcoming_events);

        if (events.length > 0) {
          await tx.run(
            `MATCH (p:Person {id: $userId})
             UNWIND $events AS ev
             MERGE (e:Event {id: ev.id})
             SET e.title = ev.title,
                 e.startTime = ev.start_time,
                 e.endTime = ev.end_time,
                 e.importance = ev.importance,
                 e.locationText = ev.location_text
             MERGE (p)-[:HAS_EVENT]->(e)
             
             WITH e, ev
             WHERE ev.location IS NOT NULL
             MERGE (loc:Location {id: apoc.util.md5([ev.location.lat, ev.location.lon])})
             SET loc.name = ev.location_text,
                 loc.lat = ev.location.lat,
                 loc.lon = ev.location.lon
             MERGE (e)-[:AT_LOCATION]->(loc)`,
            { userId, events }
          );
        }

        // 4. Upsert Battery State
        await tx.run(
          `MATCH (p:Person {id: $userId})
           CREATE (b:BatteryState {
             id: $snapshotId,
             level: $level,
             isCharging: $isCharging,
             timestamp: $timestamp
           })
           MERGE (p)-[:HAS_BATTERY]->(b)
           
           WITH p, b
           MATCH (p)-[:HAS_BATTERY]->(prev:BatteryState)
           WHERE prev.id <> b.id AND prev.timestamp < b.timestamp
           WITH b, prev ORDER BY prev.timestamp DESC LIMIT 1
           MERGE (prev)-[:NEXT]->(b)`,
          { 
            userId, 
            snapshotId: snapshot.id,
            level: snapshot.battery.level,
            isCharging: snapshot.battery.is_charging,
            timestamp: snapshot.timestamp
          }
        );

        // 5. Upsert Notifications
        if (snapshot.notifications.length > 0) {
          await tx.run(
            `MATCH (p:Person {id: $userId})
             UNWIND $notifications AS n
             MERGE (notif:Notification {id: n.id})
             SET notif.app = n.app_package,
                 notif.sender = n.sender,
                 notif.title = n.title,
                 notif.body = n.body,
                 notif.category = n.category,
                 notif.postedAt = n.posted_at
             MERGE (p)-[:HAS_NOTIFICATION]->(notif)`,
            { userId, notifications: snapshot.notifications }
          );
        }
      });
      console.log(`[Neo4j Adapter] Successfully synced snapshot for ${userId}`);
    } catch (error) {
      console.error('[Neo4j Adapter] Error applying snapshot:', error);
    } finally {
      await session.close();
    }
  }

  /**
   * Updates risk scores on nodes in Neo4j based on the RiskEngine results.
   */
  static async updateRiskInNeo4j(userId: string, riskSnapshot: any): Promise<void> {
    const session = await neo4jService.getSession();
    try {
      await session.executeWrite(async (tx) => {
        const risks = riskSnapshot.risks || [];
        for (const risk of risks) {
          if (risk.nodeId) {
            if (risk.nodeId.startsWith('APP_')) {
              const eventId = risk.nodeId.replace('APP_', '');
              await tx.run(
                `MATCH (e:Event {id: $eventId})
                 SET e.riskScore = $score`,
                { eventId, score: risk.score }
              );
            } else if (risk.nodeId === 'BATTERY') {
              await tx.run(
                `MATCH (p:Person {id: $userId})-[:HAS_BATTERY]->(b:BatteryState)
                 WITH b ORDER BY b.timestamp DESC LIMIT 1
                 SET b.riskScore = $score`,
                { userId, score: risk.score }
              );
            }
          }
        }
      });
    } catch (error) {
      console.error('[Neo4j Adapter] Error updating risks:', error);
    } finally {
      await session.close();
    }
  }

  /**
   * Fetches structured preferences for a user to adjust risk scoring.
   */
  static async getUserPreferences(userId: string): Promise<any[]> {
    const session = await neo4jService.getSession();
    try {
      const result = await session.run(
        `MATCH (p:Person {id: $userId})-[:HAS_PREFERENCE]->(pr:Preference)
         RETURN pr.category as category, pr.scope as scope, pr.value as value, pr.confidence as confidence`,
        { userId }
      );
      return result.records.map(r => ({
        category: r.get('category'),
        scope: r.get('scope'),
        value: r.get('value'),
        confidence: r.get('confidence')
      }));
    } catch (error) {
      console.error('[Neo4j Adapter] Error fetching user preferences:', error);
      return [];
    } finally {
      await session.close();
    }
  }

  /**
   * Fetches the derived personality traits, interests, and current sentiment for a user.
   */
  static async getUserPersonality(userId: string): Promise<PersonalityAnalysis> {
    const session = await neo4jService.getSession();
    try {
      const result = await session.run(
        `MATCH (p:Person {id: $userId})
         OPTIONAL MATCH (p)-[:HAS_TRAIT]->(t:Trait)
         OPTIONAL MATCH (p)-[:INTERESTED_IN]->(i:Interest)
         OPTIONAL MATCH (p)-[:FEELS]->(s:Sentiment)
         RETURN collect(distinct t.name) as traits, 
                collect(distinct i.name) as interests, 
                s.value as sentiment`,
        { userId }
      );
      
      if (result.records.length === 0) {
        return { traits: [], interests: [], sentiment: "Neutral" };
      }
      
      const record = result.records[0];
      return {
        traits: record.get('traits') || [],
        interests: record.get('interests') || [],
        sentiment: record.get('sentiment') || "Neutral"
      };
    } catch (error) {
      console.error('[Neo4j Adapter] Error fetching user personality:', error);
      return { traits: [], interests: [], sentiment: "Neutral" };
    } finally {
      await session.close();
    }
  }

  /**
   * Upserts structured preferences and patterns for a user.
   */
  static async applyPreferencesToNeo4j(userId: string, data: { preferences: any[], patterns: any[] }): Promise<void> {
    const session = await neo4jService.getSession();
    try {
      await session.executeWrite(async (tx) => {
        // 1. Upsert Preferences
        if (data.preferences.length > 0) {
          await tx.run(
            `MATCH (p:Person {id: $userId})
             UNWIND $preferences AS pref
             MERGE (pr:Preference {id: apoc.util.md5([$userId, pref.category, pref.scope])})
             SET pr.category = pref.category,
                 pr.scope = pref.scope,
                 pr.value = pref.value,
                 pr.confidence = pref.confidence,
                 pr.lastUpdated = datetime()
             MERGE (p)-[:HAS_PREFERENCE]->(pr)`,
            { userId, preferences: data.preferences }
          );
        }

        // 2. Upsert Patterns
        if (data.patterns.length > 0) {
          await tx.run(
            `MATCH (p:Person {id: $userId})
             UNWIND $patterns AS pat
             MERGE (pn:Pattern {id: apoc.util.md5([$userId, pat.description])})
             SET pn.description = pat.description,
                 pn.scope = pat.scope,
                 pn.lastUpdated = datetime()
             MERGE (p)-[:HAS_PATTERN]->(pn)`,
            { userId, patterns: data.patterns }
          );
        }
      });
    } catch (error) {
      console.error('[Neo4j Adapter] Error applying preferences:', error);
    } finally {
      await session.close();
    }
  }

  /**
   * Upserts personality traits, interests, and sentiment for a user.
   */
  static async applyPersonalityToNeo4j(userId: string, analysis: PersonalityAnalysis): Promise<void> {
    const session = await neo4jService.getSession();
    try {
      await session.executeWrite(async (tx) => {
        // 1. Upsert Traits
        if (analysis.traits.length > 0) {
          await tx.run(
            `MERGE (p:Person {id: $userId})
             WITH p
             UNWIND $traits AS trait
             MERGE (t:Trait {id: apoc.util.md5([$userId, trait])})
             SET t.name = trait, t.lastUpdated = datetime()
             MERGE (p)-[:HAS_TRAIT]->(t)`,
            { userId, traits: analysis.traits }
          );
        }

        // 2. Upsert Interests
        if (analysis.interests.length > 0) {
          await tx.run(
            `MERGE (p:Person {id: $userId})
             WITH p
             UNWIND $interests AS interest
             MERGE (i:Interest {id: apoc.util.md5([$userId, interest])})
             SET i.name = interest, i.lastUpdated = datetime()
             MERGE (p)-[:INTERESTED_IN]->(i)`,
            { userId, interests: analysis.interests }
          );
        }

        // 3. Upsert Sentiment
        if (analysis.sentiment) {
          await tx.run(
            `MERGE (p:Person {id: $userId})
             MERGE (s:Sentiment {id: $userId + "_sentiment"})
             SET s.value = $sentiment, s.lastUpdated = datetime()
             MERGE (p)-[:FEELS]->(s)`,
            { userId, sentiment: analysis.sentiment }
          );
        }
      });
    } catch (error) {
      console.error('[Neo4j Adapter] Error applying personality:', error);
    } finally {
      await session.close();
    }
  }

  /**
   * Fetches a subgraph for the Digital Twin visualization.
   */
  static async getTwinSubgraph(userId: string, horizonMinutes: number = 240): Promise<any> {
    const session = await neo4jService.getSession();
    try {
      const now = new Date().toISOString();
      const horizon = new Date(Date.now() + horizonMinutes * 60000).toISOString();

      const result = await session.run(
        `MATCH (p:Person {id: $userId})
         OPTIONAL MATCH (p)-[r1:HAS_EVENT]->(e:Event)
         WHERE e.startTime >= $now AND e.startTime <= $horizon
         OPTIONAL MATCH (e)-[r2:AT_LOCATION]->(loc:Location)
         OPTIONAL MATCH (p)-[:HAS_BATTERY]->(b:BatteryState)
         WITH p, e, loc, b ORDER BY b.timestamp DESC LIMIT 5
         OPTIONAL MATCH (p)-[:HAS_NOTIFICATION]->(n:Notification)
         WHERE n.postedAt >= $now_minus_60
         WITH p, e, loc, b, n ORDER BY n.postedAt DESC
         WITH p, e, loc, b, collect(distinct n)[0..10] as notifications
         OPTIONAL MATCH (p)-[:HAS_PREFERENCE]->(pr:Preference)
         OPTIONAL MATCH (p)-[:HAS_TRAIT]->(t:Trait)
         OPTIONAL MATCH (p)-[:INTERESTED_IN]->(i:Interest)
         OPTIONAL MATCH (p)-[:FEELS]->(s:Sentiment)
         RETURN p, collect(distinct e) as events, collect(distinct loc) as locations,
                collect(distinct b) as batteries, notifications,
                collect(distinct pr) as preferences,
                collect(distinct t) as traits,
                collect(distinct i) as interests,
                s as sentiment`,
        { 
          userId, 
          now, 
          horizon,
          now_minus_60: new Date(Date.now() - 60 * 60000).toISOString()
        }
      );

      return this.formatNodesAndEdges(result, userId);
    } catch (error) {
        console.error('[Neo4j Adapter] Error fetching subgraph:', error);
        return { nodes: [], edges: [] };
    } finally {
      await session.close();
    }
  }

  private static formatNodesAndEdges(result: any, userId: string): any {
    if (result.records.length === 0) {
        // Return a dummy person node if nothing exists yet to avoid empty screen
        return {
            nodes: [{ id: 'PERSON_' + userId, label: 'Guardian User (Syncing...)', type: 'person', x: 200, y: 50, risk: 0 }],
            edges: []
        };
    }
    const record = result.records[0];

    const nodes: any[] = [];
    const edges: any[] = [];

    // 1. Person
    const person = record.get('p');
    if (person) {
        nodes.push({
            id: 'PERSON_' + person.properties.id,
            label: 'Guardian User',
            type: 'person',
            x: 500, y: 100,
            risk: 0
        });
    }

    // 2. Events & Locations
    const events = record.get('events');
    events.forEach((e: any, idx: number) => {
        const eId = 'EVENT_' + e.properties.id;
        nodes.push({
            id: eId,
            label: e.properties.title,
            type: 'event',
            x: 200 + (idx * 300),
            y: 500,
            risk: e.properties.riskScore || 0
        });
        edges.push({ from: 'PERSON_' + userId, to: eId, type: 'HAS_EVENT' });
    });

    // 3. Battery
    const batteries = record.get('batteries');
    if (batteries.length > 0) {
        const b = batteries[0];
        const bId = 'BATT_' + b.properties.id;
        nodes.push({
            id: bId,
            label: `Battery: ${Math.round(b.properties.level * 100)}%`,
            type: 'battery',
            x: 200, y: 250,
            risk: b.properties.riskScore || 0
        });
        edges.push({ from: 'PERSON_' + userId, to: bId, type: 'HAS_BATTERY' });
    }

    // 4. Notifications
    const notifs = record.get('notifications');
    notifs.forEach((n: any, idx: number) => {
        const nId = 'NOTIF_' + n.properties.id;
        const sender = n.properties.sender || 'System';
        const title = n.properties.title ? `: ${n.properties.title}` : '';
        const body = n.properties.body ? `\n${n.properties.body}` : '';

        nodes.push({
            id: nId,
            label: `${sender}${title}${body}`,
            type: 'notification',
            x: 800, y: 250 + (idx * 80),
            risk: 0
        });
        edges.push({ from: 'PERSON_' + userId, to: nId, type: 'HAS_NOTIFICATION' });
    });

    // 5. Preferences
    const prefs = record.get('preferences');
    prefs.forEach((pr: any, idx: number) => {
        const prId = 'PREF_' + pr.properties.id;
        nodes.push({
            id: prId,
            label: `${pr.properties.category}: ${pr.properties.value}`,
            type: 'preference',
            x: 100, y: 600 + (idx * 80),
            risk: 0
        });
        edges.push({ from: 'PERSON_' + userId, to: prId, type: 'HAS_PREFERENCE' });
    });

    // 6. Personality Traits
    const traits = record.get('traits');
    traits.forEach((t: any, idx: number) => {
        const tId = 'TRAIT_' + t.properties.id;
        nodes.push({
            id: tId,
            label: t.properties.name,
            type: 'trait',
            x: 100, y: 150 + (idx * 60),
            risk: 0
        });
        edges.push({ from: 'PERSON_' + userId, to: tId, type: 'HAS_TRAIT' });
    });

    // 7. Interests
    const interests = record.get('interests');
    interests.forEach((i: any, idx: number) => {
        const iId = 'INTEREST_' + i.properties.id;
        nodes.push({
            id: iId,
            label: i.properties.name,
            type: 'interest',
            x: 900, y: 500 + (idx * 60),
            risk: 0
        });
        edges.push({ from: 'PERSON_' + userId, to: iId, type: 'INTERESTED_IN' });
    });

    // 8. Sentiment
    const sentiment = record.get('sentiment');
    if (sentiment) {
        const sId = 'SENTIMENT_' + sentiment.properties.id;
        nodes.push({
            id: sId,
            label: `Mood: ${sentiment.properties.value}`,
            type: 'sentiment',
            x: 500, y: -50,
            risk: 0
        });
        edges.push({ from: 'PERSON_' + userId, to: sId, type: 'FEELS' });
    }

    return { nodes, edges };
  }
}
