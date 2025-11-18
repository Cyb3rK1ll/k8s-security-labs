# EKS cluster data
data "aws_eks_cluster" "eks" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "eks" {
  name = var.cluster_name
}

module "defectdojo" {
  source = "../modules/defectdojo"

  providers = {
    helm       = helm.eks
    kubernetes = kubernetes.eks
  }

  cluster_name = var.cluster_name
  domain_name  = var.domain_name
  chart_url    = var.defectdojo_chart_url
  storage_class = var.storage_class
}
