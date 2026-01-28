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
