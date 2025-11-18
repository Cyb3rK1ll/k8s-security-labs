# EKS cluster data
data "aws_eks_cluster" "eks" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "eks" {
  name = var.cluster_name
}

module "ingress" {
  source = "../modules/ingress"

  providers = {
    helm       = helm.eks
    kubernetes = kubernetes.eks
    kubectl    = kubectl.eks
  }

  domain_name  = var.domain_name
  cluster_name = var.cluster_name
}
