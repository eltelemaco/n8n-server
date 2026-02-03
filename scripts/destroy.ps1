[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$TerraformDir = "terraform",

  [Parameter(Mandatory = $false)]
  [switch]$AutoApprove
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
  throw "Missing required command: terraform"
}

$approveFlag = if ($AutoApprove) { "-auto-approve" } else { "" }

$tfPath = Join-Path (Get-Location) $TerraformDir
if (-not (Test-Path $tfPath)) {
  throw "Terraform dir not found: $TerraformDir"
}

Write-Host "\n> terraform destroy $approveFlag (cwd: $TerraformDir)" -ForegroundColor Cyan
Push-Location $tfPath
try {
  & terraform destroy $approveFlag
} finally {
  Pop-Location
}
if ($LASTEXITCODE -ne 0) {
  throw "terraform destroy failed with exit code $LASTEXITCODE"
}
