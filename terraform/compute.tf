resource "hcloud_server" "n8n_server" {
  name        = "n8n-server"
  image       = var.server_image
  server_type = var.server_type
  location    = var.location
  
  ssh_keys    = [hcloud_ssh_key.n8n_key.id]
  
  firewall_ids = [hcloud_firewall.n8n_fw.id]

  network {
    network_id = hcloud_network.private_net.id
    ip         = "10.0.1.10" # Static IP in subnet
  }

  # Cloud-init to set up Python for Ansible
  user_data = <<-EOF
    #cloud-config
    packages:
      - python3
      - python3-pip
      - git
      - curl
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
