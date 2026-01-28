output "server_public_ip" {
  value = hcloud_server.n8n_server.ipv4_address
  description = "Public IP (v4) of the n8n server"
}

output "server_ipv6" {
  value = hcloud_server.n8n_server.ipv6_address
  description = "Public IP (v6) of the n8n server"
}

output "ssh_connection_command" {
  value = "ssh telemaco@${hcloud_server.n8n_server.ipv4_address}"
  description = "Command to SSH into the server (use your local private key)"
}

output "ssh_connection_command_root" {
  value = "ssh root@${hcloud_server.n8n_server.ipv4_address}"
  description = "Alternative: SSH as root (if needed initially)"
}
