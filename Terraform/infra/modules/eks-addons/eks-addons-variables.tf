variable "region" { type = string }

variable "cluster_certificate_authority" { type = string }

variable "cluster_endpoint" { type = string }

variable "cluster_name" { type = string }

variable "oidc_provider_arn" { type = string }

variable "domain" { type = string }

# RDS secret bridge: passed from the rds unit so External Secrets Operator can be
# scoped to read exactly this one secret and decrypt it with the RDS KMS key.
variable "db_master_secret_arn" { type = string }

variable "db_kms_key_arn" { type = string }
