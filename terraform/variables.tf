# variable "hcloud_token" removed - using HCLOUD_TOKEN env var


variable "location" {
  description = "Hetzner Cloud Location"
  type        = string
  default     = "hil" # Hillsboro, OR (us-west)
}

variable "server_type" {
  description = "Server Type"
  type        = string
  default     = "cpx22"
}

variable "server_image" {
  description = "Server Image"
  type        = string
  default     = "ubuntu-24.04"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key to upload"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key (for Ansible usage if needed)"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "allowed_ssh_ips" {
  description = "List of IPs allowed to SSH (CIDR format). 0.0.0.0/0 for all."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
