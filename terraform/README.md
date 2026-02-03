# Terraform (Hetzner)

This folder provisions the Hetzner Cloud infrastructure for the n8n server.

## What it creates

- 1x Hetzner server (Ubuntu by default)
- 1x Hetzner firewall (ports 22/80/443)
- Optional: a Floating IP (recommended for stable DNS)
- Optional: a locally-generated ED25519 SSH keypair (uploaded to Hetzner)

## Prereqs

- `terraform` >= 1.5
- Hetzner token exported as `HCLOUD_TOKEN`
- Docker (for the Windows Ansible runner, optional)

## SSH key behavior (matches your SSH config)

By default this repo expects you already have an SSH keypair locally (recommended) at:

- `~/.ssh/n8n-server`
- `~/.ssh/n8n-server.pub`

That matches:

```text
Host lab1.telemaco.com.mx
  HostName <server-ip>
  User telemaco
  IdentityFile ~/.ssh/n8n-server
```

If you want Terraform to generate a keypair for you instead, set `create_ssh_key=true`.

## Usage

```bash
cd terraform
terraform init
terraform apply
```

After apply:

- Point `lab1.telemaco.com.mx` to the `floating_ip` output (preferred) or `server_public_ip`.
- Run Ansible from `ansible/`.

## One-command deploy (recommended on Windows)

From the repo root:

```powershell
./scripts/deploy.ps1
```

This will:

- Run Terraform apply
- Read the Terraform `floating_ip` output
- Run Ansible from a Dockerized Ansible runner

If DNS is not pointing at the Floating IP yet, the script will automatically skip external HTTPS validation so the deploy is still repeatable.

## Destroy (Windows)

```powershell
./scripts/destroy.ps1 -AutoApprove
```
