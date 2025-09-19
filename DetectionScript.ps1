$MarkerPath = "C:\ProgramData\LogCollector"
$WeekMarker = Join-Path $MarkerPath "LastUpload.txt"

# Check folder
if (-not (Test-Path $MarkerPath)) {
    Write-Output "No marker folder, remediation needed."
    exit 1
}

# Check marker file
if (-not (Test-Path $WeekMarker)) {
    Write-Output "No marker file, remediation needed."
    exit 1
}

# Read and validate date
try {
    $LastRun = (Get-Content -Path $WeekMarker -Raw).Trim()
    $LastRunDate = [datetime]::ParseExact($LastRun, "yyyy-MM-dd HH:mm:ss", $null)  # strict format
}
catch {
    Write-Output "Marker file invalid or not a valid date, remediation needed."
    exit 1
}

# Compare with 7-day threshold
if ($LastRunDate -lt (Get-Date).AddDays(-7)) {
    Write-Output "Marker too old, remediation needed."
    exit 1
}

Write-Output "Logs already uploaded this week."
exit 0

# This Script is created by Emiel Maglalang.
