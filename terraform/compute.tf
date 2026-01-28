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
    disable_root: false  # Keep root enabled initially for Hetzner's SSH key injection
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
