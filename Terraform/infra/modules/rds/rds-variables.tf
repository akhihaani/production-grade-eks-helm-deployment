variable "tags" {
  type = map(string)
}

variable "memos_vpc" {
  description = "VPC id the database lives in"
  type        = string
}

variable "memos_private_subnet" {
  description = "Private subnet ids for the DB subnet group (no public access)"
  type        = list(string)
}

variable "allowed_security_group_id" {
  description = "Security group allowed to reach the DB on 5432 (the EKS cluster security group)"
  type        = string
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "max_allocated_storage" {
  description = "Enables storage autoscaling up to this ceiling (GB)"
  type        = number
  default     = 100
}

variable "backup_retention_period" {
  type    = number
  default = 7
}

# --- Dev vs production flags ---
# Defaults below are DEV-FRIENDLY so this can be torn down and rebuilt freely
# For production, flip all three via the live inputs:
# multi_az = true, deletion_protection = true, skip_final_snapshot = false

variable "multi_az" {
  description = "true = standby replica in another AZ (production HA). false = single AZ (cheaper, dev)"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "true blocks accidental deletion. Leave false while iterating, or destroy will refuse."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "true skips the final snapshot on destroy (fine for dev). Set false for production."
  type        = bool
  default     = true
}
