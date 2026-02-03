variable "name" {
  description = "Server name"
  type        = string
  default     = "lab1-n8n"
}

variable "location" {
  description = "Hetzner Cloud location (e.g. fsn1, nbg1, hel1, ash, hil)"
  type        = string
  default     = "hil"
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

variable "admin_user" {
  description = "Linux admin user for Ansible/SSH"
  type        = string
  default     = "telemaco"
}

variable "create_ssh_key" {
  description = "If true, generate a new ED25519 SSH keypair locally and upload the public key to Hetzner"
  type        = bool
  default     = false
}

variable "ssh_public_key" {
  description = "If create_ssh_key=false, provide an existing SSH public key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ssh_private_key_path" {
  description = "Where to write the generated private key (only used when create_ssh_key=true)"
  type        = string
  default     = "~/.ssh/n8n-server"
}

variable "ssh_public_key_path" {
  description = "Where to write the generated public key (only used when create_ssh_key=true)"
  type        = string
  default     = "~/.ssh/n8n-server.pub"
}

variable "allowed_ssh_ips" {
  description = "List of IPs allowed to SSH (CIDR format). 0.0.0.0/0 for all."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "create_floating_ip" {
  description = "If true, allocate a Floating IP and attach it to the server (recommended for stable DNS)"
  type        = bool
  default     = true
}
