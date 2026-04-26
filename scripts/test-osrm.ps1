# Test OSRM Routing
# Coordinates for Bangalore (from user request)
$START = "77.5946,12.9716"
$END = "77.6387,12.9859"
$URL = "http://localhost:5000/route/v1/driving/$($START);$($END)?overview=false"

Write-Host "Testing OSRM at $URL..."
try {
    $response = Invoke-RestMethod -Uri $URL -Method Get
    Write-Host "Success!"
    Write-Host "Duration: $($response.routes[0].duration) seconds"
    Write-Host "Distance: $($response.routes[0].distance) meters"
    $response | ConvertTo-Json -Depth 10 | Write-Host
} catch {
    Write-Error "Failed to reach OSRM server. Make sure it is running (docker-compose up osrm)."
    Write-Error $_.Exception.Message
}
