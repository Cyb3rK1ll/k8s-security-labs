# lab5-opa-gatekeeper-aks/main.tf
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
  name     = "lab5-aks-rg"
  location = var.location
}

# VNet + Subnet
resource "azurerm_virtual_network" "vnet" {
  name                = "lab5-vnet"
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

# AKS Cluster (FREE TIER)
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "lab5-aks-cluster"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "lab5"

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

# ESPERA ACTIVA A QUE EL CLUSTER AKS ESTÉ REALMENTE LISTO
resource "null_resource" "wait_for_cluster" {
  provisioner "local-exec" {
    command = <<EOT
      echo "Esperando a que el cluster AKS esté listo para kubectl..."
      az aks get-credentials --resource-group ${azurerm_resource_group.rg.name} --name ${azurerm_kubernetes_cluster.aks.name} --overwrite-existing
      for i in {1..30}; do
        if kubectl get nodes --request-timeout=5s >/dev/null 2>&1; then
          echo "✅ Cluster listo!"
          exit 0
        fi
        echo "⏳ Cluster aún no listo... reintentando ($i/30)"
        sleep 10
      done
      echo "❌ Timeout esperando al cluster AKS"
      exit 1
    EOT
  }

  depends_on = [azurerm_kubernetes_cluster.aks]
}

/*
# ESPERA A QUE EL CLUSTER ESTÉ LISTO
resource "null_resource" "wait_for_cluster" {
  provisioner "local-exec" {
    command = <<EOT
      echo "Esperando cluster AKS..."
      sleep 60
      until kubectl get nodes --request-timeout=5s > /dev/null 2>&1; do
        echo "Cluster no listo, reintentando..."
        sleep 10
      done
      echo "Cluster listo!"
    EOT
  }

  depends_on = [azurerm_kubernetes_cluster.aks]
}
*/

# ACTUALIZA KUBECONFIG
resource "null_resource" "update_kubeconfig" {
  provisioner "local-exec" {
    command = "az aks get-credentials --resource-group ${azurerm_resource_group.rg.name} --name ${azurerm_kubernetes_cluster.aks.name} --overwrite-existing"
  }

  depends_on = [azurerm_kubernetes_cluster.aks]
}

# CREA KUBECONFIG LOCAL
resource "local_file" "kubeconfig" {
  content  = azurerm_kubernetes_cluster.aks.kube_config_raw
  filename = "${path.module}/.kube/config"

  depends_on = [null_resource.update_kubeconfig]
}

# Providers (USANDO KUBECONFIG LOCAL)
provider "kubernetes" {
  config_path = local_file.kubeconfig.filename
}

provider "helm" {
  kubernetes {
    config_path = local_file.kubeconfig.filename
  }
}

# OPA Gatekeeper
resource "helm_release" "gatekeeper" {
  name       = "gatekeeper"
  #repository = "https://open-policy-agent.github.io/gatekeeper/charts"
  #chart      = "gatekeeper"
  chart            = "${path.module}/charts/gatekeeper"
  #version    = "3.20.1"
  namespace  = "gatekeeper-system"
  create_namespace = true

  set {
    name  = "audit.intervalSeconds"
    value = "60"
  }

  # ESPERA A QUE LOS CRDs ESTÉN LISTOS (FUNCIONA EN 3.14)
  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [null_resource.wait_for_cluster]
}

# ESPERA A QUE LOS CRDs ESTÉN LISTOS (DOBLE VERIFICACIÓN)
resource "null_resource" "wait_for_crds" {
  provisioner "local-exec" {
    command = <<EOT
      echo "Esperando CRDs base de Gatekeeper..."
      until kubectl get crd constrainttemplates.templates.gatekeeper.sh > /dev/null 2>&1; do
        echo "CRD ConstraintTemplate no listo, reintentando..."
        sleep 10
      done
      echo "CRD ConstraintTemplate listo!"
    EOT
  }

  depends_on = [helm_release.gatekeeper]
}

# Aplica los ConstraintTemplates con kubectl
resource "null_resource" "apply_constraint_templates" {
  provisioner "local-exec" {
    command = <<EOT
      echo "Aplicando ConstraintTemplate PSS..."
      kubectl apply -f ${path.module}/gatekeeper/templates/pss-template.yaml
      echo "Esperando CRD K8sPSS..."
      until kubectl get crd k8spss.constraints.gatekeeper.sh > /dev/null 2>&1; do
        echo "CRD K8sPSS no listo, reintentando..."
        sleep 10
      done
      echo "CRD K8sPSS listo!"
    EOT
  }

  depends_on = [null_resource.wait_for_crds]
}

# Aplica los Constraints (PSS)
resource "null_resource" "apply_constraints" {
  provisioner "local-exec" {
    command = <<EOT
      echo "Aplicando Constraints PSS..."
      kubectl apply -f ${path.module}/gatekeeper/constraints/
    EOT
  }

  depends_on = [null_resource.apply_constraint_templates]
}


/*
# ConstraintTemplate para PSS
resource "kubernetes_manifest" "constraint_template" {
  for_each = fileset("${path.module}/gatekeeper/templates", "*.yaml")
  manifest = yamldecode(file("${path.module}/gatekeeper/templates/${each.value}"))

  depends_on = [null_resource.wait_for_crds]
}

# Constraints PSS
resource "kubernetes_manifest" "pss_constraints" {
  for_each = fileset("${path.module}/gatekeeper/constraints", "*.yaml")
  manifest = yamldecode(file("${path.module}/gatekeeper/constraints/${each.value}"))

  depends_on = [kubernetes_manifest.constraint_template]
}*/