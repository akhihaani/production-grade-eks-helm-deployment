# EKS Cluster + IAM role

resource "aws_eks_cluster" "memos_eks_cluster" {
  name = "memos-eks-cluster"

  access_config {
    authentication_mode = "API"
  }
  role_arn = aws_iam_role.memos_cluster_role.arn
  version  = "1.35"
  vpc_config {
    subnet_ids = var.memos_private_subnet
  }
  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
  ]

  tags = var.tags
}

resource "aws_iam_role" "memos_cluster_role" {
  name = "memos-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.memos_cluster_role.name
}

# EKS Node Group + IAM role

resource "aws_eks_node_group" "memos_eks_node_group" {
  cluster_name    = aws_eks_cluster.memos_eks_cluster.name
  node_group_name = "memos-eks-node-group"
  node_role_arn   = aws_iam_role.memos_node_group_role.arn
  subnet_ids      = var.memos_private_subnet

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.memos-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.memos-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.memos-AmazonEC2ContainerRegistryReadOnly,
  ]
}

resource "aws_iam_role" "memos_node_group_role" {
  name = "memos-node-group-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "memos-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.memos_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "memos-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.memos_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "memos-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.memos_node_group_role.name
}

# OIDC

data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.memos_eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "irsa_oidc_provider" {
  url             = aws_eks_cluster.memos_eks_cluster.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]

  tags = var.tags
}

data "aws_caller_identity" "current" {}

resource "aws_eks_access_entry" "github_role" {
  cluster_name  = aws_eks_cluster.memos_eks_cluster.name
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/memos_github_role"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "github_admin" {
  cluster_name  = aws_eks_cluster.memos_eks_cluster.name
  principal_arn = aws_eks_access_entry.github_role.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope { type = "cluster" }
}
