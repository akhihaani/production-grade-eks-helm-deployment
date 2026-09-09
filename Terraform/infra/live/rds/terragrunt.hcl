include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../modules/rds"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    memos_vpc            = "vpc-mock"
    memos_private_subnet = ["subnet-mock-a", "subnet-mock-b", "subnet-mock-c"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_security_group_id = "sg-mock"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
}

inputs = {
  tags   = include.root.locals.tags

  memos_vpc                 = dependency.vpc.outputs.memos_vpc
  memos_private_subnet      = dependency.vpc.outputs.memos_private_subnet
  allowed_security_group_id = dependency.eks.outputs.cluster_security_group_id

  # Flip these to production values when you do the final hardening pass:
  # multi_az            = true
  # deletion_protection = true
  # skip_final_snapshot = false
}
