provider "helm" {
  kubernetes = {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_certificate_authority)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region]
    }
  }
}

# ArgoCD
resource "helm_release" "argo_cd" {
  name = "argo-cd"

  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  create_namespace = true
  namespace        = "argocd"
}

# Cert Manager
resource "helm_release" "cert_manager" {
  name = "cert-manager"

  repository       = "oci://quay.io/jetstack/charts"
  chart            = "cert-manager"
  version          = "v1.20.0"
  create_namespace = true
  namespace        = "cert-manager"
  depends_on       = [module.cert_manager_irsa_role.iam_role_arn]

  # First entry: cert-manager waits for the IAM role to be created.
  # Second entry: installs the custom resource definitions.
  set = [
    {
      name  = "crds.enabled"
      value = "true"
    },
  ]

  values = [file("${path.module}/helm-values/cert-manager.yaml")]
}

# Cert Manager IRSA (IAM roles for service accounts)
## This allows the created IAM role to be able to add records to the hosted zone
module "cert_manager_irsa_role" {
  # This is a registry submodule, so Terraform requires `//modules/...`.
  # Pinning the version keeps your code aligned with the tutorial/module API.
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.2.0"


  role_name                     = "cert_manager"
  attach_cert_manager_policy    = true
  cert_manager_hosted_zone_arns = [data.aws_route53_zone.memos.arn] #Hosted Zone ID

  oidc_providers = {
    eks = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["cert-manager:cert-manager"]
    }
  }

}

# External DNS
resource "helm_release" "external_dns" {
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  create_namespace = true
  namespace        = "external-dns"
  depends_on       = [module.external_dns_irsa_role.iam_role_arn]

  values = [file("${path.module}/helm-values/external-dns.yaml")]
}

# External DNS IRSA
module "external_dns_irsa_role" {
  # Same fix here: use `//modules/...` for a registry submodule path.
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.2.0"

  role_name                     = "external_dns"
  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = [data.aws_route53_zone.memos.arn]

  oidc_providers = {
    eks = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["external-dns:external-dns"]
    }
  }
}

data "aws_route53_zone" "memos" {
  name = var.domain
}

# Prometheus + Grafana
resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true

  values = [yamlencode({
    grafana = {
      ingress = {
        enabled          = true
        ingressClassName = "nginx"
        annotations = {
          "cert-manager.io/cluster-issuer" = "letsencrypt-staging"
        }
        hosts = ["grafana.memos.abuniyyah.uk"]
        tls = [{
          secretName = "grafana-tls"
          hosts      = ["grafana.memos.abuniyyah.uk"]
        }]
      }
      "grafana.ini" = {
        server = {
          root_url = "https://grafana.memos.abuniyyah.uk"
        }
      }
    }
  })]
}
