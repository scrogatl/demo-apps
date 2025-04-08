variable "runtime" {
  description = "The runtime environment for the Lambda function"
  type        = string
  default     = "nodejs14.x"  # Change this to your desired runtime
}

variable "memory_size" {
  description = "The amount of memory allocated for the Lambda function"
  type        = number
  default     = 128  # Default memory size in MB; modify as needed
}

variable "region" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-west-1"  # Default AWS region; modify as needed
}
