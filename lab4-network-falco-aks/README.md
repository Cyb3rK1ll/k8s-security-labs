
# Kubernetes Security Labs – Claudio Magagnotti

> **Cybersecurity Architect | 12+ Years in Cloud Security & DevSecOps**  
> **Azure AKS | AWS EKS | Zero Trust | CISSP (2025) | CKA | AZ-500**  
> **Spain | [clau.magagnotti@hotmail.com](mailto:clau.magagnotti@hotmail.com)**  

# LAB 4: Network Policies + Falco (AKS + Slack Alerts)

---

## WHY FALCO?

Falco is the de facto solution for runtime security in Kubernetes, regardless of the cloud provider.
Azure and AWS offer native tools (Defender for Containers, GuardDuty), but:

- They lack the granularity of Falco (syscall-level detection)
- They are not open-source or multi-cloud
- They don’t support such flexible custom rules

> Falco detects in real-time: shell spawn, unauthorized binaries, privilege escalation.
We use it because it is the CNCF standard, and works the same in EKS, AKS, GKE.
In production, it integrates with Slack, SIEM, SOAR. It’s more powerful than native tools for regulated environments.

---

## Objetive

Demonstrate **Zero Trust** in Azure Kubernetes Service (AKS):

- **NetworkPolicy deny-all** → Block all traffic between pods
- **Falco** → Detect unauthorized shells and binaries in real time  
- **Slack** → Immediate alerts via Falcosidekick  
- **Terraform + Helm** → Infrastructure as code, 100% automated 

---

## Deployed Architecture

```text
AKS Cluster (Standard_B2s)
├── VNet (10.0.0.0/16) + Subnet (10.0.1.0/24)
├── Service CIDR: 172.16.0.0/16 (separado del VNet)
├── NetworkPolicy deny-all (default namespace)
├── Falco DaemonSet → Detecta:
│   • Drop and execute new binary in container (curl)
│   • Terminal shell in container (sh -c)
├── Falcosidekick → Envía alertas a Slack
└── Ataque: lateral-move.sh → curl + shell spawn
```
---
## Deploy en 5 Minutos (GRATIS)
```
# 1. Clona el repo
git clone https://github.com/Cyb3rK1ll/k8s-security-labs.git
cd k8s-security-labs/lab4-network-falco-aks

# 2. Deploy
terraform init
terraform apply -auto-approve

# 3. Ejecuta ataque
./attack/lateral-move.sh

```
---
## 📊 Hardening metrics

|Feature| Status| Prueba|
|-|-|-|
|NetworkPolicy deny-all |✅ Activo |curl victim:80 → BLOCKED|
|Falco runtime detection| ✅ Activo| shell in container → Slack alert
|Slack integration |✅ Activo |Real-time alerts|
|Custom rules |✅ Loaded |rules_ files: /etc/falco/custom_rules/falco.yaml|



---

## Evidence (100% collected in /evidence)

|Archivo | Descripción |
|-|-|
|falco.log| Detección de curl y sh -c |
|networkpolicy.yaml| deny-all activa pods.txt Pods en ejecución |
|falco-custom-rules.yaml| Reglas personalizadas |
|helm-values.yaml| Configuración de Falco lateral-move.10g Ataque ejecutado|
|![Notificacion1](evidence/Slack_Notification01.png)|  Alerta curl|
|![Notificacion1](evidence/Slack_Notification02.png) | Alerta sh -c|

---

## Reglas Personalizadas (falco_rules/falco.yaml)
```
- rule: Shell via sh
  desc: Detecta cualquier shell lanzado
  condition: container and evt.type = execve and proc.name = sh
  output: "Shell detected! user=%user.name container=%container.id command=%proc.cmdline"
  priority: NOTICE
  tags: [container, shell]

- rule: Shell spawned via sh -c
  desc: Detecta exec con -c
  condition: container and evt.type = execve and proc.name = sh and proc.cmdline contains "-c"
  output: "Shell spawned via sh -c (user=%user.name container=%container.id command=%proc.cmdline image=%container.image.repository)"
  priority: WARNING
  tags: [container, shell, exec]
  ```

