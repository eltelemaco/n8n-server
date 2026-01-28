# Generate a new SSH key pair
resource "tls_private_key" "n8n_key" {
  algorithm = "ED25519"
}

# Save the private key locally
resource "local_file" "private_key" {
  content         = tls_private_key.n8n_key.private_key_openssh
  filename        = "${path.module}/n8n_key"
  file_permission = "0600"
}

# Upload the public key to Hetzner
resource "hcloud_ssh_key" "n8n_key" {
  name       = "n8n-auto-key"
  public_key = tls_private_key.n8n_key.public_key_openssh
}
