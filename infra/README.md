# infra

Terraform for varpad's AWS infrastructure: a single EC2 instance (Ubuntu 24.04 + Docker)
in the default VPC, with an Elastic IP, a security group for HTTP/HTTPS, and an IAM role
for SSM Session Manager access.

## Layout

| Path | What it is |
|---|---|
| `infra/` | Main root module: the app infrastructure. State lives in S3 (see below). |
| `infra/bootstrap/` | Separate root module that creates the S3 state bucket. Uses **local** state, committed to git. |
| `infra/user-data.sh.tftpl` | First-boot script (swap, Docker, `/opt/app`). Editing it **replaces the instance**. |

Each directory is its own root module: run Terraform from inside it (or with
`terraform -chdir=<dir> ...`) and `terraform init` each one separately.

## Prerequisites

- Terraform, at the version pinned in `.terraform-version`.
- AWS CLI v2 and credentials for the target account.
- [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) for shell access.

## First-time setup

1. **Create the state bucket**
   ```sh
   cd infra/bootstrap
   terraform init
   terraform apply
   git add terraform.tfstate && git commit -m "Bootstrap Terraform state bucket"
   ```
2. **Point the main module at it.** Paste the output of
   `terraform output -raw backend_config` into the `terraform {}` block in
   `infra/versions.tf`.
3. **Migrate any existing local state**
   ```sh
   cd infra
   terraform init -migrate-state
   ```
   Confirm `terraform plan` shows no changes, then delete the leftover local
   `terraform.tfstate*` files and commit `versions.tf`.

## Workflow: apply, then commit

While Terraform is run by one person from a laptop, changes are applied **before** they
are committed or merged. A PR review would add nothing here, since the plan is the review.

**Rule: `main` always matches what is deployed.** Never leave applied changes uncommitted,
and never commit unapplied changes to `main`.

### Small changes (directly on `main`)

```sh
terraform plan                   # expect "No changes": no drift, nothing half-applied
# edit .tf files
terraform fmt && terraform validate
terraform plan -out=tfplan       # read it; look hard at "must be replaced" and "destroy"
terraform apply tfplan           # applies exactly what was reviewed
git add -A && git commit         # immediately, describing the infrastructure change
```

### Larger or exploratory changes (on a branch)

1. `git switch -c <topic>`, then apply from the branch as often as needed using the loop above.
2. **Merge to `main` as soon as the change settles.** While a branch has live changes, `main`
   is out of date, and applying from `main` would undo the branch's work.
3. Have **at most one branch with live changes** at a time. Before applying from anywhere else,
   merge it or roll it back (`git switch main && terraform apply`).

### When things go sideways

- **Apply fails partway.** State records whatever was created. Fix the code, `plan` again
  (it shows only what remains), apply, then commit. Don't revert to retry; the code should
  match what's now deployed.
- **`plan` shows changes you didn't make (drift).** Someone changed something in the console.
  Either add that change to the code, or apply to undo it.
- **Bootstrap changes** follow the same loop. Commit the updated `bootstrap/terraform.tfstate`
  along with the code.

### Things that replace the instance

These destroy the server and create a new one (new root disk; the Elastic IP moves over):

- editing `user-data.sh.tftpl` or its inputs (e.g. `swap_size_mb`)
- `terraform apply -replace=aws_instance.app` (also the way to adopt a newer Ubuntu AMI,
  which is otherwise ignored)
- some instance argument changes. The plan says `must be replaced`.

## Useful commands

```sh
terraform output                                 # public_ip (Elastic IP), instance_id, ...
$(terraform output -raw ssm_session_command)     # shell on the instance
```

On the instance, check first-boot setup with `cloud-init status --long` and
`sudo tail -100 /var/log/cloud-init-output.log`.

## Revisit when adding CI/CD

Once CI runs Terraform (or a second person does), switch to: **plan on PR → review the code
and the plan → apply from CI after merge**, and stop applying from laptops. The S3 backend's
lock file (`use_lockfile = true`) already prevents concurrent applies.
