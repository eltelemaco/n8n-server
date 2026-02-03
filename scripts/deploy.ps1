[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$Domain = "lab1.telemaco.com.mx",

  [Parameter(Mandatory = $false)]
  [string]$TerraformDir = "terraform",

  [Parameter(Mandatory = $false)]
  [string]$AnsibleDir = "ansible",

  [Parameter(Mandatory = $false)]
  [string]$SshPrivateKeyPath = "$HOME/.ssh/n8n-server",

  [Parameter(Mandatory = $false)]
  [string]$SecretsPath = "ansible/vars/secrets.yml",

  [Parameter(Mandatory = $false)]
  [string]$DockerImage = "willhallonline/ansible:latest",

  # Preferred: run Ansible on the target server itself (post-Terraform).
  # This avoids requiring WSL/Docker Ansible on the operator machine.
  [Parameter(Mandatory = $false)]
  [switch]$RemoteAnsible = $true,

  # Fallback: run Ansible locally from a Docker container on this machine.
  [Parameter(Mandatory = $false)]
  [switch]$LocalDockerAnsible = $false,

  [Parameter(Mandatory = $false)]
  [switch]$UseAcmeStaging,

  [Parameter(Mandatory = $false)]
  [switch]$UseSelfSigned,

  [Parameter(Mandatory = $false)]
  [switch]$SkipExternalValidation,

  [Parameter(Mandatory = $false)]
  [switch]$TerraformOnly,

  [Parameter(Mandatory = $false)]
  [switch]$AnsibleOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-CommandAvailable([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Missing required command: $Name"
  }
}

function Resolve-ARecord([string]$HostName) {
  try {
    $result = Resolve-DnsName -Name $HostName -Type A -ErrorAction Stop |
      Where-Object { $_.Type -eq 'A' } |
      Select-Object -First 1
    return $result.IPAddress
  } catch {
    return $null
  }
}

function Wait-ForTcpPort([string]$HostName, [int]$Port, [int]$TimeoutSeconds) {
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    try {
      if (Test-NetConnection -ComputerName $HostName -Port $Port -InformationLevel Quiet) {
        return $true
      }
    } catch {
      # ignore transient DNS/stack issues
    }
    Start-Sleep -Seconds 5
  }
  return $false
}

function Run([string]$Cmd) {
  Write-Host "\n> $Cmd" -ForegroundColor Cyan
  & powershell -NoProfile -Command $Cmd
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed with exit code $LASTEXITCODE. Command: $Cmd"
  }
}

Test-CommandAvailable terraform

$repoRoot = Get-Location
$tfDir = Join-Path $repoRoot $TerraformDir

if (-not $AnsibleOnly) {
  if (-not (Test-Path $tfDir)) { throw "Terraform dir not found: $TerraformDir" }

  Run "terraform -chdir=`"$TerraformDir`" init -upgrade"
  Run "terraform -chdir=`"$TerraformDir`" apply -auto-approve"
}

Push-Location $tfDir
try {
  $floatingIp = & terraform output -raw floating_ip 2>$null
  $serverPublicIp = & terraform output -raw server_public_ip 2>$null
} finally {
  Pop-Location
}
if (-not $floatingIp) {
  throw "Terraform output 'floating_ip' is empty. Did apply succeed?"
}
Write-Host "Floating IP: $floatingIp" -ForegroundColor Green

if ($TerraformOnly) { exit 0 }

if (-not (Test-Path $SecretsPath)) {
  Write-Host "Secrets missing: $SecretsPath" -ForegroundColor Yellow
  Write-Host "Generating secrets..." -ForegroundColor Yellow
  Run "./scripts/new-secrets.ps1 -SecretsPath `"$SecretsPath`""
}

if (-not (Test-Path $SshPrivateKeyPath)) {
  throw "SSH private key not found: $SshPrivateKeyPath"
}

$dnsA = Resolve-ARecord -HostName $Domain
if (-not $SkipExternalValidation) {
  if (-not $dnsA) {
    Write-Host "DNS A record for $Domain not found. External validation will be skipped." -ForegroundColor Yellow
    $SkipExternalValidation = $true
  } elseif ($dnsA -ne $floatingIp) {
    Write-Host "DNS A mismatch for $Domain" -ForegroundColor Yellow
    Write-Host "  DNS:      $dnsA" -ForegroundColor Yellow
    Write-Host "  Expected: $floatingIp" -ForegroundColor Yellow
    Write-Host "External validation will be skipped (use -SkipExternalValidation:`$false to force)." -ForegroundColor Yellow
    $SkipExternalValidation = $true
  }
}

