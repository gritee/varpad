output "bucket" {
  value = aws_s3_bucket.tfstate.id
}

output "backend_config" {
  description = "Paste into the terraform {} block in ../versions.tf, then run `terraform init -migrate-state` there."
  value       = <<-EOT
    backend "s3" {
      bucket       = "${aws_s3_bucket.tfstate.id}"
      key          = "infra/terraform.tfstate"
      region       = "${var.region}"
      encrypt      = true
      use_lockfile = true
    }
  EOT
}
