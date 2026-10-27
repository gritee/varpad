# Values for `aws configure sso`.

output "sso_start_url" {
  description = "AWS access portal URL (the default form; differs if you set a custom subdomain in the console)."
  value       = "https://${local.identity_store_id}.awsapps.com/start"
}

output "sso_region" {
  value = var.region
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "admin_role_name" {
  value = aws_ssoadmin_permission_set.admin.name
}
