# Upload the user-provided public key to Hetzner
# The public key should be stored as a variable in HCP Terraform
resource "hcloud_ssh_key" "n8n_key" {
  name       = "n8n-server-key"
  public_key = var.ssh_public_key
}