if ($UseSelfSigned -and -not $SkipExternalValidation) {
  Write-Host "Self-signed requested; skipping external HTTPS validation." -ForegroundColor Yellow
  $SkipExternalValidation = $true
}

$validateExternally = if ($SkipExternalValidation) { "false" } else { "true" }
$acmeStagingValue = if ($UseAcmeStaging) { "true" } else { "false" }
$selfSignedValue = if ($UseSelfSigned) { "true" } else { "false" }
$extraVars = "-e @vars/secrets.yml -e validate_n8n_externally=$validateExternally -e n8n_use_acme_staging=$acmeStagingValue -e n8n_use_self_signed=$selfSignedValue -e n8n_domain=$Domain"

if (-not $RemoteAnsible -and -not $LocalDockerAnsible) {
  throw "Choose an Ansible mode: use -RemoteAnsible (default) or -LocalDockerAnsible."
}

if ($RemoteAnsible -and $LocalDockerAnsible) {
  throw "Choose only one Ansible mode: -RemoteAnsible or -LocalDockerAnsible."
}

if ($RemoteAnsible) {
  Test-CommandAvailable ssh
  Test-CommandAvailable scp

  if (-not (Test-Path $SecretsPath)) {
    throw "Secrets file missing: $SecretsPath (expected to exist before remote Ansible run)."
  }

  $remoteScript = "/tmp/n8n-ansible-run.sh"

  $remoteBaseDir = "~/n8n-ansible"
  $localAnsibleDir = Join-Path $repoRoot.Path 'ansible'
  if (-not (Test-Path $localAnsibleDir)) {
    throw "Local ansible directory not found: $localAnsibleDir"
  }

  $sshIp = $floatingIp
  Write-Host ("\n> Waiting for SSH on Floating IP ({0}:22)" -f $floatingIp) -ForegroundColor Cyan
  $fipReady = Wait-ForTcpPort -HostName $floatingIp -Port 22 -TimeoutSeconds 180
  if (-not $fipReady) {
    if (-not $serverPublicIp) {
      throw "Floating IP SSH is not reachable yet and terraform output 'server_public_ip' is empty."
    }

    Write-Host "Floating IP not reachable yet; falling back to server_public_ip ($serverPublicIp) for bootstrap." -ForegroundColor Yellow
    Write-Host ("\n> Waiting for SSH on server_public_ip ({0}:22)" -f $serverPublicIp) -ForegroundColor Cyan
    $srvReady = Wait-ForTcpPort -HostName $serverPublicIp -Port 22 -TimeoutSeconds 180
    if (-not $srvReady) {
      throw "SSH is not reachable on either floating_ip ($floatingIp) or server_public_ip ($serverPublicIp)."
    }
    $sshIp = $serverPublicIp
  }

  Write-Host "\n> Preparing remote directory $remoteBaseDir" -ForegroundColor Cyan
  & ssh -i $SshPrivateKeyPath -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ("telemaco@{0}" -f $sshIp) ("sudo rm -rf {0} && sudo mkdir -p {0} && sudo chown -R telemaco:telemaco {0}" -f $remoteBaseDir)
  if ($LASTEXITCODE -ne 0) {
    throw "remote directory prep failed with exit code $LASTEXITCODE"
  }

  Write-Host ("\n> Uploading ansible/ directory to {0}:{1}" -f $sshIp, $remoteBaseDir) -ForegroundColor Cyan
  & scp -r -i $SshPrivateKeyPath -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $localAnsibleDir ("telemaco@{0}:{1}" -f $sshIp, $remoteBaseDir)
  if ($LASTEXITCODE -ne 0) {
    throw "scp ansible directory failed with exit code $LASTEXITCODE"
  }

  $remoteRunScriptContent = @'
#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

sudo apt-get update -y
sudo apt-get install -y ansible

cd "$HOME/n8n-ansible/ansible"

cat > /tmp/inventory.local.ini <<'EOF'
[n8n_servers]
localhost ansible_connection=local
EOF

ansible-playbook -i /tmp/inventory.local.ini playbook.yml __EXTRA_VARS__
'@

  $remoteRunScriptContent = $remoteRunScriptContent.Replace('__VALIDATE_EXTERNALLY__', $validateExternally)
  $remoteRunScriptContent = $remoteRunScriptContent.Replace('__ACME_STAGING__', $acmeStagingValue)
  $remoteRunScriptContent = $remoteRunScriptContent.Replace('__SELF_SIGNED__', $selfSignedValue)
  $remoteRunScriptContent = $remoteRunScriptContent.Replace('__EXTRA_VARS__', $extraVars)

  $localScriptPath = Join-Path $env:TEMP ("n8n-ansible-run-{0}.sh" -f ([guid]::NewGuid().ToString('n')))
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  $lfContent = $remoteRunScriptContent -replace "`r`n", "`n"
  [System.IO.File]::WriteAllText($localScriptPath, $lfContent, $utf8NoBom)

  Write-Host "\n> Uploading remote run script" -ForegroundColor Cyan
  & scp -i $SshPrivateKeyPath -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $localScriptPath ("telemaco@{0}:{1}" -f $sshIp, $remoteScript)
  if ($LASTEXITCODE -ne 0) {
    throw "scp run script failed with exit code $LASTEXITCODE"
  }

  Write-Host "\n> Executing Ansible on the server" -ForegroundColor Cyan
  & ssh -i $SshPrivateKeyPath -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ("telemaco@{0}" -f $sshIp) ("bash {0}" -f $remoteScript)
  if ($LASTEXITCODE -ne 0) {
    throw "remote ansible run failed with exit code $LASTEXITCODE"
  }

  Remove-Item -Force $localScriptPath -ErrorAction SilentlyContinue

  Write-Host "\nDeploy finished (remote ansible)." -ForegroundColor Green
  Write-Host "Next checks:" -ForegroundColor Green
  Write-Host "  curl -I https://$Domain/" -ForegroundColor Green
  Write-Host "  curl -I http://$Domain/" -ForegroundColor Green
  exit 0
}

