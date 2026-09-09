include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../modules/vpc"
}

inputs = {
  region = include.root.locals.region
  tags   = include.root.locals.tags
}
