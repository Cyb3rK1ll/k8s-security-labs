# lab4-network-falco-aks/main.tf
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
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

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "lab4-aks-rg"
  location = var.location
}

# VNet + Subnet
resource "azurerm_virtual_network" "vnet" {
  name                = "lab4-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "aks" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "lab4-aks-cluster"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "lab4"

  default_node_pool {
    name           = "default"
    node_count     = 1
    vm_size        = "Standard_B2s"
    vnet_subnet_id = azurerm_subnet.aks.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    service_cidr   = "172.16.0.0/16" 
    dns_service_ip = "172.16.0.10"
  }
}

resource "null_resource" "update_kubeconfig" {
  provisioner "local-exec" {
    command = "az aks get-credentials --resource-group ${azurerm_resource_group.rg.name} --name ${azurerm_kubernetes_cluster.aks.name} --overwrite-existing"
  }

  depends_on = [azurerm_kubernetes_cluster.aks]
}

# Providers Kubernetes y Helm
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
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

# Namespace Falco
resource "kubernetes_namespace" "falco" {
  metadata {
    name = "falco"
  }

  depends_on = [null_resource.update_kubeconfig]
}

# ConfigMap
resource "kubernetes_config_map" "falco_custom_rules" {
  metadata {
    name      = "falco-custom-rules"
    namespace = "falco"
  }

  data = {
    "falco.yaml" = file("${path.module}/falco_rules/falco.yaml")
  }

  depends_on = [
    kubernetes_namespace.falco
  ]
}

# Falco via Helm
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
        - /etc/falco/custom_rules/falco.yaml
    falcosidekick:
      enabled: true
      config:
        slack:
          webhookurl: "https://hooks.slack.com/services/XXXXXXXX/XXXXXXX/XXXXXXXXXX"
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