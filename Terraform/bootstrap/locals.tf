locals {
  tags = {
    Environment = "Production"
    Project     = "Memos Application"
  }

  # GitHub immutable OIDC subject (July 2026+). Encodes the org and repo numeric IDs
  # so the trust survives renames and resists namespace-recycling attacks.
  github_oidc_sub = "repo:${split("/", var.github_repo)[0]}@${var.github_owner_id}/${split("/", var.github_repo)[1]}@${var.github_repo_id}:ref:refs/heads/main"
}