# Fallback: Run Ansible from a Linux container so it works on Windows without WSL.
Test-CommandAvailable docker

$inventoryLine = "$Domain ansible_host=$floatingIp ansible_user=telemaco"

& docker image inspect $DockerImage *> $null
if ($LASTEXITCODE -ne 0) {
  Write-Host "Docker image not present locally: $DockerImage" -ForegroundColor Yellow
  Write-Host "Pulling..." -ForegroundColor Yellow
  & docker pull $DockerImage
  if ($LASTEXITCODE -ne 0) {
    $fallback = "cytopia/ansible:latest"
    Write-Host "Failed to pull $DockerImage. Falling back to $fallback" -ForegroundColor Yellow
    $DockerImage = $fallback
    & docker pull $DockerImage
    if ($LASTEXITCODE -ne 0) {
      throw "Unable to pull a usable Ansible Docker image (tried willhallonline/ansible:latest and cytopia/ansible:latest)."
    }
  }
}

$mountRepo = $repoRoot.Path + ':/work'
$mountKey = $SshPrivateKeyPath + ':/key/id_ed25519:ro'

$containerScript = 'mkdir -p /root/.ssh && cp /key/id_ed25519 /root/.ssh/id_ed25519 && cp /key/id_ed25519 /root/.ssh/n8n-server && chmod 600 /root/.ssh/id_ed25519 /root/.ssh/n8n-server && ' +
  'printf ''[n8n_servers]\n%s\n'' "' + $inventoryLine + '" > /tmp/inventory.ini && ' +
  'cd /work/' + $AnsibleDir + ' && ' +
  'ansible-playbook -i /tmp/inventory.ini playbook.yml ' + $extraVars

$dockerArgs = @(
  'run', '--rm', '-t',
  '-v', $mountRepo,
  '-v', $mountKey,
  '-e', 'ANSIBLE_HOST_KEY_CHECKING=False',
  '-e', 'ANSIBLE_SSH_RETRIES=3',
  '-e', 'ANSIBLE_TIMEOUT=30',
  '-e', 'ANSIBLE_STDOUT_CALLBACK=yaml',
  '-e', "ANSIBLE_CONFIG=/work/$AnsibleDir/ansible.cfg",
  '-e', "ANSIBLE_SSH_COMMON_ARGS=-o ServerAliveInterval=15 -o ServerAliveCountMax=4 -o StrictHostKeyChecking=no",
  $DockerImage,
  'sh', '-lc', $containerScript
)

Write-Host "\n> docker $($dockerArgs -join ' ')" -ForegroundColor Cyan
& docker @dockerArgs
if ($LASTEXITCODE -ne 0) {
  throw "docker/ansible-playbook failed with exit code ${LASTEXITCODE}"
}

Write-Host "\nDeploy finished." -ForegroundColor Green
Write-Host "Next checks:" -ForegroundColor Green
Write-Host "  curl -I https://$Domain/" -ForegroundColor Green
Write-Host "  curl -I http://$Domain/" -ForegroundColor Green
