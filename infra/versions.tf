terraform {
  required_version = ">= 1.16.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.69"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.13"
    }
  }

  # bucket and region come from infra/backend.hcl, written by infra/bootstrap:
  #   terraform init -backend-config=backend.hcl
  backend "s3" {
    key          = "infra/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = {
      Project   = var.name
      ManagedBy = "terraform"
    }
  }
}

# Authenticates with GITHUB_TOKEN; the justfile sets it from `gh auth token`.
provider "github" {
  owner = local.github_owner
}
