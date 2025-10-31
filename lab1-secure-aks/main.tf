# lab1-secure-aks/main.tf
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
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "k8s-lab-rg"
  location = "westeurope"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "k8s-vnet"
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

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "k8s-lab-aks"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "k8slab"

  default_node_pool {
    name                = "default"
    node_count          = 1
    vm_size             = "Standard_D2s_v3"
    vnet_subnet_id      = azurerm_subnet.aks.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    service_cidr   = "10.1.0.0/16"
    dns_service_ip = "10.1.0.10"
  }

  # HARDENING 
  private_cluster_enabled = false

  # api_server_access_profile
  api_server_access_profile {
    authorized_ip_ranges = []  # Bloquea acceso público
  }

  # RBAC NATIVO CORRECTO (BLOQUE SEPARADO)
  role_based_access_control_enabled = true

  azure_active_directory_role_based_access_control {
    managed                = true
    azure_rbac_enabled     = true
  }
}

# Provider Kubernetes (después del cluster)
data "azurerm_kubernetes_cluster" "aks_creds" {
  name                = azurerm_kubernetes_cluster.aks.name
  resource_group_name = azurerm_resource_group.rg.name
}

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.aks_creds.kube_config[0].host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.aks_creds.kube_config[0].client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.aks_creds.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks_creds.kube_config[0].cluster_ca_certificate)
}

# Output
output "kube_config" {
  value     = data.azurerm_kubernetes_cluster.aks_creds.kube_config_raw
  sensitive = true
}