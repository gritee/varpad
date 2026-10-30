variable "account_id" {
  description = "AWS account to deploy into. Terraform stops if the credentials belong to another account."
  type        = string
}

variable "region" {
  description = "Region where IAM Identity Center is enabled."
  type        = string
}

variable "name" {
  description = "Account/project name, used in descriptions and the Project tag."
  type        = string
}

# --- Admin user (set in terraform.tfvars; see terraform.tfvars.example) ---

variable "admin_user_name" {
  description = "Identity Center username for the admin user (used to sign in)."
  type        = string
}

variable "admin_email" {
  description = "Admin user's email; receives the password setup link."
  type        = string
}

variable "admin_given_name" {
  description = "Admin user's first name."
  type        = string
}

variable "admin_family_name" {
  description = "Admin user's last name."
  type        = string
}

variable "admin_session_duration" {
  description = "How long an admin CLI/console session lasts before re-login (ISO 8601 duration, max PT12H)."
  type        = string
  default     = "PT8H"
}

# Unused here; declared so the shared project.auto.tfvars loads without warnings.
variable "github_repository" {
  type = string
}
