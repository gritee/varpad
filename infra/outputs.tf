output "instance_id" {
  value = aws_instance.app.id
}

output "public_ip" {
  description = "Elastic IP; stays the same across instance replacements. Point DNS A records here."
  value       = aws_eip.app.public_ip
}

output "ssm_session_command" {
  description = "Open a shell on the instance (needs the Session Manager plugin locally)."
  value       = "aws ssm start-session --target ${aws_instance.app.id} --region ${var.region}"
}

output "ecr_registry" {
  description = "Registry host for `docker login`."
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
}

output "ecr_repository_urls" {
  description = "Repository URL per image, for docker push/pull and the compose file."
  value       = { for image, repo in aws_ecr_repository.images : image => repo.repository_url }
}
