# OSRM & Routing Integration

Pulse uses **OSRM (Open Source Routing Machine)** for high-performance, private, and offline-capable routing. This service is self-hosted via Docker and integrated into the Pulse intelligence pipeline.

## 1. Setup & Infrastructure

### Docker Configuration
The OSRM engine runs in a dedicated container using the `osrm/osrm-backend` image.
- **Port**: `5000` (internal)
- **Data Volume**: `./osrm-data`

### Data Provisioning
We use a specialized pipeline to minimize resource usage:
1. **Source**: Karnataka state extract from OpenStreetMap France.
2. **Clipping**: The data is automatically clipped to the **Bangalore metropolitan area** (approx. 49MB) using `osmium-tool`.
3. **Processing**: The clipped data is extracted, partitioned, and customized using the `car.lua` profile.

**To setup/refresh data**:
```powershell
.\scripts\setup-osrm.ps1
```

---

## 2. Backend Routing Service

The `RoutingService` (`server/src/services/RoutingService.ts`) abstracts the OSRM details and provides a robust API for other agents.

### Features
- **In-Memory Caching**: Routes are cached based on coordinate pairs (rounded to 4 decimal places) to reduce redundant OSRM calls.
- **Fallback Heuristic**: If OSRM is unavailable, the service returns a safe heuristic (30 min / 5 km) to prevent system failure.
- **Environment Driven**: The base URL is configured via `OSRM_BASE_URL` in `.env`.

---

## 3. API Endpoints

The following endpoints are available under `/api/routing/`:

### 3.1 Get ETA (Generic)
Returns duration and distance between two arbitrary points.
- **URL**: `GET /api/routing/eta`
- **Params**: `fromLat`, `fromLon`, `toLat`, `toLon`
- **Example**: `GET http://localhost:8080/api/routing/eta?fromLat=12.9716&fromLon=77.5946&toLat=12.9859&toLon=77.6387`

### 3.2 Next Appointment ETA
Automatically calculates the ETA from the user's current location to their next scheduled appointment.
- **URL**: `GET /api/routing/next-appointment-eta`
- **Params**: `userId` (query or `X-User-Id` header)
- **Example**: `GET http://localhost:8080/api/routing/next-appointment-eta?userId=shreya`

---

## 4. Graph Engine Integration

The `GraphBuilder` is fully wired to OSRM:
- **TRAVEL Edges**: When building the risk graph, the engine identifies `TRAVEL` edges from current locations to upcoming `APPOINTMENT` nodes.
- **Dynamic Weights**: It calls `RoutingService.getRoute()` to fetch the real ETA and attaches it to the edge weight.
- **Risk Scoring**: The **Risk Agent** uses these real travel times to compute lateness probability.

**Log Output Example**:
```text
[Graph] TRAVEL edge home → Physics Lab, etaMinutes=11
```

---

## 5. Testing
You can verify the OSRM server independently using the test script:
```powershell
.\scripts\test-osrm.ps1
```
