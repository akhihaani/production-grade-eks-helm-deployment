# RDS PostgreSQL for memos
#
# Design notes:
# - Lives in PRIVATE subnets, no public access.
# - Reachable only from the EKS cluster security group, on 5432.
# - Encrypted at rest with a customer-managed KMS key.
# - TLS enforced in transit via rds.force_ssl = 1 (app must use sslmode=require).
# - Master credentials are managed by RDS in AWS Secrets Manager
#   (manage_master_user_password), so no password ever lands in Terraform state.

# KMS key for storage + secret encryption

resource "aws_kms_key" "memos_rds_kms" {
  description         = "memos RDS storage and master-secret encryption"
  enable_key_rotation = true
  tags                = var.tags
}

resource "aws_kms_alias" "memos_rds_kms" {
  name          = "alias/memos-rds"
  target_key_id = aws_kms_key.memos_rds_kms.key_id
}

# Networking

resource "aws_db_subnet_group" "memos_db_subnet_group" {
  name       = "memos-db-subnet-group"
  subnet_ids = var.memos_private_subnet
  tags       = var.tags
}

resource "aws_security_group" "memos_rds_sg" {
  name        = "memos-rds-sg"
  description = "Allow Postgres from the EKS cluster only"
  vpc_id      = var.memos_vpc

  ingress {
    description     = "Postgres from the EKS cluster security group"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.allowed_security_group_id]
  }

  tags = var.tags
}

# Parameter group: enforce TLS

resource "aws_db_parameter_group" "memos_pg" {
  name   = "memos-postgres-params"
  family = "postgres16"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = var.tags
}

# --- The database instance ---

resource "aws_db_instance" "memos_postgres" {
  identifier     = "memos-postgres"
  engine         = "postgres"
  engine_version = "16.15"
  instance_class = var.instance_class

  db_name  = "memos"
  username = "memos"

  # RDS generates and stores the master password in Secrets Manager for us.
  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.memos_rds_kms.key_id

  # Storage (encrypted, with autoscaling headroom)
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.memos_rds_kms.arn

  # Networking (private only)
  db_subnet_group_name   = aws_db_subnet_group.memos_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.memos_rds_sg.id]
  publicly_accessible    = false
  parameter_group_name   = aws_db_parameter_group.memos_pg.name

  # Availability + backups
  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period
  copy_tags_to_snapshot   = true

  # Observability
  performance_insights_enabled    = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # Lifecycle
  auto_minor_version_upgrade = true
  deletion_protection        = var.deletion_protection
  skip_final_snapshot        = var.skip_final_snapshot
  final_snapshot_identifier  = var.skip_final_snapshot ? null : "memos-postgres-final"

  tags = var.tags
}
