output "memos_name_servers" {
  value = aws_route53_zone.memos_hosted_zone.name_servers
}

output "memos_repo_url" {
  value = aws_ecr_repository.memos_repo.repository_url
}

output "memos_hosted_zone_id" {
  value = aws_route53_zone.memos_hosted_zone.zone_id
}
