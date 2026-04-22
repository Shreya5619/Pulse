import * as fs from 'fs';
import * as path from 'path';

/**
 * Simple JSON-backed store for the Pulse sprint.
 * Provides basic persistence for demo events and state.
 */

const DATA_DIR = path.join(process.cwd(), 'data');

/**
 * Loads a JSON file from the data directory.
 * @param filename - The name of the file (e.g., 'demo-user.json')
 */
export async function loadJson(filename: string): Promise<any> {
    const filePath = path.join(DATA_DIR, filename);
    try {
        const content = fs.readFileSync(filePath, 'utf8');
        return JSON.parse(content);
    } catch (error) {
        console.error(`Error loading JSON file ${filename}:`, error);
        return null;
    }
}

/**
 * Saves a demo event to the internal store.
 * For the sprint, this just logs to console and returns a promise.
 */
export async function saveDemoEvent(event: any): Promise<void> {
    console.log("[MemoryStore] Saving demo event:", JSON.stringify(event, null, 2));
    
    // TODO: In a real implementation, this would append to a JSON file or database.
    return Promise.resolve();
}
