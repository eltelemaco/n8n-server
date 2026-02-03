locals {
  effective_ssh_public_key = var.create_ssh_key ? tls_private_key.n8n[0].public_key_openssh : (trimspace(var.ssh_public_key) != "" ? var.ssh_public_key : file(pathexpand(var.ssh_public_key_path)))
}

resource "tls_private_key" "n8n" {
  count     = var.create_ssh_key ? 1 : 0
  algorithm = "ED25519"
}

resource "local_file" "n8n_private_key" {
  count           = var.create_ssh_key ? 1 : 0
  filename        = pathexpand(var.ssh_private_key_path)
  content         = tls_private_key.n8n[0].private_key_openssh
  file_permission = "0600"
}

resource "local_file" "n8n_public_key" {
  count           = var.create_ssh_key ? 1 : 0
  filename        = pathexpand(var.ssh_public_key_path)
  content         = tls_private_key.n8n[0].public_key_openssh
  file_permission = "0644"
}

resource "hcloud_ssh_key" "n8n_key" {
  name       = "${var.name}-key"
  public_key = local.effective_ssh_public_key
}

#------------------------------------------------------------------------------
# Firewall
#------------------------------------------------------------------------------
resource "hcloud_firewall" "n8n_fw" {
  name = "${var.name}-firewall"

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
  name        = var.name
  image       = var.server_image
  server_type = var.server_type
  location    = var.location

  ssh_keys = [hcloud_ssh_key.n8n_key.id]

  firewall_ids = [hcloud_firewall.n8n_fw.id]

  # Cloud-init to set up Python for Ansible
  user_data = <<-EOF
#cloud-config
package_update: true
package_upgrade: true

packages:
  - python3
  - python3-apt

users:
  - name: ${var.admin_user}
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: [sudo]
    shell: /bin/bash
    ssh_authorized_keys:
      - ${local.effective_ssh_public_key}

ssh_pwauth: false

${var.create_floating_ip ? <<-EOT
write_files:
  - path: /usr/local/sbin/configure-floating-ip.sh
    permissions: '0755'
    content: |
      #!/usr/bin/env bash
      set -euo pipefail
      FIP="${hcloud_floating_ip.n8n_fip[0].ip_address}"
      IFACE=$(ip -o -4 route show to default | awk '{print $5}' | head -n1)
      if ! ip addr show dev "$IFACE" | grep -q "${hcloud_floating_ip.n8n_fip[0].ip_address}"; then
        ip addr add "$FIP/32" dev "$IFACE"
      fi

  - path: /etc/systemd/system/hetzner-floating-ip.service
    permissions: '0644'
    content: |
      [Unit]
      Description=Configure Hetzner Floating IP
      After=network-online.target
      Wants=network-online.target

      [Service]
      Type=simple
      ExecStart=/bin/bash -lc 'while true; do /usr/local/sbin/configure-floating-ip.sh; sleep 30; done'
      Restart=always
      RestartSec=5

      [Install]
      WantedBy=multi-user.target
EOT
: ""}

runcmd:
  - echo "Cloud-init complete"
${var.create_floating_ip ? "  - systemctl daemon-reload\n  - systemctl enable --now hetzner-floating-ip.service\n" : ""}
  EOF

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  depends_on = [hcloud_firewall.n8n_fw]
}

resource "hcloud_floating_ip" "n8n_fip" {
  count         = var.create_floating_ip ? 1 : 0
  name          = "${var.name}-fip"
  type          = "ipv4"
  home_location = var.location
}

resource "hcloud_floating_ip_assignment" "n8n_fip" {
  count          = var.create_floating_ip ? 1 : 0
  floating_ip_id = hcloud_floating_ip.n8n_fip[0].id
  server_id      = hcloud_server.n8n_server.id
}
