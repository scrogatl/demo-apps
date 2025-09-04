variable "project_prefix" {
  description = "A short prefix used for naming all resources."
  type        = string
}

variable "location" {
  description = "The Azure region where resources will be created."
  type        = string
  default     = "East US"
}

variable "admin_username" {
  description = "The admin username for the VM."
  type        = string
  default     = "azureadmin"
}

variable "admin_password" {
  description = "The admin password for the VM. Must be complex."
  type        = string
  sensitive   = true
}

variable "my_ip_address" {
  description = "Your local public IP address to allow SSH and web access."
  type        = string
}

variable "vm_size" {
  description = "The size of the Azure VM for the application."
  type        = string
  default     = "Standard_D4s_v3" # A size with enough memory for SQL Server
}

variable "sql_password" {
  description = "The SA password for the SQL Server container. Must be complex."
  type        = string
  sensitive   = true
}

# New variable to define the path to the project root
variable "project_root_path" {
  type        = string
  description = "The relative path to the project root directory from the terraform directory."
  default     = ".."
}

variable "new_relic_license_key" {
  description = "Your New Relic Ingest License Key."
  type        = string
  sensitive   = true
}

variable "new_relic_team_tag" {
  description = "Value of 'nr.team' tag."
  type        = string
  default     = ""
}

variable "new_relic_environment_tag" {
  description = "Value of 'environment' tag."
  type        = string
  default     = "staging"
}
