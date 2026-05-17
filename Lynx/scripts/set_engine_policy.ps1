param(
  [Parameter(Mandatory = $true)][string]$ApiBase,
  [Parameter(Mandatory = $true)][string]$BearerToken,
  [Parameter(Mandatory = $true)][string]$ManifestUrl,
  [Parameter(Mandatory = $true)][string]$RecommendedVersion
)

$ErrorActionPreference = "Stop"

$base = $ApiBase.TrimEnd("/")
$uri = "$base/admin/engine/policy"

$body = @{
  manifest_url = $ManifestUrl
  recommended_version = $RecommendedVersion
} | ConvertTo-Json -Depth 4

Write-Host "PUT $uri" -ForegroundColor Cyan

$headers = @{
  Authorization = "Bearer $BearerToken"
  "Content-Type" = "application/json"
}

$resp = Invoke-RestMethod -Method Put -Uri $uri -Headers $headers -Body $body
$resp | ConvertTo-Json -Depth 8

Write-Host ""
Write-Host "Policy updated. Verifying public manifest..." -ForegroundColor Green
Invoke-RestMethod -Method Get -Uri "$base/engine/manifest" | ConvertTo-Json -Depth 10
