locals {
  name          = var.project_name
  cluster_name  = "${var.project_name}-eks"
  tags = {
    Project = var.project_name
    Owner   = "claudio-magagnotti"
    Lab     = "juice-shop-demo"
  }
}

# ==================== VPC ------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-1a", "eu-west-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway      = true
  single_nat_gateway      = true
  enable_vpn_gateway      = false
  map_public_ip_on_launch = true

  public_subnet_tags = merge(
    local.tags,
    {
      "kubernetes.io/cluster/${local.cluster_name}" = "shared"
      "kubernetes.io/role/elb"                      = "1"
    }
  )

  private_subnet_tags = merge(
    local.tags,
    {
      "kubernetes.io/cluster/${local.cluster_name}" = "shared"
      "kubernetes.io/role/internal-elb"             = "1"
    }
  )

  tags = local.tags
}

# ------------------ EKS ------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = local.cluster_name
  kubernetes_version = "1.30"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Public access only for Lab
  endpoint_public_access  = true
  endpoint_private_access = true

  enable_irsa = true

  tags = local.tags
}

resource "aws_security_group_rule" "allow_nodeports_from_internet" {
  description       = "Allow external load balancers to reach Traefik NodePorts"
  security_group_id = module.eks.node_security_group_id
  type              = "ingress"
  from_port         = 32080
  to_port           = 32443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

# ==================== EKS ADD-ONS ====================
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = module.eks.cluster_name
  addon_name   = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags         = local.tags

  depends_on = [module.eks]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = module.eks.cluster_name
  addon_name   = "kube-proxy"
  tags         = local.tags

  depends_on = [module.eks]
}

data "aws_iam_policy_document" "ebs_csi_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${local.name}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name = module.eks.cluster_name
  addon_name   = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi.arn
  tags         = local.tags

  depends_on = [
    module.eks,
    aws_iam_role.ebs_csi,
    aws_iam_role_policy_attachment.ebs_csi
  ]
}

# ==================== NODE GROUP -------------------
module "eks_default_node_group" {
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = "~> 21.0"

  name = "default"

  cluster_name                      = module.eks.cluster_name
  cluster_endpoint                  = module.eks.cluster_endpoint
  cluster_auth_base64               = module.eks.cluster_certificate_authority_data
  cluster_service_cidr = module.eks.cluster_service_cidr
  cluster_ip_family    = "ipv4"

  subnet_ids             = module.vpc.private_subnets
  vpc_security_group_ids = [module.eks.node_security_group_id]

  min_size     = 1
  max_size     = 1
  desired_size = 1

  instance_types = ["t3.medium"]
  capacity_type  = "ON_DEMAND"

  kubernetes_version             = "1.30"
  use_latest_ami_release_version = false

  create_iam_role = true
  iam_role_name   = "${local.name}-eks-node-group"

  tags = local.tags

  depends_on = [
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy
  ]
}

module "eks_defectdojo_node_group" {
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = "~> 21.0"

  name = "defectdojo"

  cluster_name        = module.eks.cluster_name
  cluster_endpoint    = module.eks.cluster_endpoint
  cluster_auth_base64 = module.eks.cluster_certificate_authority_data
  cluster_service_cidr = module.eks.cluster_service_cidr
  cluster_ip_family    = "ipv4"

  subnet_ids             = module.vpc.private_subnets
  vpc_security_group_ids = [module.eks.node_security_group_id]

  min_size     = 1
  max_size     = 1
  desired_size = 1

  labels = {
    workload = "defectdojo"
  }

  instance_types = ["t3.small"]
  capacity_type  = "ON_DEMAND"

  kubernetes_version             = "1.30"
  use_latest_ami_release_version = false

  create_iam_role = true
  iam_role_name   = "${local.name}-eks-node-defectdojo"

  tags = merge(local.tags, { Workload = "defectdojo" })

  depends_on = [
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy
  ]
}

resource "aws_iam_role_policy_attachment" "node_group_ecr_readonly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = module.eks_default_node_group.iam_role_name
}

resource "aws_eks_addon" "coredns" {
  cluster_name = module.eks.cluster_name
  addon_name   = "coredns"
  tags         = local.tags

  depends_on = [module.eks_default_node_group]
}

# ==================== EKS ACCESS ENTRY FOR GITLAB ====================
resource "aws_eks_access_entry" "gitlab" {
  cluster_name  = module.eks.cluster_name
  principal_arn = data.aws_iam_role.gitlab_ci.arn
  type          = "STANDARD"

  depends_on = [module.eks]
}

resource "aws_eks_access_policy_association" "gitlab_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = data.aws_iam_role.gitlab_ci.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [
    aws_eks_access_entry.gitlab,
    module.eks
  ]
}
# ==================== ECR ====================
resource "aws_ecr_repository" "juice_shop" {
  name                 = "${local.name}-juice-shop"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  tags                 = local.tags
}

# ==================== GitLab OIDC ====================
data "aws_iam_openid_connect_provider" "gitlab" {
  url = "https://gitlab.com"
}

######### ==================== IAM Role para GitLab CI ======================
data "aws_iam_role" "gitlab_ci" {
  name = var.gitlab_ci_role_name
}

# ==================== EKS CLUSTER DATA ====================
data "aws_eks_cluster" "eks" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

# ==================== EKS AUTH =======================
data "aws_eks_cluster_auth" "eks" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}
