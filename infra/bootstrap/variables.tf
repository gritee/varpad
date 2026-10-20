variable "region" {
  description = "AWS region for the state bucket."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name prefix for the bucket and the Project tag."
  type        = string
  default     = "varpad"
}

variable "noncurrent_version_retention_days" {
  description = "Days to keep old state versions before S3 deletes them."
  type        = number
  default     = 90
}
