# Container registry: one ECR repository per image the app's compose file runs.

data "aws_caller_identity" "current" {}

resource "aws_ecr_repository" "images" {
  for_each = toset(var.container_images)

  name                 = "${var.name}/${each.key}"
  image_tag_mutability = "IMMUTABLE"

  # Images are rebuildable from git, so let `terraform destroy` remove a repo
  # that still holds images.
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "images" {
  for_each = aws_ecr_repository.images

  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the ${var.ecr_images_to_keep} most recent images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.ecr_images_to_keep
      }
      action = { type = "expire" }
    }]
  })
}
