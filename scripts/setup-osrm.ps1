# Setup OSRM Data for Pulse (Bangalore focused)
# This script ensures the Bangalore extract is available (by clipping Karnataka if needed) and processes it.

$DATA_DIR = "osrm-data"
$PARENT_OSM_FILE = "karnataka-latest.osm.pbf"
$OSM_FILE = "bangalore-latest.osm.pbf"
$OSRM_FILE = "bangalore-latest.osrm"
$URL = "https://download.openstreetmap.fr/extracts/asia/india/karnataka-latest.osm.pbf"

if (-not (Test-Path $DATA_DIR)) {
    New-Item -ItemType Directory -Path $DATA_DIR
}

Set-Location $DATA_DIR

# 1. Ensure Parent Karnataka file exists
if (-not (Test-Path $PARENT_OSM_FILE)) {
    Write-Host "Downloading Karnataka data from $URL..."
    curl.exe -L $URL -o $PARENT_OSM_FILE
}

# 2. Clip to Bangalore if bangalore-latest.osm.pbf is missing
if (-not (Test-Path $OSM_FILE)) {
    Write-Host "Clipping Karnataka data to Bangalore area..."
    docker run --rm -v "${PWD}:/data" debian:bookworm-slim sh -c "apt-get update && apt-get install -y osmium-tool && osmium extract -b 77.3,12.7,77.9,13.2 /data/$PARENT_OSM_FILE -o /data/$OSM_FILE"
} else {
    Write-Host "$OSM_FILE already exists, skipping clipping."
}

# 3. OSRM Processing
Write-Host "Extracting OSRM data (this may take a few minutes)..."
docker run -t -v "${PWD}:/data" osrm/osrm-backend osrm-extract -p /opt/car.lua /data/$OSM_FILE

Write-Host "Partitioning OSRM data..."
docker run -t -v "${PWD}:/data" osrm/osrm-backend osrm-partition /data/$OSRM_FILE

Write-Host "Customizing OSRM data..."
docker run -t -v "${PWD}:/data" osrm/osrm-backend osrm-customize /data/$OSRM_FILE

Write-Host "OSRM data preparation complete for Bangalore!"
Write-Host "You can now start the OSRM server with: docker-compose up -d osrm"
