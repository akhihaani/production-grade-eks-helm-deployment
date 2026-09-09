locals {
  region = "eu-west-2"
  account_id = "310829530244"
  domain = "memos.abuniyyah.uk"
  ecr_repo = "${local.account_id}.dkr.ecr.${local.region}.amazonaws.com/memos"
  github_repo = "akhihaani/production-grade-eks-helm-deployment"

  tags = {
    Project     = "Memos Application"
    Environment = "Production"
  }
}

# Generate an AWS Provider block
generate "provider" {
    path = "provider.tf"
    if_exists = "overwrite_terragrunt"
    contents = <<EOF
provider "aws" {
  region = "${local.region}"

  # Only these AWS Account IDs may be operated
  allowed_account_ids = ["${local.account_id}"]
}
EOF
}

# Configure Terragrunt to automatically store tfstate files in an S3 bucket
remote_state {
    backend = "s3"
    config = {
        encrypt = true
        bucket = "memos-eks-tfstate-${local.account_id}"
        key = "${path_relative_to_include()}/tf.tfstate"
        region = local.region
        use_lockfile = true
    }
    generate = {
        path = "backend.tf"
        if_exists = "overwrite_terragrunt"
    }
}
