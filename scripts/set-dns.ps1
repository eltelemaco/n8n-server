[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
  # Your Hetzner DNS zone name (example: telemaco.com.mx)
  [Parameter(Mandatory = $false)]
  [string]$Zone = 'telemaco.com.mx',

  # The record name inside the zone (example: lab1)
  [Parameter(Mandatory = $false)]
  [string]$RecordName = 'lab1',

  [Parameter(Mandatory = $false)]
  [ValidateSet('A')]
  [string]$Type = 'A',

  [Parameter(Mandatory = $false)]
  [int]$Ttl = 3600,

  # If omitted, we read terraform output floating_ip from terraform/
  [Parameter(Mandatory = $false)]
  [string]$TargetIp,

  [Parameter(Mandatory = $false)]
  [string]$TerraformDir = 'terraform',

  # Prefer using the hcloud CLI if available (recommended on this machine).
  [Parameter(Mandatory = $false)]
  [switch]$UseHcloudCli = $true,

  # Env var to read the API token from. You said yours is hcloud_token.
  # Note: Hetzner Cloud tokens are NOT the same as Hetzner DNS tokens.
  # If this token isn't a DNS token, the API will return 401.
  [Parameter(Mandatory = $false)]
  [string]$TokenEnvVar = 'hcloud_token'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-EnvValue([string]$Name) {
  foreach ($scope in @('Process', 'User', 'Machine')) {
    $v = [Environment]::GetEnvironmentVariable($Name, $scope)
    if (-not [string]::IsNullOrEmpty($v)) { return $v }
  }
  return $null
}

if ($UseHcloudCli) {
  if (-not (Get-Command hcloud -ErrorAction SilentlyContinue)) {
    throw "UseHcloudCli was requested, but 'hcloud' was not found in PATH."
  }
} else {
  $token = Get-EnvValue -Name $TokenEnvVar
  if ([string]::IsNullOrEmpty($token)) {
    throw "Missing token env var '$TokenEnvVar' (checked Process/User/Machine)."
  }
}

if ([string]::IsNullOrEmpty($TargetIp)) {
  if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    throw "TargetIp not provided and terraform is not available in PATH. Provide -TargetIp or install terraform."
  }

  $tfPath = Join-Path (Get-Location) $TerraformDir
  if (-not (Test-Path $tfPath)) {
    throw "Terraform dir not found: $TerraformDir"
  }

  Push-Location $tfPath
  try {
    $TargetIp = & terraform output -raw floating_ip 2>$null
  } finally {
    Pop-Location
  }

  if ([string]::IsNullOrEmpty($TargetIp)) {
    throw "Unable to read terraform output 'floating_ip'. Provide -TargetIp explicitly."
  }
}

Write-Host "Zone: $Zone" -ForegroundColor Cyan
Write-Host "Record: $RecordName ($Type)" -ForegroundColor Cyan
Write-Host "Target: $TargetIp (ttl $Ttl)" -ForegroundColor Cyan

if ($UseHcloudCli) {
  if ($PSCmdlet.ShouldProcess("$RecordName.$Zone", "Set $Type record to $TargetIp")) {
    & hcloud zone rrset set-records --record $TargetIp $Zone $RecordName $Type
    if ($LASTEXITCODE -ne 0) { throw "hcloud rrset set-records failed with exit code $LASTEXITCODE" }

    & hcloud zone rrset change-ttl --ttl $Ttl $Zone $RecordName $Type
    if ($LASTEXITCODE -ne 0) { throw "hcloud rrset change-ttl failed with exit code $LASTEXITCODE" }

    Write-Host "Updated via hcloud CLI." -ForegroundColor Green
  }
  return
}

# Fallback: Hetzner DNS HTTP API
$baseUrl = 'https://dns.hetzner.com/api/v1'
$headers = @{ 'Auth-API-Token' = $token }

# 1) Find zone
$zones = Invoke-RestMethod -Method GET -Uri "$baseUrl/zones" -Headers $headers
$zoneObj = $zones.zones | Where-Object { $_.name -eq $Zone } | Select-Object -First 1
if (-not $zoneObj) {
  $available = ($zones.zones | Select-Object -ExpandProperty name | Sort-Object) -join ', '
  throw "Zone '$Zone' not found. Available zones: $available"
}
$zoneId = $zoneObj.id

# 2) Find record
$records = Invoke-RestMethod -Method GET -Uri "$baseUrl/records?zone_id=$zoneId" -Headers $headers
$record = $records.records | Where-Object { $_.type -eq $Type -and $_.name -eq $RecordName } | Select-Object -First 1

$body = @{
  value   = $TargetIp
  ttl     = $Ttl
  type    = $Type
  name    = $RecordName
  zone_id = $zoneId
} | ConvertTo-Json

if ($record) {
  $recordId = $record.id
  if ($PSCmdlet.ShouldProcess("$RecordName.$Zone", "Update record $recordId to $TargetIp")) {
    Invoke-RestMethod -Method PUT -Uri "$baseUrl/records/$recordId" -Headers $headers -ContentType 'application/json' -Body $body | Out-Null
    Write-Host "Updated record $recordId" -ForegroundColor Green
  }
} else {
  if ($PSCmdlet.ShouldProcess("$RecordName.$Zone", "Create record to $TargetIp")) {
    $created = Invoke-RestMethod -Method POST -Uri "$baseUrl/records" -Headers $headers -ContentType 'application/json' -Body $body
    Write-Host ("Created record {0}" -f $created.record.id) -ForegroundColor Green
  }
}

Write-Host "Done." -ForegroundColor Green
