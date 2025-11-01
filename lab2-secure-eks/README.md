# Kubernetes Security Labs – Claudio Magagnotti

> **Cybersecurity Architect | 12+ Years in Cloud Security & DevSecOps**  
> **Azure AKS | AWS EKS | Zero Trust | CISSP (2025) | CKA | AZ-500**  
> **Spain | [clau.magagnotti@hotmail.com](mailto:clau.magagnotti@hotmail.com)**  

# LAB 2: Secure EKS Cluster (IRSA, No IMDS, Pod Escape BLOCKED)

## Objective
Deploy EKS with:
- **IRSA** (no IAM keys)
- **No IMDS** (VPC isolation – NAT enabled for deployment only)
- **Pod escape blocked**
- **CIS Benchmark**

## Hardening Demonstrated
| Feature | Status | Proof |
|---------|--------|-------|
| **IRSA** | Active | Pod assumes IAM role without keys |
| **VPC Isolation** | Blocked | No access to `169.254.169.254` (IMDS) |
| **Host Network** | Blocked | `/etc/hosts` only shows pod IP |
| **CIS Benchmark** | Executed | Full JSON report |

> **Note**: NAT Gateway enabled for deployment (required for image pull). IMDS remains blocked.

## Deploy in 5 Minutes
```bash
terraform apply -auto-approve
aws eks update-kubeconfig --name eks-lab-cluster --region eu-west-1 --profile k8s-labs
./attack/pod-escape.sh