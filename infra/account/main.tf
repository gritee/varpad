# --- Admin identity: IAM Identity Center user with AdministratorAccess to this account ---
#
# Prerequisite (console only): enable IAM Identity Center in var.region. The API can't
# create the organization instance needed to grant access to AWS accounts.
# After apply (console only): send the user a password setup email and enroll MFA.

data "aws_caller_identity" "current" {}

data "aws_ssoadmin_instances" "this" {
  lifecycle {
    postcondition {
      condition     = length(self.arns) > 0
      error_message = "IAM Identity Center isn't enabled in ${var.region}. Enable it in the console, then re-run plan."
    }
  }
}

locals {
  sso_instance_arn  = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
}

resource "aws_identitystore_group" "admins" {
  identity_store_id = local.identity_store_id
  display_name      = "Administrators"
  description       = "Full administrator access to the ${var.name} account."
}

resource "aws_identitystore_user" "admin" {
  identity_store_id = local.identity_store_id
  user_name         = var.admin_user_name
  display_name      = "${var.admin_given_name} ${var.admin_family_name}"

  name {
    given_name  = var.admin_given_name
    family_name = var.admin_family_name
  }

  emails {
    value   = var.admin_email
    primary = true
  }
}

resource "aws_identitystore_group_membership" "admin" {
  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.admins.group_id
  member_id         = aws_identitystore_user.admin.user_id
}

resource "aws_ssoadmin_permission_set" "admin" {
  name             = "AdministratorAccess"
  description      = "Full access, via the AWS managed AdministratorAccess policy."
  instance_arn     = local.sso_instance_arn
  session_duration = var.admin_session_duration
}

resource "aws_ssoadmin_managed_policy_attachment" "admin" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Assign to the group, not the user, so adding a second admin is just a membership.
resource "aws_ssoadmin_account_assignment" "admins" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
  principal_type     = "GROUP"
  principal_id       = aws_identitystore_group.admins.group_id
  target_type        = "AWS_ACCOUNT"
  target_id          = data.aws_caller_identity.current.account_id

  # The assignment only grants what the permission set holds once its policy is attached.
  depends_on = [aws_ssoadmin_managed_policy_attachment.admin]
}
