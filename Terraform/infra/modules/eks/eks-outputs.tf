output "cluster_name" { value = aws_eks_cluster.memos_eks_cluster.name }

output "cluster_security_group_id" { value = aws_eks_cluster.memos_eks_cluster.vpc_config[0].cluster_security_group_id }

output "oidc_provider_arn" { value = aws_iam_openid_connect_provider.irsa_oidc_provider.arn }

output "oidc_provider_url" { value = aws_eks_cluster.memos_eks_cluster.identity[0].oidc[0].issuer }

output "cluster_endpoint" { value = aws_eks_cluster.memos_eks_cluster.endpoint }

output "cluster_certificate_authority" { value = aws_eks_cluster.memos_eks_cluster.certificate_authority[0].data }
