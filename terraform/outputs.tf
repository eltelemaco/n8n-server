output "server_public_ip" {
  value       = hcloud_server.n8n_server.ipv4_address
  description = "Public IP (v4) of the n8n server"
}

output "floating_ip" {
  value       = var.create_floating_ip ? hcloud_floating_ip.n8n_fip[0].ip_address : null
  description = "Stable Floating IPv4 (recommended target for DNS)"
}

output "server_ipv6" {
  value       = hcloud_server.n8n_server.ipv6_address
  description = "Public IP (v6) of the n8n server"
}

output "ssh_connection_command" {
  value       = "ssh ${var.admin_user}@${var.create_floating_ip ? hcloud_floating_ip.n8n_fip[0].ip_address : hcloud_server.n8n_server.ipv4_address}"
  description = "Command to SSH into the server"
}

output "ansible_inventory_hint" {
  value       = "lab1.telemaco.com.mx ansible_host=${var.create_floating_ip ? hcloud_floating_ip.n8n_fip[0].ip_address : hcloud_server.n8n_server.ipv4_address} ansible_user=${var.admin_user}"
  description = "Line you can paste into ansible/inventory.ini"
}

output "ssh_connection_command_root" {
  value       = "ssh root@${hcloud_server.n8n_server.ipv4_address}"
  description = "Alternative: SSH as root (if needed initially)"
}
