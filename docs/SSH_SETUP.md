# SSH Key Setup for HCP Terraform

This guide explains how to set up SSH access when running Terraform in HCP Terraform (remote execution).

## The Problem

When Terraform runs in HCP, dynamically generating SSH keys doesn't work because:
- The private key is generated on HCP's remote runner, not your local machine
- Retrieving the key via outputs is insecure and cumbersome
- You can't easily use the key for SSH connections

## The Solution

Instead, we use a **user-provided SSH key** stored as a variable in HCP Terraform.

## Setup Steps

### 1. Generate an SSH Key Locally (if you don't have one)

```bash
ssh-keygen -t ed25519 -f ~/.ssh/n8n_server_key -C "n8n-server"
```

This creates:
- `~/.ssh/n8n_server_key` (private key - keep this safe locally)
- `~/.ssh/n8n_server_key.pub` (public key - this goes to HCP)

### 2. Get Your Public Key Content

```bash
cat ~/.ssh/n8n_server_key.pub
```

Copy the entire output (it should start with `ssh-ed25519`).

### 3. Add the Public Key to HCP Terraform

#### Option A: Via HCP UI
1. Go to your HCP Terraform workspace
2. Navigate to **Variables**
3. Click **Add variable**
4. Set:
   - **Key**: `ssh_public_key`
   - **Value**: Paste your public key content
   - **Category**: Terraform variable
   - **Sensitive**: No (public keys are safe)
5. Save

#### Option B: Via Terraform CLI (if configured)
```bash
# Set as environment variable for testing
export TF_VAR_ssh_public_key="ssh-ed25519 AAAA... your-email@example.com"
```

### 4. Apply the Configuration

Commit and push your changes:
```bash
git add .
git commit -m "Refactor: Use user-provided SSH keys for HCP compatibility"
git push
```

HCP Terraform will auto-trigger (or manually trigger) the plan/apply.

### 5. Connect to Your Server

After the apply completes, get the server IP from outputs:
```bash
terraform output server_public_ip
```

Connect using your local private key:
```bash
ssh -i ~/.ssh/n8n_server_key telemaco@<server_ip>
```

Or as root (initially):
```bash
ssh -i ~/.ssh/n8n_server_key root@<server_ip>
```

## How It Works

1. **You generate** the SSH key pair locally (you keep the private key)
2. **Public key** is stored in HCP Terraform as a variable (safe to store)
3. **Terraform** uploads the public key to:
   - Hetzner Cloud (via `hcloud_ssh_key` resource)
   - The server directly (via cloud-init)
4. **You connect** using your local private key

## Security Notes

- ✅ Private key never leaves your machine
- ✅ Only public key is stored in HCP (public keys are safe)
- ✅ No sensitive data in Terraform state
- ✅ Standard SSH key workflow

## Optional: Add to SSH Config

For easier access, add to `~/.ssh/config`:

```
Host n8n-server
    HostName <server_ip>
    User telemaco
    IdentityFile ~/.ssh/n8n_server_key
    StrictHostKeyChecking accept-new
```

Then connect with:
```bash
ssh n8n-server
```
