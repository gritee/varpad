variable "account_id" {
  description = "AWS account to deploy into. Terraform stops if the credentials belong to another account."
  type        = string
}

variable "region" {
  description = "AWS region for the state bucket."
  type        = string
}

variable "name" {
  description = "Name prefix for the bucket and the Project tag."
  type        = string
}

variable "noncurrent_version_retention_days" {
  description = "Days to keep old state versions before S3 deletes them."
  type        = number
  default     = 90
}

# Unused here; declared so the shared project.auto.tfvars loads without warnings.
variable "github_repository" {
  type = string
}
