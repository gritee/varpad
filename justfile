# Project tasks. Run `just` to list them. Recipes print each command before running it.

# Token for Terraform's GitHub provider, from the GitHub CLI's login.
export GITHUB_TOKEN := env("GITHUB_TOKEN", `gh auth token`)

# List available recipes
default:
    @just --list

# Initialize the main infra module against the S3 backend; extra args go to terraform init
[working-directory('infra')]
init *args: login
    terraform init -backend-config=backend.hcl {{ args }}

# Plan the main infra module into infra/tfplan; extra args go to terraform plan
[working-directory('infra')]
plan *args: login
    terraform plan -out=tfplan {{ args }}

# Apply infra/tfplan, exactly as last planned
[confirm("Apply infra/tfplan? Read the plan first.")]
[working-directory('infra')]
apply: login
    terraform apply tfplan

# Open a shell on the instance via SSM Session Manager
[working-directory('infra')]
ssm: login
    $(terraform output -raw ssm_session_command)

# Show the release each container on the instance was started from, via SSM Run Command
[working-directory('infra')]
live: login
    #!/usr/bin/env bash
    set -euxo pipefail
    instance_id=$(terraform output -raw instance_id)
    command_id=$(aws ssm send-command --instance-ids "$instance_id" \
      --document-name AWS-RunShellScript --comment "just live" \
      --parameters '{"commands":["docker ps --format \"table {{{{.Names}}\\t{{{{.Label \\\"release\\\"}}\\t{{{{.Image}}\\t{{{{.Status}}\""]}' \
      --query Command.CommandId --output text)
    aws ssm wait command-executed --command-id "$command_id" --instance-id "$instance_id"
    aws ssm get-command-invocation --command-id "$command_id" --instance-id "$instance_id" \
      --query StandardOutputContent --output text

# Log in to AWS SSO only if there's no valid session
[private]
login:
    @aws sts get-caller-identity >/dev/null 2>&1 || aws sso login
