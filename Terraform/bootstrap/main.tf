# S3 Bucket for tfstate

resource "aws_s3_bucket" "memos_state" {
  bucket = "memos-eks-tfstate-${var.account_id}"

  force_destroy = true

  tags = local.tags
}

resource "aws_s3_bucket_versioning" "memos_state_versioning" {
  bucket = aws_s3_bucket.memos_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "memos_state_encryption" {
  bucket = aws_s3_bucket.memos_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "memos_state_public_block" {
  bucket                  = aws_s3_bucket.memos_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Route53 Hosted Zone

resource "aws_route53_zone" "memos_hosted_zone" {
  name = var.domain

  tags = local.tags
}

# ECR Repository

resource "aws_ecr_repository" "memos_repo" {
  name                 = "memos"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  force_delete = true

  tags = local.tags
}

resource "aws_ecr_lifecycle_policy" "memos_repo_lifecycle" {
  repository = aws_ecr_repository.memos_repo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = { type = "expire" }
      }
    ]
  })
}

# OIDC

resource "aws_iam_openid_connect_provider" "memos_oidc_provider" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  tags = local.tags
}

resource "aws_iam_role" "memos_github_role" {
  name = "memos_github_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Federated = aws_iam_openid_connect_provider.memos_oidc_provider.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = local.github_oidc_sub
          }
        }
      },
    ]
  })

  tags = local.tags
}

resource "aws_iam_policy" "memos_github_tight_policy" {
  name = "memos_github_tight_policy"
  policy = templatefile("${path.module}/github-tight-policy.json.tftpl", {
    region     = var.region
    account_id = var.account_id
  })
}

resource "aws_iam_role_policy_attachment" "memos_github_tight_policy_attach" {
  role       = aws_iam_role.memos_github_role.name
  policy_arn = aws_iam_policy.memos_github_tight_policy.arn
}