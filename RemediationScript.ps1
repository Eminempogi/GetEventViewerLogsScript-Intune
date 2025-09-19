<#
Remediation Script
- Collect 30 days of System logs (all levels)
- Save as EVTX file
- Zip and upload to SharePoint
- Update marker file to avoid re-running the same week
#>

# ===== CONFIGURATION =====
$DaysBack        = 30  #Days to get
$TenantId        = "<YOUR_TENANT_ID>"                   #Input details here
$ClientId        = "<YOUR_CLIENT_ID>"                   #Input details here
$ClientSecret    = "<YOUR_CLIENT_SECRET>"               #Input details here
$SiteHostname    = "<YOUR_SHAREPOINT_SITE_HOST>"        #Input details here
$SitePath        = "<SHAREPOINT_SITE_PATH>"             #Input details here
$LibraryPath     = "<SHAREPOINT_LIBRARY_PATH>"          #Input details here

$MarkerPath = "C:\ProgramData\LogCollector"
$WeekMarker = "$MarkerPath\LastUpload.txt"

# Ensure marker folder exists
if (!(Test-Path $MarkerPath)) {
    New-Item -ItemType Directory -Path $MarkerPath | Out-Null
}

# ===== EXPORT LOGS =====
$TempPath = "$env:TEMP\DeviceLogs"
if (Test-Path $TempPath) { Remove-Item $TempPath -Recurse -Force }
New-Item -ItemType Directory -Path $TempPath | Out-Null

$DeviceName = $env:COMPUTERNAME
$DateStamp  = (Get-Date -Format "yyyy-MM-dd")
$StartTime  = (Get-Date).AddDays(-$DaysBack)

# Export System logs (last 30 days)
$EvtxFile = "$TempPath\System-$DeviceName-$DateStamp.evtx"
$Query = "*[System[TimeCreated[@SystemTime>='$($StartTime.ToUniversalTime().ToString("o"))']]]"
wevtutil epl System $EvtxFile "/q:$Query"

# Compress logs
$ZipFile = "$env:TEMP\$DeviceName-$DateStamp.zip"
if (Test-Path $ZipFile) { Remove-Item $ZipFile -Force }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($TempPath, $ZipFile)

# ===== AUTHENTICATE TO GRAPH =====
$Body = @{
    client_id     = $ClientId
    scope         = "https://graph.microsoft.com/.default"
    client_secret = $ClientSecret
    grant_type    = "client_credentials"
}
$TokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Method POST -Body $Body
$AccessToken   = $TokenResponse.access_token

# ===== RESOLVE SITE + DRIVE =====
$SiteInfo = Invoke-RestMethod -Headers @{Authorization = "Bearer $AccessToken"} -Uri "https://graph.microsoft.com/v1.0/sites/${SiteHostname}:$SitePath"
$SiteId   = $SiteInfo.id

$DriveInfo = Invoke-RestMethod -Headers @{Authorization = "Bearer $AccessToken"} -Uri "https://graph.microsoft.com/v1.0/sites/$SiteId/drives"
$DriveId   = ($DriveInfo.value | Where-Object { $_.name -eq "Documents" }).id

# ===== UPLOAD TO SHAREPOINT =====
$FileName       = "$DeviceName-$DateStamp.zip"
$RemoteFolder   = "<YOUR_FOLDER>"                    # Folder inside Shared Documents
$RemoteFilePath = "$RemoteFolder/$FileName"          # Full path inside the library

# Build the upload URL using the DriveId
$UploadUrl = "https://graph.microsoft.com/v1.0/drives/$DriveId/root:/${RemoteFilePath}:/content"

Write-Output "Uploading logs to $UploadUrl"

Invoke-RestMethod -Uri $UploadUrl `
    -Headers @{ Authorization = "Bearer $AccessToken" } `
    -Method PUT `
    -InFile $ZipFile `
    -ContentType "application/zip"


# ===== UPDATE MARKER =====
(Get-Date).ToString("yyyy-MM-dd HH:mm:ss") | Out-File $WeekMarker -Force
