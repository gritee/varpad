variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name prefix for resources and the Project tag."
  type        = string
  default     = "varpad"
}

variable "instance_type" {
  description = "EC2 instance type. The AMI architecture (x86_64/arm64) is derived from it."
  type        = string
  default     = "t3a.micro"
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size in GiB (holds the OS, Docker images and swap)."
  type        = number
  default     = 20
}

variable "swap_size_mb" {
  description = "Swap file size in MiB. Set to 0 to disable."
  type        = number
  default     = 2048
}

variable "ingress_cidrs" {
  description = "IPv4 CIDRs allowed to reach the app on HTTP/HTTPS."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "container_images" {
  description = "Container images to create ECR repositories for; each repo is named <name>/<image>."
  type        = set(string)
  default     = ["web"]
}

variable "ecr_images_to_keep" {
  description = "Number of most recent images each ECR repository keeps; older ones expire."
  type        = number
  default     = 20
}

variable "github_repository" {
  description = "GitHub repo whose main-branch workflows may assume the CI role, as it appears in the OIDC sub claim: owner@owner_id/name@repo_id."
  type        = string
  default     = "gritee@257450698/varpad@1438830019"
}
