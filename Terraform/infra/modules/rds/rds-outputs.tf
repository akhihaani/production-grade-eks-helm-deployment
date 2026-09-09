# The app needs host + port + db name (from here) plus username + password
# (from the Secrets Manager secret below) to assemble its MEMOS_DSN.
# External Secrets Operator will read the secret; the host/port/db come from these outputs.

output "db_address" {
  description = "Endpoint hostname of the instance"
  value       = aws_db_instance.memos_postgres.address
}

output "db_port" {
  value = aws_db_instance.memos_postgres.port
}

output "db_name" {
  value = aws_db_instance.memos_postgres.db_name
}

output "db_username" {
  value = aws_db_instance.memos_postgres.username
}

output "master_user_secret_arn" {
  description = "Secrets Manager secret (JSON: username/password) that RDS manages"
  value       = aws_db_instance.memos_postgres.master_user_secret[0].secret_arn
}

output "rds_security_group_id" {
  value = aws_security_group.memos_rds_sg.id
}

output "kms_key_arn" {
  value = aws_kms_key.memos_rds_kms.arn
}
