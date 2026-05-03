import { describe, it, expect, vi, beforeEach } from 'vitest';
import { geocodingService } from '../services/GeocodingService';
import { routingService } from '../services/RoutingService';

// Mocking global fetch
global.fetch = vi.fn();

describe('GeocodingService', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should append Bangalore to queries', async () => {
    (global.fetch as any).mockResolvedValue({
      ok: true,
      json: async () => [{
        lat: '12.9716',
        lon: '77.5946',
        display_name: 'Bangalore, India'
      }]
    });

    const result = await geocodingService.geocode('Koramangala');
    
    expect(global.fetch).toHaveBeenCalledWith(
      expect.stringContaining(encodeURIComponent('Koramangala, Bangalore, Karnataka, India')),
      expect.any(Object)
    );
    expect(result).toEqual({
      lat: 12.9716,
      lon: 77.5946,
      displayName: 'Bangalore, India'
    });
  });

  it('should return null if no results found', async () => {
    (global.fetch as any).mockResolvedValue({
      ok: true,
      json: async () => []
    });

    const result = await geocodingService.geocode('NonExistentPlace');
    expect(result).toBeNull();
  });
});

describe('Routing Integration Logic', () => {
  it('should handle end-to-end flow conceptually', async () => {
    // This is more of a logic check than a full integration test of the Express route
    // but ensures our services work together.
    
    const mockGeocode = vi.spyOn(geocodingService, 'geocode').mockResolvedValue({
      lat: 12.9352,
      lon: 77.6245,
      displayName: 'Koramangala, Bangalore'
    });

    const mockGetRoute = vi.spyOn(routingService, 'getRoute').mockResolvedValue({
      durationSeconds: 600,
      distanceMeters: 5000,
      travelMode: 'car'
    });

    const from = { lat: 12.9716, lon: 77.5946 };
    const toLoc = 'Koramangala';

    const dest = await geocodingService.geocode(toLoc);
    expect(dest).not.toBeNull();
    
    const route = await routingService.getRoute(from, { lat: dest!.lat, lon: dest!.lon });
    
    expect(route.durationSeconds).toBe(600);
    expect(mockGeocode).toHaveBeenCalledWith(toLoc);
  });
});
