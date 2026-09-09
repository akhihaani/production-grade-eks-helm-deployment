include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../modules/eks"
}

dependency "vpc" {
    config_path = "../vpc"

    mock_outputs = {
      memos_private_subnet = ["subnet-mock"]
    }
    mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
}

inputs = {
  tags   = include.root.locals.tags
  memos_private_subnet = dependency.vpc.outputs.memos_private_subnet
}
