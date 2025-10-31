# Kubernetes Security Labs – Claudio Magagnotti

> **Cybersecurity Architect | 12+ Years in Cloud & DevSecOps**  
> **Azure AKS | AWS EKS | Zero Trust | CISSP | CKA | AZ-500**  
> **Spain | [clau.magagnotti@hotmail.com](mailto:clau.magagnotti@hotmail.com)**  

### Technical Expertise

- **Security Architecture**: Azure, AWS, hybrid environments, Zero Trust, Landing Zones
- **Cloud Security**: AKS/EKS hardening, VNet isolation, CIS benchmarks, Falco, OPA Gatekeeper
- **IAM & Compliance**: PAM, RBAC, MFA, ISO 27001, NIST CSF, GDPR, NIS2
- **DevSecOps**: GitLab, Jenkins, Docker, SAST, DAST, SCA, container security
- **Threat & Risk**: Threat modeling, vulnerability management, SIEM, SOAR
- **Presales & Advisory**: Solution design, technical proposals, client presentations

---

## **Production-Grade Kubernetes Security Labs**

**Real-world, deployable labs to demonstrate enterprise-ready K8s security.**  

---

### **Why These Labs?**
- **Interview-proof**: Deploy secure AKS/EKS in 5 minutes
- AKS audit + CIS fix plan
- **Production-hardened**: Terraform, RBAC, VNet isolation, CIS benchmarks
- **Multi-cloud**: Azure AKS + AWS EKS
- **Real attacks**: Pod escape, privilege escalation, lateral movement


### Roadmap

|Lab|Focus|Status|
|-|-|-|
|LAB 1|Secure AKS Cluster|✅ LIVE
|LAB 2|Network Policies + Falco|Tomorrow
|LAB 3|RBAC + JIT Access|Day 3
|LAB 4|Runtime Security + SOAR|Day 4
|LAB 5|Breach Simulation|Day 5

---

## **LAB 1: Secure AKS Cluster (Zero-Trust, RBAC AAD, Pod Escape BLOCKED)**

### **Objective**
Deploy AKS with:
- **Azure AD RBAC** (granular access control)
- **Private cluster + VNet isolation**
- **Pod escape protection** (no IMDS, no hostNetwork)
- **CIS Benchmark audit** (11 FAIL, 14 WARN → remediation plan)

### **Live Results**
| Attack | Result | Evidence |
|--------|--------|----------|
| **IMDS Metadata** | **BLOCKED** | No response from `168.63.129.16` |
| **Host Network** | **BLOCKED** | Pod sees only its own `/etc/hosts` |
| **RBAC AAD** | **ENFORCED** | `Forbidden` without cluster-admin role |
| **CIS Score** | **92/100** | Full JSON report |

### **Deploy in 5 Minutes**
```bash
terraform apply -auto-approve
az role assignment create --role "Azure Kubernetes Service RBAC Cluster Admin" \
  --assignee claudiom@deepnet.com.ar \
  --scope $(az aks show -g k8s-lab-rg -n k8s-lab-aks --query id -o tsv)
az aks get-credentials -g k8s-lab-rg -n k8s-lab-aks
./attack/pod-escape.sh  # → BLOCKED
```
---
# About Me

In the last 10 years I’ve worked mostly for MSP and MSSP companies. I am a versatile professional with +10 years of experience, specializing first and foremost in Network Security followed by a deep engagement in Security Engineering, and culminating in proficiency in DevSecOps. This unique blend of skills empowers me to comprehensively secure network systems, IT infrastructure, and software development processes.

My technical expertise is broad, encompassing advanced network routing & switching, network security solutions like firewalls (UTM, IDS/IPS, VPNs, SIEM, NAC and network & infrastructure monitoring tools like check_mk, New Relic, Zabbix, Grafana and Prometheus, as well as automation with Ansible. In the realm of DevSecOps, I am proficient with tools like Docker, Jenkins, Git, GitLab, Kubernetes, AKS, EKS, ECS, Terraform, Defect Dojo and integration of automated security analysis like SAST, SCA, Container images scanning, IAST, DAST, and am familiar with cloud platforms like AWS and Azure, complemented by my knowledge in Powershell and Python.

My approach is characterized by a comprehensive risk analysis and mitigation strategy, where I develop and implement security measures that address the complex nature of current cyber threats across network infrastructure, and software domains. I am known for my proactive, adaptive stance, continually evolving with the latest cybersecurity trends and threats.

I effectively communicate complex security concepts to various teams, enhancing collaboration and embedding security considerations into all technological aspects.
I am a solid team player, and I am always looking to improve and the last ten years I’ve been working with multi cloud environments such as AWS, Azure and Orale Cloud.