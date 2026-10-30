# GitHub Actions access via OIDC: workflows on main assume a role that can push images;
# jobs in the `production` environment (gated by required reviewers) assume one that can
# deploy them. No long-lived AWS keys are stored in GitHub.
#
# The repo side is managed here too: the `production` environment, and the Actions
# variables the workflows read, so they follow any change to the values behind them.

locals {
  github_owner = split("/", var.github_repository)[0]

  # OIDC sub claims name the repo as owner@owner_id/name@repo_id.
  github_oidc_repo = "${data.github_user.owner.login}@${data.github_user.owner.id}/${data.github_repository.app.name}@${data.github_repository.app.repo_id}"
}

data "github_repository" "app" {
  full_name = var.github_repository
}

data "github_user" "owner" {
  username = local.github_owner
}

# An empty username looks up the authenticated user: whoever runs Terraform reviews deploys.
data "github_user" "current" {
  username = ""
}

resource "github_repository_environment" "production" {
  repository  = data.github_repository.app.name
  environment = "production"

  reviewers {
    users = [data.github_user.current.id]
  }

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "production_main" {
  repository     = data.github_repository.app.name
  environment    = github_repository_environment.production.environment
  branch_pattern = "main"
}

resource "github_actions_variable" "app" {
  for_each = {
    AWS_REGION          = var.region
    AWS_PUSH_ROLE_ARN   = aws_iam_role.github_actions.arn
    AWS_DEPLOY_ROLE_ARN = aws_iam_role.github_deploy.arn
    ECR_REPO_PREFIX     = var.name
    IMAGE_PLATFORM      = "linux/${local.arch}"
    INSTANCE_NAME       = aws_instance.app.tags.Name
  }

  repository    = data.github_repository.app.name
  variable_name = each.key
  value         = each.value
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

resource "aws_iam_role" "github_actions" {
  name = "${var.name}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:${local.github_oidc_repo}:ref:refs/heads/main"
        }
      }
    }]
  })
}

# Push (and pull) access to this app's ECR repos only.
resource "aws_iam_role_policy" "github_ecr_push" {
  name = "ecr-push"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # `docker login`; this action doesn't support resource scoping.
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
        ]
        Resource = [for repo in aws_ecr_repository.images : repo.arn]
      },
    ]
  })
}

# Jobs that name an environment get an environment sub claim instead of the branch one.
resource "aws_iam_role" "github_deploy" {
  name = "${var.name}-github-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:${local.github_oidc_repo}:environment:${github_repository_environment.production.environment}"
        }
      }
    }]
  })
}

# Run a shell script on the app instance via SSM Run Command, and read its result.
resource "aws_iam_role_policy" "github_deploy" {
  name = "deploy"
  role = aws_iam_role.github_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ssm:SendCommand"
        Resource = "arn:aws:ssm:${var.region}::document/AWS-RunShellScript"
      },
      {
        # Separate statement: the tag condition would never match the document above.
        Effect   = "Allow"
        Action   = "ssm:SendCommand"
        Resource = "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:instance/*"
        Condition = {
          StringEquals = { "ssm:resourceTag/Name" = aws_instance.app.tags.Name }
        }
      },
      {
        # Neither action supports resource scoping.
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances", "ssm:GetCommandInvocation"]
        Resource = "*"
      },
    ]
  })
}
