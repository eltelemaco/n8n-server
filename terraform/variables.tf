# variable "hcloud_token" removed - using HCLOUD_TOKEN env var


variable "location" {
  description = "Hetzner Cloud Location"
  type        = string
  default     = "hil" # Hillsboro, OR (us-west)
}

variable "server_type" {
  description = "Server Type"
  type        = string
  default     = "cpx21"
}

variable "server_image" {
  description = "Server Image"
  type        = string
  default     = "ubuntu-24.04"
}

variable "ssh_public_key" {
  description = "SSH public key content to add to the server (store in HCP Terraform as a variable)"
  type        = string
  sensitive   = true # Public keys are safe to store
}

variable "allowed_ssh_ips" {
  description = "List of IPs allowed to SSH (CIDR format). 0.0.0.0/0 for all."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
