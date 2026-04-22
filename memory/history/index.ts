import { loadJson } from '../store';

/**
 * Retrieves recent behavior patterns from the history store.
 * For the sprint, this pulls from the demo events file.
 */
export async function getRecentPatterns(): Promise<any[]> {
    const events = await loadJson('demo-events.json');
    if (!events) {
        return [];
    }
    // Logic to extract patterns (delays, battery drain) could be added here.
    return events;
}
