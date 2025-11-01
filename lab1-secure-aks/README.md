# Kubernetes Security Labs – Claudio Magagnotti

> **Cybersecurity Architect | 12+ Years in Cloud Security & DevSecOps**  
> **Azure AKS | AWS EKS | Zero Trust | CISSP (2025) | CKA | AZ-500**  
> **Spain | [clau.magagnotti@hotmail.com](mailto:clau.magagnotti@hotmail.com)**  

# LAB 1: Secure AKS Cluster (Zero-Trust, RBAC AAD, Pod Escape **BLOQUEADO**)

## 🎯 Objetivo
Deployar AKS **privado originalmente**, RBAC AAD nativo, VNet isolation. **Pod no escapa**.

## ✅ Hardening demostrado
| Feature | Estado | Prueba |
|---------|--------|--------|
| **RBAC AAD** | ✅ Activo | Forbidden sin rol → OK con rol cluster scope |
| **VNet Isolation** | ✅ Bloqueado | curl metadata → **NO RESPUESTA** |
| **No hostNetwork** | ✅ Bloqueado | `/etc/hosts` solo pod (no host) |
| **CIS Benchmark** | ✅ Ejecutado | kube-bench v0.8.0 |

## 🚀 Deploy completo (5 min)
```bash
terraform apply -auto-approve
CLUSTER_ID=$(az aks show -g k8s-lab-rg -n k8s-lab-aks --query id -o tsv)
az role assignment create --role "Azure Kubernetes Service RBAC Cluster Admin" --assignee yourAccount@yourDomain.com --scope $CLUSTER_ID
az aks get-credentials -g k8s-lab-rg -n k8s-lab-aks
./attack/pod-escape.sh
