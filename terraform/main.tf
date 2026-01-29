#------------------------------------------------------------------------------
# SSH Key
#------------------------------------------------------------------------------
# Upload the user-provided public key to Hetzner
# The public key should be stored as a variable in HCP Terraform
resource "hcloud_ssh_key" "n8n_key" {
  name       = "n8n-server-key"
  public_key = var.ssh_public_key
}

#------------------------------------------------------------------------------
# Network
#------------------------------------------------------------------------------
resource "hcloud_network" "private_net" {
  name     = "n8n-private-net"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "n8n_subnet" {
  network_id   = hcloud_network.private_net.id
  type         = "cloud"
  network_zone = "us-west"
  ip_range     = "10.0.1.0/24"
}

#------------------------------------------------------------------------------
# Firewall
#------------------------------------------------------------------------------
resource "hcloud_firewall" "n8n_fw" {
  name = "n8n-firewall"

  # SSH
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = var.allowed_ssh_ips
    description = "Allow SSH"
  }

  # HTTP
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Allow HTTP"
  }

  # HTTPS
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Allow HTTPS"
  }

  # Allow ICMP Inbound
  rule {
    direction   = "in"
    protocol    = "icmp"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Allow Ping"
  }

  # Outbound - Allow All TCP
  rule {
    direction       = "out"
    protocol        = "tcp"
    port            = "1-65535"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description     = "Allow all outbound TCP"
  }

  # Outbound - Allow All UDP
  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "1-65535"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description     = "Allow all outbound UDP"
  }

  # Outbound - Allow All ICMP
  rule {
    direction       = "out"
    protocol        = "icmp"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description     = "Allow all outbound ICMP"
  }
}

#------------------------------------------------------------------------------
# Compute - Server
#------------------------------------------------------------------------------
resource "hcloud_server" "n8n_server" {
  name        = "n8n-server"
  image       = var.server_image
  server_type = var.server_type
  location    = var.location

  ssh_keys = [hcloud_ssh_key.n8n_key.id]

  firewall_ids = [hcloud_firewall.n8n_fw.id]

  network {
    network_id = hcloud_network.private_net.id
    ip         = "10.0.1.10" # Static IP in subnet
  }

  # Cloud-init to set up Python for Ansible
  user_data = <<-EOF
    #cloud-config
    package_update: true
    package_upgrade: true

    # Set timezone and locale
    timezone: UTC
    locale: en_US.UTF-8

    # Hostname (will be overridden by Terraform server name, but good to have)
    hostname: n8n-server

    packages:
      - python3
      - python3-pip
      - git
      - curl
      - wget
      - htop
      - vim
      - neovim
      - ufw
      - net-tools
      - fail2ban
      - htop
      - iotop
      - ncdu
      - tree
      - jq
      - unzip
      - software-properties-common
      - apt-transport-https
      - ca-certificates
      - gnupg
      - lsb-release
    users:
      - name: telemaco
        sudo: ALL=(ALL) NOPASSWD:ALL
        groups: [sudo, adm, docker]
        shell: /bin/bash
        ssh_authorized_keys:
          - ${var.ssh_public_key}

    ssh_pwauth: false
    disable_root: true  # Keep root enabled initially for Hetzner's SSH key injection
    package_update: true
    package_upgrade: true
    runcmd:
      - echo "Cloud-init complete"
  EOF

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  depends_on = [
    hcloud_network_subnet.n8n_subnet,
    hcloud_firewall.n8n_fw
  ]
}
