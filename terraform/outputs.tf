output "server_public_ip" {
  value = hcloud_server.n8n_server.ipv4_address
  description = "Public IP (v4) of the n8n server"
}

output "server_ipv6" {
  value = hcloud_server.n8n_server.ipv6_address
  description = "Public IP (v6) of the n8n server"
}

output "private_key_path" {
  value = abspath(local_file.private_key.filename)
  description = "Path to the generated private key"
}
