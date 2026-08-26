include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../modules/eks-addons"
}

dependency "eks" {
    config_path = "../eks"

    mock_outputs = {
      cluster_endpoint = "https://mock.eks.amazonaws.com"
      cluster_certificate_authority = "bW9jaw=="
      cluster_name = "mock-cluster"
      oidc_provider_arn = "arn:aws:iam::000000000000:oidc-provider/oidc.eks.eu-west-2.amazonaws.com/id/MOCK"
    }
    mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
}

inputs = {
  region = include.root.locals.region
  domain = include.root.locals.domain
  cluster_endpoint = dependency.eks.outputs.cluster_endpoint
  cluster_certificate_authority = dependency.eks.outputs.cluster_certificate_authority
  cluster_name = dependency.eks.outputs.cluster_name
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
}
