
# LAB 5: OPA Gatekeeper + Pod Security Standards (AKS)

**Autor**: Claudio Magagnotti  
**Cloud**: Azure AKS (Free Tier)  
**Costo**: $0.00 (750h/mes gratis)  
**Deploy**: 5 minutos con Terraform  

---
## WHAT IS OPA GATEKEEPER?
OPA Gatekeeper is the Open Policy Agent admission controller for Kubernetes.
Enable Policy as Code with Rego: validate, mutate or block resources in real time.
In this lab, we use it to enforce Pod Security Standards (PSS):

- Baseline → No privileged, no hostPath
- Restricted → No root, no capabilities

It is more flexible than Kyverno and more powerful than PodSecurityPolicies.
Integrated with Falco for audit + Slack.
It is CNCF standard, multi-cloud, open source.
In production, it is combined with RBAC, NetworkPolicy and Falco for Zero Trust.

---

## Objetivo

Demostrar **Policy as Code** en Azure Kubernetes Service (AKS):

- **OPA Gatekeeper** → Valida pods en tiempo real  
- **Pod Security Standards** → Baseline + Restricted  
- **Bloqueo de pods privilegiados** → `privileged: true`, `runAsUser: 0`  
- **Terraform + Helm** → 100% automatizado  

---

## Arquitectura Deployada

```text
AKS Cluster (Standard_B2s - Free Tier)
├── VNet (10.0.0.0/16) + Subnet (10.0.1.0/24)
├── Service CIDR: 172.16.0.0/16 (separado)
├── OPA Gatekeeper → Enforza PSS:
│   • Baseline: No hostPath, no privileged
│   • Restricted: No root, no capabilities
├── Ataque: malicious-pod.yaml → BLOCKED
└── Audit logs → Gatekeeper
```
---

## Deploy en 5 Minutos
```
# 1. Clona el repo
git clone https://github.com/Cyb3rK1ll/k8s-security-labs.git
cd k8s-security-labs/lab5-opa-gatekeeper-aks

# 2. Deploy
terraform init
terraform apply -auto-approve

# 3. Ataque
kubectl apply -f attack/malicious-pod.yaml
# → DEBE FALLAR
```

---
## Evidencia (100% recolectada en /evidence)
|Archivo|Descripción|
|-|-|
|gatekeeper-audit.log|Violación PSS|
|kubectl-apply-error.txt|Forbidden por Gatekeeper|
|pods.txt|Solo pods válidos|
|helm-values.yaml|Configuración Gatekeeper|

---
## 📊 Hardening metrics
|Feature|Status|Prueba|
|-|-|-|
|OPA Gatekeeper|✅ Activo|helm list -n gatekeeper-system|
|PSS Baseline|✅ Enforced|hostPath → BLOCKED|
|PSS Restricted|✅ Enforced|privileged: true → BLOCKED|
|Audit logs|✅ Active|kubectl logs -n gatekeeper-system|