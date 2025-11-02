# lab3-network-falco/main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = "k8s-labs"
}

# VPC with 2 AZs + Public IP
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "lab3-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  map_public_ip_on_launch = true

  tags = {
    Name = "lab3-vpc"
  }
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "lab3-eks-cluster"
  cluster_version = "1.30"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = concat(module.vpc.private_subnets, module.vpc.public_subnets)

  cluster_endpoint_public_access = true
  cluster_endpoint_private_access = true

  enable_irsa = true

  eks_managed_node_groups = {
    default = {
      desired_size   = 1
      min_size       = 1
      max_size       = 1
      instance_types = ["t3.medium"]
      public_ip      = true
      subnet_ids     = module.vpc.public_subnets
    }
  }

  tags = {
    Name = "lab3-eks-cluster"
  }
}

# Update kubeconfig
resource "null_resource" "update_kubeconfig" {
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region} --profile k8s-labs"
  }

  depends_on = [module.eks]
}

# Providers Kubernetes y Helm
provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

# NetworkPolicy deny-all
resource "kubernetes_network_policy" "deny_all" {
  metadata {
    name      = "deny-all"
    namespace = "default"
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
  }

  depends_on = [null_resource.update_kubeconfig]
}

#--- FALCO
resource "kubernetes_namespace" "falco" {
  metadata {
    name = "falco"
  }

  depends_on = [null_resource.update_kubeconfig]
}

resource "kubernetes_config_map" "falco_custom_rules" {
  metadata {
    name      = "falco-custom-rules"
    namespace = "falco"
  }

  data = {
    "falco_rules.local.yaml" = file("${path.module}/falco_rules/falco.yaml")
  }

  depends_on = [
    null_resource.update_kubeconfig,
    kubernetes_namespace.falco
    ]
}

resource "helm_release" "falco" {
  name             = "falco"
  repository       = "https://falcosecurity.github.io/charts"
  chart            = "falco"
  version          = "7.0.0"
  namespace        = "falco"
  create_namespace = false
  timeout          = 600
  wait             = true
  wait_for_jobs    = true
  force_update     = true

  values = [
    <<-EOT
    driver:
      kind: module
      loader:
        version: "3.0.0"
    falco:
      json_output: true
      json_include_output_property: true
      rules_files:
        - /etc/falco/falco_rules.yaml
        - /etc/falco/falco_rules.local.yaml
        - /etc/falco/custom_rules/falco.yaml
    falcosidekick:
      enabled: true
      config:
        slack:
          webhookurl: "https://hooks.slack.com/services/XXXXXXXXXXX/XXXXXXXXXX/XXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
          minimumpriority: "Debug"
    extraVolumes:
      - name: falco-custom-rules
        configMap:
          name: falco-custom-rules
    extraVolumeMounts:
      - name: falco-custom-rules
        mountPath: /etc/falco/custom_rules
        readOnly: true
    EOT
  ]

  depends_on = [
    null_resource.update_kubeconfig,
    kubernetes_config_map.falco_custom_rules,
    kubernetes_network_policy.deny_all
  ]
}