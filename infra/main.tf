# --- AMI: latest Ubuntu 24.04 LTS matching the instance type's architecture ---

data "aws_ec2_instance_type" "app" {
  instance_type = var.instance_type
}

locals {
  # Canonical names architectures amd64/arm64 (not x86_64).
  arch = contains(data.aws_ec2_instance_type.app.supported_architectures, "arm64") ? "arm64" : "amd64"
}

# Published by Canonical; official Ubuntu AMIs ship with the SSM agent preinstalled.
data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/${local.arch}/hvm/ebs-gp3/ami-id"
}

# --- Network: default VPC, in a subnet whose AZ offers the instance type ---

data "aws_vpc" "default" {
  default = true
}

data "aws_ec2_instance_type_offerings" "app" {
  location_type = "availability-zone"

  filter {
    name   = "instance-type"
    values = [var.instance_type]
  }
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }

  filter {
    name   = "availability-zone"
    values = data.aws_ec2_instance_type_offerings.app.locations
  }
}

resource "aws_security_group" "app" {
  name        = "${var.name}-app"
  description = "Web traffic in; all traffic out. No SSH: use SSM Session Manager."
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  for_each = toset(var.ingress_cidrs)

  security_group_id = aws_security_group.app.id
  description       = "HTTP"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  for_each = toset(var.ingress_cidrs)

  security_group_id = aws_security_group.app.id
  description       = "HTTPS"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = each.value
}

# Outbound is needed for SSM, ECR pulls and package installs.
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.app.id
  description       = "All outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# --- Instance ---

resource "aws_instance" "app" {
  ami                    = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type          = var.instance_type
  subnet_id              = sort(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.app.name

  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    swap_size_mb = var.swap_size_mb
  })
  user_data_replace_on_change = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size_gb
    encrypted             = true
    delete_on_termination = true
  }

  # Require IMDSv2. Hop limit 2 lets containers reach the metadata service
  # (and so the instance role's credentials).
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = {
    Name = "${var.name}-app"
  }

  lifecycle {
    # New Ubuntu AMIs are published every few weeks; don't replace the instance
    # on every apply. Roll forward deliberately with: terraform apply -replace=aws_instance.app
    ignore_changes = [ami]
  }
}

# --- Elastic IP: stable address for DNS A records across instance replacements ---

resource "aws_eip" "app" {
  domain   = "vpc"
  instance = aws_instance.app.id

  tags = {
    Name = "${var.name}-app"
  }
}
