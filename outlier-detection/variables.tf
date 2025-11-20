variable "aws_region" {
  description = "The AWS region to deploy all resources in."
  type        = string
  default     = "us-west-1"
}

variable "ssh_ingress_cidr" {
  description = "The CIDR block (e.g., your IP/32) allowed for SSH access."
  type        = string
  default     = ""
}

variable "new_relic_api_key" {
  description = "Your New Relic User API Key."
  type        = string
  default     = ""
  sensitive   = true
}

variable "new_relic_account_id" {
  description = "Your New Relic Account ID."
  type        = string
  default     = ""
}

variable "ec2_key_name" {
  description = "The name of the existing EC2 KeyPair to use for SSH access."
  type        = string
  default     = ""
}
