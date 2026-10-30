output "bucket" {
  value = aws_s3_bucket.tfstate.id
}

output "backend_hcl" {
  description = "Backend settings shared by ../ and ../account. Write to ../backend.hcl and commit it."
  value       = <<-EOT
    bucket = "${aws_s3_bucket.tfstate.id}"
    region = "${var.region}"
  EOT
}
