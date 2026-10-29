# infra

Terraform for varpad's AWS infrastructure: a single EC2 instance (Ubuntu 24.04 + Docker)
in the default VPC, with an Elastic IP, a security group for HTTP/HTTPS, and an IAM role
for SSM Session Manager access.

## Layout

| Path | What it is |
|---|---|
| `infra/` | Main root module: the app infrastructure. State lives in S3 (see below). |
| `infra/bootstrap/` | Creates the S3 state bucket. Uses **local** state, committed to git. |
| `infra/account/` | Account access: an IAM Identity Center admin user and group. State in S3. |
| `infra/user-data.sh.tftpl` | First-boot script (swap, Docker, `/opt/app`). Editing it **replaces the instance**. |

Each directory is its own root module: run Terraform from inside it (or with
`terraform -chdir=<dir> ...`) and `terraform init` each one separately.

## Prerequisites

- **Terraform**, at the version pinned in `.terraform-version`.
- **AWS CLI v2**, with an SSO profile named `varpad-admin` (created in first-time setup).
- **[Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)** for shell access to the instance.
- **[just](https://just.systems/man/en/)** for the project tasks in the repo-root `justfile`.
- **[direnv](https://direnv.net/)** (optional) to set `AWS_PROFILE` automatically.

### AWS profile

The repo-root `.envrc` sets `AWS_PROFILE=varpad-admin` for Terraform and the AWS CLI:

- **With direnv:** run `direnv allow` once in the repo; it then loads on `cd` and unloads on leaving.
- **Without direnv:** run `source .envrc` in each new terminal.
- **Different profile name?** Put `export AWS_PROFILE=<yours>` in `.envrc.local` (gitignored).

Check which identity you're using with `aws sts get-caller-identity` before applying.

## First-time setup

Steps 1–4 run as the account's root user, once. Everything after runs as the admin identity.

1. **Create the state bucket**
   ```sh
   cd infra/bootstrap
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   git add terraform.tfstate && git commit -m "Bootstrap Terraform state bucket"
   ```
2. **Point the other modules at it.** Paste `terraform output -raw backend_config_account`
   into the `terraform {}` block in `infra/account/versions.tf`, and
   `terraform output -raw backend_config_infra` into the one in `infra/versions.tf`.
   Commit both files.
3. **Enable IAM Identity Center** in the console, in `us-east-1`. This can't be done from
   Terraform.
4. **Create the admin user**
   ```sh
   cd infra/account
   cp terraform.tfvars.example terraform.tfvars   # fill in; gitignored
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   ```
5. **Finish the admin user in the console** (IAM Identity Center → Users): send the
   password setup email, sign in at the access portal (`terraform output sso_start_url`),
   and enroll MFA.
6. **Switch the CLI to the admin identity**
   ```sh
   aws configure sso      # values from `terraform output`; name the profile varpad-admin
   aws logout             # drop the root credentials from `aws login`
   direnv allow           # or: source .envrc   (from the repo root; sets AWS_PROFILE)
   aws sso login
   aws sts get-caller-identity   # should show AWSReservedSSO_AdministratorAccess_..., not root
   ```
   From here on, don't use root. Make sure it has MFA and no access keys.
7. **Initialize the main module**
   ```sh
   cd infra
   terraform init        # add -migrate-state if it reports existing local state
   ```
   Then follow the workflow below.

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

## Project tasks (`just`)

The repo-root `justfile` wraps the commands above for the main module. Recipes work
from any directory in the repo, log in to AWS SSO first if the session has expired, and
print each command before running it.

```sh
just                 # list recipes
just plan            # terraform plan -out=tfplan (extra args pass through)
just apply           # terraform apply tfplan, after a confirmation prompt
just ssm             # shell on the instance via SSM Session Manager
just live            # release each running container was started from (via SSM Run Command)
just --dry-run plan  # show the commands without running them
```

The bootstrap and account modules are run by hand, as in first-time setup.

## Useful commands

```sh
terraform output                                 # public_ip (Elastic IP), instance_id, ...
$(terraform output -raw ssm_session_command)     # shell on the instance (or: just ssm)
```

On the instance, check first-boot setup with `cloud-init status --long` and
`sudo tail -100 /var/log/cloud-init-output.log`.

## Revisit when adding CI/CD

Once CI runs Terraform (or a second person does), switch to: **plan on PR → review the code
and the plan → apply from CI after merge**, and stop applying from laptops. The S3 backend's
lock file (`use_lockfile = true`) already prevents concurrent applies.
