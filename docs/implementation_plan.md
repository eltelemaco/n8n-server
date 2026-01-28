# Implementation Plan: n8n Server on Hetzner

This document outlines the plan to deploy an n8n automation server on Hetzner Cloud using Terraform for Infrastructure as Code (IaC) and Ansible for configuration management.

## 1. Objectives
- Deploy a logical and secure infrastructure on Hetzner Cloud.
- Automate provision utilizing Terraform with remote state on HCP.
- Configure the server and application using Ansible.
- Ensure security hardening specifically for SSH and network access.

## 2. Infrastructure Architecture (Terraform)

### Provider & Backend
- **Provider**: `hetznercloud/hcloud`
- **Backend**: Terraform Cloud/HCP (`remote` backend) to store state securely.

### Resources
1.  **SSH Keys**:
    - Generate/Upload SSH public key to Hetzner for server access.
    
2.  **Networking**:
    - **Network**: Create a private network (`10.0.0.0/16`) to isolate traffic if needed in the future.
    - **Subnet**: Create a subnet (`10.0.1.0/24`) in region `us-west` (Hillsboro, OR).
    
3.  **Security (Firewall)**:
    - Create a Firewall resource attached to the server.
    - **Inbound Rules**:
        - SSH (TCP/22): Restricted to specific IPs if possible, or open with Fail2Ban.
        - HTTP (TCP/80): Allow for Let's Encrypt challenges / web traffic.
        - HTTPS (TCP/443): Allow for secure web traffic.
    - **Outbound Rules**:
        - Allow all (TCP/UDP/ICMP) for updates and external API calls.

4.  **Compute (VPS)**:
    - **Type**: `cpx22` (Shared vCPU AMD).
    - **Image**: `ubuntu-24.04`.
    - **Location**: `us-west` (Hillsboro, OR).
    - **Cloud-init**: Basic bootstrap to install Python (for Ansible) and add the user's SSH key.

## 3. Configuration Management (Ansible)

After Terraform provisions the infrastructure, Ansible will takeover via an inventory file generated from Terraform outputs or a dynamic inventory.

### Roles & Tasks
1.  **System Common**:
    - Update/Upgrade `apt` packages.
    - Install essential tools (`curl`, `git`, `vim`, `htop`).

2.  **Security Hardening**:
    - **SSH**: 
        - Disable Password Authentication.
        - Disable Root Login.
        - Change default SSH port (Optional, but recommended).
    - **UFW (Uncomplicated Firewall)**:
        - Enable UFW.
        - Allow SSH (rate limited), HTTP, HTTPS.
    - **Fail2Ban**: Install and configure for SSH protection.

3.  **Docker Setup**:
    - Install Docker Engine and Docker Compose plugin.
    - Configure non-root user access for Docker.

4.  **n8n Deployment**:
    - **Deploy Method**: Docker Compose.
    - **Components**:
        - `n8n`: Main application container.
        - `postgres`: Database backend (Production setup).
        - `traefik`: Reverse proxy (Configured for HTTP initially, customizable for future Domain/SSL).
    - **Authentication**: Basic Auth (n8n built-in).

## 4. Execution Steps

1.  **Terraform Init & Apply**:
    - Initialize HCP backend.
    - Plan and Apple infrastructure.
2.  **Ansible Provisioning**:
    - Run playbook against the new host IP.
3.  **Verification**:
    - Verify SSH access.
    - Verify n8n UI accessibility.

---

## 5. Configuration Summary

- **Domain**: None (IP based access initially).
- **Database**: Postgres.
- **Authentication**: Basic.
- **SMTP**: Disabled.
- **Instance**: CPX22.
- **HCP Org**: `n8n`.

 