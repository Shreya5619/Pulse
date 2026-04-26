# Setup OSRM Data for Pulse
# This script downloads (if missing) and processes OSM data for the OSRM backend.

$DATA_DIR = "osrm-data"
$OSM_FILE = "karnataka-latest.osm.pbf"
$OSRM_FILE = "karnataka-latest.osrm"
$URL = "https://download.openstreetmap.fr/extracts/asia/india/karnataka-latest.osm.pbf"

if (-not (Test-Path $DATA_DIR)) {
    New-Item -ItemType Directory -Path $DATA_DIR
}

Set-Location $DATA_DIR

if (-not (Test-Path $OSM_FILE)) {
    Write-Host "Downloading OSM data from $URL..."
    curl.exe -L $URL -o $OSM_FILE
} else {
    Write-Host "$OSM_FILE already exists, skipping download."
}

Write-Host "Extracting OSRM data (this may take a few minutes)..."
docker run -t -v "${PWD}:/data" osrm/osrm-backend osrm-extract -p /opt/car.lua /data/$OSM_FILE

Write-Host "Partitioning OSRM data..."
docker run -t -v "${PWD}:/data" osrm/osrm-backend osrm-partition /data/$OSRM_FILE

Write-Host "Customizing OSRM data..."
docker run -t -v "${PWD}:/data" osrm/osrm-backend osrm-customize /data/$OSRM_FILE

Write-Host "OSRM data preparation complete!"
Write-Host "You can now start the OSRM server with: docker-compose up -d osrm"
