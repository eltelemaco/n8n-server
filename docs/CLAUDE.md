# Claude.md - n8n Server Setup Status

## Project Overview
This project deploys an n8n automation server on Hetzner Cloud using Terraform (Infrastructure as Code) and Ansible (Configuration Management).

## Completed Work ✅

### 1. Planning & Documentation
- [x] Created detailed implementation plan in `docs/implementation_plan.md`
- [x] Established task checklist in `docs/task.md`
- [x] Documented infrastructure architecture and deployment strategy

### 2. Terraform Infrastructure
- [x] Initialized Terraform project structure in `terraform/`
- [x] Configured Hetzner Cloud provider and HCP remote backend
- [x] Defined all variables in `variables.tf` including HCP organization (`n8n`)
- [x] Implemented all required resources:
  - SSH key management
  - Private network (10.0.0.0/16) with subnet (10.0.1.0/24) in us-west region
  - Firewall rules (SSH, HTTP, HTTPS)
  - CPX22 Ubuntu 24.04 compute instance
  - Output definitions for public IP and other resources

### 3. Ansible Configuration
- [x] Created `ansible/` directory structure with all playbooks
- [x] Configured inventory for dynamic host management
- [x] Implemented security hardening playbook:
  - UFW firewall configuration
  - SSH hardening (disabled password auth, disabled root login)
  - Fail2Ban installation and setup
- [x] Created Docker installation playbook
- [x] Created n8n + PostgreSQL service definition with Docker Compose

## Remaining Tasks ⏳

### Execute & Verify Phase
- [ ] **Run Terraform Apply**: Execute `terraform apply` to provision infrastructure on Hetzner Cloud
  - Verify HCP backend connectivity
  - Confirm resource creation (network, subnet, firewall, instance)
  - Retrieve public IP from Terraform outputs

- [ ] **Run Ansible Playbook**: Execute playbooks against the provisioned instance
  - Verify SSH access to the instance
  - Confirm security hardening is applied
  - Verify Docker installation
  - Verify n8n service is running

- [ ] **Verify Deployment**: Test n8n accessibility
  - Access n8n web UI via the instance's public IP
  - Confirm PostgreSQL database connectivity
  - Test basic n8n functionality

## Key Configuration Details

- **Cloud Provider**: Hetzner Cloud
- **Infrastructure Tool**: Terraform with HCP remote state
- **Configuration Tool**: Ansible
- **Instance Type**: CPX22 (2 vCPU, 4GB RAM)
- **OS**: Ubuntu 24.04
- **Region**: us-west (Hillsboro, OR)
- **Network**: 10.0.0.0/16 (Private)
- **Database**: PostgreSQL (containerized)
- **Web Server**: n8n with Traefik reverse proxy
- **Authentication**: Basic Auth (n8n built-in)
- **Security**: UFW + Fail2Ban + SSH hardening

## Next Steps

1. Ensure you have valid Hetzner Cloud and HCP credentials configured
2. Navigate to the `terraform/` directory
3. Run `terraform plan` to review the changes
4. Run `terraform apply` to provision the infrastructure
5. Retrieve the public IP from Terraform outputs
6. Configure the Ansible inventory with the new instance IP
7. Run the Ansible playbooks to configure the server
8. Access n8n via http://<public-ip>:80

## Files Structure

```
n8n-server/
├── docs/
│   ├── task.md                    # Task checklist
│   ├── implementation_plan.md     # Detailed architecture plan
│   └── CLAUDE.md                  # This file
├── terraform/
│   ├── main.tf                    # Main resource definitions
│   ├── providers.tf               # Provider and backend config
│   ├── variables.tf               # Variable definitions
│   ├── outputs.tf                 # Output definitions
│   └── terraform.tfvars           # Variable values
└── ansible/
    ├── inventory.ini              # Host inventory
    ├── playbook.yml               # Main playbook
    └── roles/                      # Ansible roles
        ├── common/
        ├── security/
        ├── docker/
        └── n8n/
```

## Notes for Future AI Assistants

- The HCP organization is set to `n8n` as configured in variables
- SSH keys are managed via Terraform and should not be manually modified
- All passwords and sensitive values should be provided via `terraform.tfvars` (not committed to version control)
- Ansible requires SSH access to the instance; ensure firewall rules allow SSH from your IP
- The n8n service uses PostgreSQL for production setup with Docker Compose orchestration
