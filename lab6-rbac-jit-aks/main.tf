terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
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

provider "azuread" {}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "lab6-aks-rg"
  location = var.location
}

# Generate a secure random password for the developer user
resource "random_password" "developer_password" {
  length           = 16
  special          = true
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!@#$%^&*()-_=+[]{}"
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "lab6-aks-cluster"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "lab6"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_B2s"
  }

  identity {
    type = "SystemAssigned"
  }

  azure_active_directory_role_based_access_control {
    managed                = true
    azure_rbac_enabled     = true
    admin_group_object_ids = [azuread_group.admin.object_id]
  }
}

# ====================================================
#  Azure RBAC assignments for AKS Zero Trust Access
# ====================================================

# Get current Azure AD user 
data "azuread_user" "current" {
  user_principal_name = "claudiom@deepnet.com.ar"
}

# Grant current user Cluster Admin role (to manage RBAC + K8s resources)
resource "azurerm_role_assignment" "aks_cluster_admin_user" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azuread_user.current.object_id

  depends_on = [azurerm_kubernetes_cluster.aks]
}

# Grant AKS-Admins group Cluster Admin permissions
resource "azurerm_role_assignment" "aks_cluster_admin_group" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = azuread_group.admin.object_id

  depends_on = [azurerm_kubernetes_cluster.aks]
}

# UPDATE KUBECONFIG
resource "null_resource" "update_kubeconfig" {
  provisioner "local-exec" {
    command = "az aks get-credentials --resource-group ${azurerm_resource_group.rg.name} --name ${azurerm_kubernetes_cluster.aks.name} --overwrite-existing"
  }

  depends_on = [azurerm_kubernetes_cluster.aks]
}

# CREATE LOCAL KUBECONFIG 
resource "local_file" "kubeconfig" {
  content  = azurerm_kubernetes_cluster.aks.kube_config_raw
  filename = "${path.module}/.kube/config"

  depends_on = [null_resource.update_kubeconfig]
}

# Providers
provider "kubernetes" {
  config_path = local_file.kubeconfig.filename
}

# Azure AD Groups
resource "azuread_group" "admin" {
  display_name     = "AKS-Admins"
  security_enabled = true

  lifecycle {
    ignore_changes = [members]
  }
}

resource "azuread_group" "developer" {
  display_name     = "AKS-Developers"
  security_enabled = true

  lifecycle {
    ignore_changes = [members]
  }
}

# ====================================================
# Add members to Azure AD Groups
# ====================================================

# Get users from Entra ID (replace with real users in your tenant)
data "azuread_user" "admin_user" {
  user_principal_name = "claudiom@testinglab.com"
}

# Create demo developer user in Entra ID (for lab)
resource "azuread_user" "developer_user" {
  user_principal_name   = "developer@testinglab.com"
  display_name          = "AKS Developer"
  mail_nickname         = "developer"
  password              = random_password.developer_password.result
  force_password_change = false
}

# ================================================================
# Assign AKS RBAC Viewer role to developer user on AKS cluster
# ================================================================
resource "azurerm_role_assignment" "aks_viewer_developers_group" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azuread_group.developer.object_id

  depends_on = [
    azurerm_kubernetes_cluster.aks,
    azuread_user.developer_user
  ]
}

# Add admin to AKS-Admins group
resource "azuread_group_member" "admin_member" {
  group_object_id  = azuread_group.admin.id
  member_object_id = data.azuread_user.admin_user.id
}

# Add developer to AKS-Developers group
resource "azuread_group_member" "developer_member" {
  group_object_id  = azuread_group.developer.id
  member_object_id = azuread_user.developer_user.id
}

# PIM Eligible Assignment (JIT - CONFIGURED IN PORTAL)
# Note: PIM eligibility is configured manually in the Azure Portal due to Terraform limitations.

data "azurerm_role_definition" "aks_admin" {
  name = "Azure Kubernetes Service RBAC Cluster Admin"
}

# RBAC Developer Role
resource "kubernetes_role" "developer" {
  metadata {
    name      = "developer"
    namespace = "default"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services"]
    verbs      = ["get", "list", "watch", "create", "delete"]
  }

  depends_on = [
    local_file.kubeconfig,
    azurerm_role_assignment.aks_cluster_admin_user,
    azurerm_role_assignment.aks_cluster_admin_group
  ]
}

# RBAC Developer Binding
resource "kubernetes_role_binding" "developer" {
  metadata {
    name      = "developer-binding"
    namespace = "default"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.developer.metadata.0.name
  }

  subject {
    kind      = "Group"
    name      = azuread_group.developer.object_id
    api_group = "rbac.authorization.k8s.io"
  }

  depends_on = [kubernetes_role.developer]
}
output "developer_password" {
  value       = random_password.developer_password.result
  sensitive   = true
  description = "Generated password for developer@deepnet.com.ar"
}