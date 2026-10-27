output "bucket" {
  value = aws_s3_bucket.tfstate.id
}

locals {
  backend_block = <<-EOT
    backend "s3" {
      bucket       = "${aws_s3_bucket.tfstate.id}"
      key          = "%s/terraform.tfstate"
      region       = "${var.region}"
      encrypt      = true
      use_lockfile = true
    }
  EOT
}

output "backend_config_account" {
  description = "Paste into the terraform {} block in ../account/versions.tf."
  value       = format(local.backend_block, "account")
}

output "backend_config_infra" {
  description = "Paste into the terraform {} block in ../versions.tf."
  value       = format(local.backend_block, "infra")
}
