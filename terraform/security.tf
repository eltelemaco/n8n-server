resource "hcloud_firewall" "n8n_fw" {
  name = "n8n-firewall"

  # SSH
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = var.allowed_ssh_ips
    description = "Allow SSH"
  }

  # HTTP
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
    description = "Allow HTTP"
  }

  # HTTPS
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
    description = "Allow HTTPS"
  }
  
  # Allow ICMP Inbound
  rule {
    direction = "in"
    protocol  = "icmp"
    source_ips = ["0.0.0.0/0", "::/0"]
    description = "Allow Ping"
  }

  # Outbound - Allow All TCP
  rule {
    direction = "out"
    protocol  = "tcp"
    port      = "any"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description = "Allow all outbound TCP"
  }

  # Outbound - Allow All UDP
  rule {
    direction = "out"
    protocol  = "udp"
    port      = "any"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description = "Allow all outbound UDP"
  }

  # Outbound - Allow All ICMP
  rule {
    direction = "out"
    protocol  = "icmp"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description = "Allow all outbound ICMP"
  }
}
