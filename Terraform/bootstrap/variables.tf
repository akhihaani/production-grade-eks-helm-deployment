variable "region" {
  type        = string
  description = "AWS region to deploy into"
}

variable "account_id" {
  type        = string
  description = "AWS account ID"
}

variable "domain" {
  type        = string
  description = "Domain"
}

variable "github_repo" {
  type        = string
  description = "GitHub Repository"
}

variable "github_owner_id" {
  type        = string
  description = "Numeric GitHub account (user or org) ID, part of the immutable OIDC subject claim"
}

variable "github_repo_id" {
  type        = string
  description = "Numeric GitHub repository ID, part of the immutable OIDC subject claim"
}