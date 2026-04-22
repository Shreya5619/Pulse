import { loadJson } from '../store';

/**
 * Retrieves the profile of the current demo user.
 * Includes preferences, trusted contacts, and quiet hours.
 */
export async function getUserProfile(): Promise<any> {
    const user = await loadJson('demo-user.json');
    if (!user) {
        throw new Error("User profile not found. Ensure demo-user.json exists in data directory.");
    }
    return user;
}
